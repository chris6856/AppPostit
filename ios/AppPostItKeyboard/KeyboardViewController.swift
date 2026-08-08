import UIKit

/// Free-tier limit -- keep in sync with the Android keyboard's copy
/// (android/.../ime/AppPostItInputMethodService.kt: FREE_INSERT_LIMIT) and
/// the Dart side's kFreeInsertLimit (lib/providers/providers.dart). Each
/// platform enforces the same gate independently against the same App
/// Group data.
private let freeInsertLimit = 8

/// Mirrors AppPostItInputMethodService.kt's structure: a horizontal row of
/// category chips above a scrollable list of that category's posts,
/// tapping a post inserts its body at the cursor. Reading the shared
/// SQLite file and SharedState.swift's JSON file works without "Allow
/// Full Access", but *writing* to either does not -- confirmed by
/// testing, a write without it throws a permission error. Since tracking
/// the free-tier insert count requires writing, the whole UI here is
/// gated on hasFullAccess (see refresh()).
final class KeyboardViewController: UIInputViewController {
    private let reader = SqliteReader()
    private let usageTracker = UsageTracker()
    private let purchaseStatusReader = PurchaseStatusReader()

    private var categories: [CategoryRow] = []
    private var selectedCategoryId: Int64?

    private let chipScrollView = UIScrollView()
    private let chipStack = UIStackView()
    private let postScrollView = UIScrollView()
    private let postStack = UIStackView()
    private var nextKeyboardButton: UIButton!

    override func updateViewConstraints() {
        super.updateViewConstraints()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        buildLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    // MARK: - Layout

    private func buildLayout() {
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            view.heightAnchor.constraint(equalToConstant: 260),
        ])

        // Top bar: category chips + switch-keyboard button (required
        // whenever more than one keyboard is enabled).
        let topBar = UIStackView()
        topBar.axis = .horizontal
        topBar.spacing = 8
        topBar.alignment = .center

        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScrollView.addSubview(chipStack)
        chipScrollView.showsHorizontalScrollIndicator = false
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScrollView.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScrollView.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScrollView.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScrollView.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScrollView.heightAnchor),
        ])
        chipScrollView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        topBar.addArrangedSubview(chipScrollView)

        nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("\u{1F310}", for: .normal)
        nextKeyboardButton.addTarget(
            self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents
        )
        nextKeyboardButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        topBar.addArrangedSubview(nextKeyboardButton)

        root.addArrangedSubview(topBar)

        // Post list.
        postStack.axis = .vertical
        postStack.spacing = 4
        postStack.translatesAutoresizingMaskIntoConstraints = false
        postScrollView.addSubview(postStack)
        NSLayoutConstraint.activate([
            postStack.topAnchor.constraint(equalTo: postScrollView.topAnchor),
            postStack.bottomAnchor.constraint(equalTo: postScrollView.bottomAnchor),
            postStack.leadingAnchor.constraint(equalTo: postScrollView.leadingAnchor),
            postStack.trailingAnchor.constraint(equalTo: postScrollView.trailingAnchor),
            postStack.widthAnchor.constraint(equalTo: postScrollView.widthAnchor),
        ])
        root.addArrangedSubview(postScrollView)
    }

    // MARK: - Data

    private func refresh() {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        postStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Writing to the App Group container (tracking insert count, so
        // the free-tier limit can be enforced) requires Full Access --
        // confirmed by testing: reads succeeded without it, but every
        // write threw "Operation not permitted". Without it, the free
        // count could never be tracked at all.
        if !hasFullAccess {
            addEmptyMessage(
                to: postStack,
                text: "Enable \"Allow Full Access\" for AppPostIt Keyboard in Settings > " +
                    "General > Keyboard > Keyboards to use your saved posts here."
            )
            return
        }

        let isLocked = !purchaseStatusReader.isPremium() &&
            usageTracker.getInsertCount() >= freeInsertLimit
        if isLocked {
            addEmptyMessage(
                to: postStack,
                text: "You've used your \(freeInsertLimit) free inserts. Open AppPostIt to " +
                    "unlock unlimited posting."
            )
            return
        }

        categories = reader.getCategories()
        if categories.isEmpty {
            addEmptyMessage(to: postStack, text: "Add a category in AppPostIt to get started.")
            return
        }

        let currentSelection = categories.first { $0.id == selectedCategoryId }?.id
            ?? categories[0].id
        selectedCategoryId = currentSelection

        for category in categories {
            let isSelected = category.id == currentSelection
            let chip = UIButton(type: .system)
            chip.setTitle(category.name, for: .normal)
            chip.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            chip.layer.cornerRadius = 14
            chip.backgroundColor = isSelected ? .systemBlue : .secondarySystemBackground
            chip.setTitleColor(isSelected ? .white : .label, for: .normal)
            chip.tag = Int(category.id)
            chip.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            chipStack.addArrangedSubview(chip)
        }

        refreshPosts(categoryId: currentSelection)
    }

    private func refreshPosts(categoryId: Int64) {
        postStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let posts = reader.getPosts(categoryId: categoryId)
        if posts.isEmpty {
            addEmptyMessage(to: postStack, text: "No saved posts in this category yet.")
            return
        }
        for post in posts {
            let row = UIButton(type: .system)
            row.contentHorizontalAlignment = .left
            row.titleLabel?.numberOfLines = 2
            let hasLabel = !(post.label ?? "").isEmpty
            row.setTitle(hasLabel ? post.label : post.body, for: .normal)
            row.setTitleColor(.label, for: .normal)
            row.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            row.backgroundColor = .secondarySystemBackground
            row.layer.cornerRadius = 8
            row.addAction(
                UIAction { [weak self] _ in self?.insertPost(post) },
                for: .touchUpInside
            )
            postStack.addArrangedSubview(row)
        }
    }

    private func insertPost(_ post: PostRow) {
        textDocumentProxy.insertText(post.body)
        usageTracker.recordInsert()
        if !purchaseStatusReader.isPremium() && usageTracker.getInsertCount() >= freeInsertLimit {
            refresh()
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        selectedCategoryId = Int64(sender.tag)
        refresh()
    }

    private func addEmptyMessage(to stack: UIStackView, text: String) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .footnote)
        stack.addArrangedSubview(label)
    }
}
