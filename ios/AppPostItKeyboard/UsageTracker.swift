import Foundation

private let insertCountKey = "insert_count"
private let isPremiumKey = "is_premium"

/// Tracks how many times a saved post has actually been inserted into
/// another app via the keyboard -- this, not how many posts are saved, is
/// what counts against the free tier. Mirrors UsageTracker.kt on Android;
/// reads/writes the same shared JSON file (SharedState.swift) the Flutter
/// app's SharedStorage bridges into (AppGroupPlugin.swift).
final class UsageTracker {
    func getInsertCount() -> Int {
        SharedState.getInt(insertCountKey) ?? 0
    }

    func recordInsert() {
        SharedState.setInt(insertCountKey, getInsertCount() + 1)
    }
}

/// Mirrors PurchaseStatusReader.kt on Android -- reads the "is_premium"
/// flag the Flutter app writes after a successful purchase.
final class PurchaseStatusReader {
    func isPremium() -> Bool {
        SharedState.getBool(isPremiumKey) ?? false
    }
}
