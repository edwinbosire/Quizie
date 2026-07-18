struct SearchNavDestination: Hashable {
    let chapter: HandbookChapter
    let sectionIndex: Int
    let searchTerm: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(chapter.id)
        hasher.combine(sectionIndex)
        hasher.combine(searchTerm)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapter.id == rhs.chapter.id && lhs.sectionIndex == rhs.sectionIndex && lhs.searchTerm == rhs.searchTerm
    }
}

// MARK: - Search Result Row

