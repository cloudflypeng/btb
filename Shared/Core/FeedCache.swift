import Foundation

/// Stale-while-revalidate cache for the home feed (plan item A5).
/// The last recommend page is written to disk so the next cold start can render
/// immediately while the network refresh runs.
enum FeedCache {
    private static let maxItems = 30

    private static var file: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("btb-home-feed.json")
    }

    static func load() -> [VideoItem] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([VideoItem].self, from: data)) ?? []
    }

    static func save(_ items: [VideoItem]) {
        let slice = Array(items.prefix(maxItems))
        guard !slice.isEmpty else { return }
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(slice) else { return }
            try? data.write(to: file, options: .atomic)
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
