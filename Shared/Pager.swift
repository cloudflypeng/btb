import Observation

@MainActor
@Observable
final class Pager {
    var nextPage = 1
    var isLoadingMore = false
    var hasMore = true
    var failed = false

    func reset() {
        nextPage = 1
        isLoadingMore = false
        hasMore = true
        failed = false
    }

    func stop() {
        hasMore = false
        failed = false
    }
}
