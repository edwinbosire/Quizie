import Foundation

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let category: String
}

let curatedSuggestions: [SearchSuggestion] = [
    SearchSuggestion(text: "Democracy", icon: "building.columns", category: "Values"),
    SearchSuggestion(text: "Magna Carta", icon: "scroll", category: "History"),
    SearchSuggestion(text: "Henry VIII", icon: "crown", category: "History"),
    SearchSuggestion(text: "Parliament", icon: "building.columns", category: "Government"),
    SearchSuggestion(text: "Shakespeare", icon: "theatermasks", category: "Culture"),
    SearchSuggestion(text: "World War", icon: "globe.europe.africa", category: "History"),
    SearchSuggestion(text: "Scotland", icon: "map", category: "Geography"),
    SearchSuggestion(text: "Citizenship", icon: "person.text.rectangle", category: "Rights"),
    SearchSuggestion(text: "Queen Elizabeth", icon: "crown", category: "History"),
    SearchSuggestion(text: "Bronze Age", icon: "clock.arrow.circlepath", category: "History"),
    SearchSuggestion(text: "Northern Ireland", icon: "map", category: "Geography"),
    SearchSuggestion(text: "Bill of Rights", icon: "doc.text", category: "Government"),
]

nonisolated struct HandbookSearchResult: Identifiable, Sendable, Equatable {
    /// Stable across launches and query casing because it comes exclusively
    /// from authored content identity.
    let id: String
    let chapter: HandbookChapter
    let section: HandbookSection
    let sectionIndex: Int
    let blockID: String
    let matchedText: String
    let snippet: String
    let matchRange: Range<String.Index>?
}
