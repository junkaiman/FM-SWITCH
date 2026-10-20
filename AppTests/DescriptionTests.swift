import Foundation
import Testing

@testable import FMSwitch

/// Filling in descriptions from GitHub, for firmwares no list describes.
struct DescriptionTests {
    static func entry(_ id: String, repo: String?, what: String? = nil) -> CatalogueEntry {
        let links = repo.map { name in
            [CatalogueLink(label: "Source", url: URL(literal: "https://github.com").appending(path: name))]
        }
        return CatalogueEntry(id: id, name: id, what: what, links: links ?? [], listing: .resourceHub)
    }

    /// GitHub's answer for each repository, and a failure for anything else.
    static func gitHub(_ descriptions: [String: String]) -> CatalogueBuilder.Fetch {
        { url in
            let repo = url.pathComponents.suffix(2).joined(separator: "/")
            guard let description = descriptions[repo] else { throw URLError(.notConnectedToInternet) }
            return Data(#"{"description": "\#(description)", "stargazers_count": 3}"#.utf8)
        }
    }

    @Test func usesTheRepositoryDescriptionOnlyWhereTheListsHaveNone() async {
        let builder = CatalogueBuilder(
            fetch: Self.gitHub(["ada/zeta": "A synth.", "bo/listed": "Not this."]), describesFromGitHub: true)
        let entries = await builder.describe(
            [Self.entry("zeta", repo: "ada/zeta"), Self.entry("listed", repo: "bo/listed", what: "The list's words.")],
            previous: [:]
        )
        #expect(entries[0].what == "A synth.")
        #expect(entries[0].whatSource == .gitHub)
        #expect(entries[1].what == "The list's words.")
        #expect(entries[1].whatSource == nil)
    }

    @Test func leavesFirmwaresThatShareARepositoryUndescribed() async {
        let builder = CatalogueBuilder(fetch: Self.gitHub(["bo/mono": "Four firmwares."]), describesFromGitHub: true)
        let entries = await builder.describe(
            [Self.entry("mono-a", repo: "bo/mono"), Self.entry("mono-b", repo: "bo/mono")], previous: [:])
        #expect(entries.allSatisfy { $0.what == nil })
    }

    @Test func keepsTheLastDescriptionWhenGitHubCantBeReached() async {
        var earlier = Self.entry("zeta", repo: "ada/zeta", what: "A synth.")
        earlier.whatSource = .gitHub
        let builder = CatalogueBuilder(fetch: Self.gitHub([:]), describesFromGitHub: true)
        let entries = await builder.describe([Self.entry("zeta", repo: "ada/zeta")], previous: ["zeta": earlier])
        #expect(entries[0].what == "A synth.")
        #expect(entries[0].whatSource == .gitHub)
    }
}
