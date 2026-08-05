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
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    func getInsertCount() -> Int {
        defaults?.integer(forKey: insertCountKey) ?? 0
    }

    func recordInsert() {
        // App extensions are terminated far more aggressively than a
        // regular foregrounded app -- iOS can kill this process shortly
        // after the keyboard is dismissed, potentially before the
        // system's normal automatic flush of this write to the
        // cross-process-visible store has happened. synchronize() forces
        // that flush to happen now, before there's a chance to lose it.
        // (It's a documented no-op in most other contexts, which is why
        // adding it on the *read* side earlier didn't help -- this write
        // path in a short-lived extension process is the case it still
        // matters for.)
        let store = defaults
        store?.set(getInsertCount() + 1, forKey: insertCountKey)
        store?.synchronize()
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
