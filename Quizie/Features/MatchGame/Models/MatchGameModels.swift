import Foundation

struct MatchPair: Identifiable, Equatable {
    let id: String
    let term: String
    let definition: String
}

struct MatchGameCard: Identifiable, Equatable {
    enum Kind: Equatable {
        case term
        case definition
    }

    let id: String
    let pairID: String
    let text: String
    let kind: Kind
}

extension MatchPair {
    static let lifeInTheUK: [MatchPair] = [
        MatchPair(
            id: "magna-carta",
            term: "Magna Carta",
            definition: "Charter that established the monarch is subject to the law"
        ),
        MatchPair(
            id: "habeas-corpus",
            term: "Habeas corpus",
            definition: "The right to challenge unlawful detention in court"
        ),
        MatchPair(
            id: "house-of-commons",
            term: "House of Commons",
            definition: "The elected chamber of the UK Parliament"
        ),
        MatchPair(
            id: "first-past-the-post",
            term: "First past the post",
            definition: "The candidate with the most votes wins"
        ),
        MatchPair(
            id: "devolution",
            term: "Devolution",
            definition: "Transfer of certain powers to Scotland, Wales and Northern Ireland"
        ),
        MatchPair(
            id: "suffragettes",
            term: "Suffragettes",
            definition: "Campaigners for women’s right to vote"
        )
    ]
}
