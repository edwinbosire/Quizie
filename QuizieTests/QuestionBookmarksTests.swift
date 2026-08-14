import Foundation
import Testing
@testable import BritReady__Life_in_UK_Test

struct QuestionBookmarksTests {
    @Test("Bookmark IDs persist across encoding and decoding")
    func bookmarkRoundTrip() {
        let expected: Set<String> = ["question-12", "question-3", "question-44"]
        let data = QuestionBookmarks.data(for: expected)

        #expect(!data.isEmpty)
        #expect(QuestionBookmarks.ids(from: data) == expected)
    }

    @Test("Invalid bookmark data safely produces an empty collection")
    func invalidBookmarkData() {
        #expect(QuestionBookmarks.ids(from: Data("not-json".utf8)).isEmpty)
    }
}
