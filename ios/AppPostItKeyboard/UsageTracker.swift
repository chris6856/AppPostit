import Foundation

private let appGroupId = "group.com.apppostit.apppostit"
private let insertCountKey = "insert_count"
private let isPremiumKey = "is_premium"

/// Tracks how many times a saved post has actually been inserted into
/// another app via the keyboard -- this, not how many posts are saved, is
/// what counts against the free tier. Mirrors UsageTracker.kt on Android;
/// reads/writes the same App Group UserDefaults suite the Flutter app's
/// SharedStorage bridges into (AppGroupPlugin.swift).
final class UsageTracker {
    // Computed, not stored -- see the matching comment in
    // AppGroupPlugin.swift. A stored instance served stale reads of this
    // exact key across the process boundary; recreating it on every
    // access is what actually fixed it.
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    func getInsertCount() -> Int {
        defaults?.integer(forKey: insertCountKey) ?? 0
    }

    func recordInsert() {
        defaults?.set(getInsertCount() + 1, forKey: insertCountKey)
    }
}

/// Mirrors PurchaseStatusReader.kt on Android -- reads the "is_premium"
/// flag the Flutter app writes after a successful purchase.
final class PurchaseStatusReader {
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    func isPremium() -> Bool {
        defaults?.bool(forKey: isPremiumKey) ?? false
    }
}
