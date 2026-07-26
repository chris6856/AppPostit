package com.apppostit.apppostit.ime

import android.graphics.Color
import android.inputmethodservice.InputMethodService
import android.view.LayoutInflater
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import com.apppostit.apppostit.R

class AppPostItInputMethodService : InputMethodService() {

    private lateinit var reader: SqliteReader
    private lateinit var categoryChipRow: LinearLayout
    private lateinit var postList: LinearLayout
    private var categories: List<CategoryRow> = emptyList()
    private var selectedCategoryId: Long? = null

    override fun onCreate() {
        super.onCreate()
        reader = SqliteReader(this)
    }

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.keyboard_view, null)
        categoryChipRow = view.findViewById(R.id.category_chip_row)
        postList = view.findViewById(R.id.post_list)
        view.findViewById<ImageButton>(R.id.switch_keyboard_button).setOnClickListener {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        }
        return view
    }

    override fun onStartInputView(info: EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        refreshCategories()
    }

    private fun refreshCategories() {
        categories = reader.getCategories()
        categoryChipRow.removeAllViews()
        postList.removeAllViews()

        if (categories.isEmpty()) {
            addEmptyMessage(postList, "Add a category in AppPostIt to get started.")
            return
        }

        val currentSelection = selectedCategoryId
            ?.takeIf { id -> categories.any { it.id == id } }
            ?: categories.first().id
        selectedCategoryId = currentSelection

        categories.forEach { category ->
            val chip = LayoutInflater.from(this)
                .inflate(R.layout.item_category_chip, categoryChipRow, false) as TextView
            val isSelected = category.id == currentSelection
            chip.text = category.name
            chip.setBackgroundResource(
                if (isSelected) R.drawable.chip_background_selected
                else R.drawable.chip_background_normal
            )
            chip.setTextColor(if (isSelected) Color.WHITE else Color.BLACK)
            chip.setOnClickListener {
                selectedCategoryId = category.id
                refreshCategories()
            }
            categoryChipRow.addView(chip)
        }

        refreshPosts(currentSelection)
    }

    private fun refreshPosts(categoryId: Long) {
        postList.removeAllViews()
        val posts = reader.getPosts(categoryId)
        if (posts.isEmpty()) {
            addEmptyMessage(postList, "No saved posts in this category yet.")
            return
        }
        posts.forEach { post ->
            val row = LayoutInflater.from(this).inflate(R.layout.item_post, postList, false)
            val title = row.findViewById<TextView>(R.id.post_title)
            val subtitle = row.findViewById<TextView>(R.id.post_subtitle)
            val hasLabel = !post.label.isNullOrBlank()
            title.text = if (hasLabel) post.label else post.body
            if (hasLabel) {
                subtitle.visibility = View.VISIBLE
                subtitle.text = post.body
            } else {
                subtitle.visibility = View.GONE
            }
            row.setOnClickListener {
                currentInputConnection?.commitText(post.body, 1)
            }
            postList.addView(row)
        }
    }

    private fun addEmptyMessage(container: LinearLayout, message: String) {
        val text = LayoutInflater.from(this)
            .inflate(R.layout.item_empty_message, container, false) as TextView
        text.text = message
        container.addView(text)
    }
}
