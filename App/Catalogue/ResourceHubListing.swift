import Foundation

/// The firmware directory in aroum's FM1 Resource Hub (`github.com/aroum/fm1-custom-fw`), read
/// from its README.
///
/// The README lists each firmware as a numbered line under a section heading, such as
/// `1. **[Melodee by keremimo](https://github.com/keremimo/melodee) ([Web Installer](…)):**`,
/// followed by bullets including `**License:**`. Only facts are taken: the name, author, links,
/// licence and section. The repository has no licence of its own, so its descriptions are left
/// out.
struct ResourceHubListing: Sendable {
    static let defaultURL = URL(literal: "https://raw.githubusercontent.com/aroum/fm1-custom-fw/main/README.md")
    /// Where people read the list.
    static let pageURL = URL(literal: "https://github.com/aroum/fm1-custom-fw")

    struct Entry: Sendable, Hashable {
        var name: String
        var author: String?
        /// The entry's main link, then the others on its line, e.g. its web installer.
        var links: [CatalogueLink]
        /// The licence as the list gives it, e.g. "Open Source (GPL-3.0-only)".
        var licence: String?
        /// From the section it's listed in, e.g. "game" for the gaming and emulator ports.
        var kinds: [String]
    }

    var entries: [Entry]

    init(markdown: String) {
        var entries: [Entry] = []
        var kinds: [String]?
        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("#") {
                kinds = Self.kinds(forHeading: line)
                continue
            }
            guard let kinds else { continue }
            if let entry = Self.entry(fromLine: line, kinds: kinds) {
                entries.append(entry)
            } else if let licence = Self.licence(fromLine: line), let last = entries.indices.last,
                entries[last].licence == nil
            {
                entries[last].licence = licence
            }
        }
        self.entries = entries
    }

    /// The kinds for a section's firmwares, or nil outside the firmware sections.
    ///
    /// Section 1 lists firmwares, in 1.1 (sound), 1.2 (modular platforms), 1.3 (games and
    /// experiments) and 1.4 (patched stock firmware). Later sections are tools and references.
    static func kinds(forHeading line: String) -> [String]? {
        guard let match = line.firstMatch(of: #/^#+\s+(\d+)(?:\.(\d+))?/#) else { return nil }
        guard match.output.1 == "1" else { return nil }
        switch match.output.2 {
        case "2": return ["platform"]
        case "3": return ["game"]
        case "4": return ["patch"]
        default: return []
        }
    }

    /// A numbered entry line: `1. **[Name by Author](url) ([Label](url) | …):**`.
    static func entry(fromLine line: String, kinds: [String]) -> Entry? {
        let pattern = #/^\s*\d+\.\s+\*\*\[(.+?)\]\((https?://[^\s)]+)\)(.*)$/#
        guard let match = line.firstMatch(of: pattern), let main = URL(string: String(match.output.2)) else {
            return nil
        }
        let (name, author) = nameAndAuthor(String(match.output.1))
        let mainLabel = main.host() == "github.com" ? "Source code" : "Project site"
        var links = [CatalogueLink(label: mainLabel, url: main)]
        for other in String(match.output.3).matches(of: #/\[([^\]]+)\]\((https?://[^\s)]+)\)/#) {
            guard let url = URL(string: String(other.output.2)) else { continue }
            let link = CatalogueLink(label: String(other.output.1), url: url)
            if !links.contains(where: { $0.comparable == link.comparable }) {
                links.append(link)
            }
        }
        return Entry(name: name, author: author, links: links, licence: nil, kinds: kinds)
    }

    /// The name and author, split at the first " by " of, say, "Felucca [Salt] by Chance Roth".
    static func nameAndAuthor(_ text: String) -> (String, String?) {
        let plain = text.replacingOccurrences(of: "\\", with: "").trimmingCharacters(in: .whitespaces)
        guard let range = plain.range(of: " by ") else { return (plain, nil) }
        let author = plain[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return (String(plain[..<range.lowerBound]), author.isEmpty ? nil : author)
    }

    /// The text of a `* **License:** …` bullet, without its closing full stop.
    static func licence(fromLine line: String) -> String? {
        guard let match = line.firstMatch(of: #/^\s*[*-]\s+\*\*Licen[sc]e:\*\*\s*(.+?)\s*$/#) else { return nil }
        var text = String(match.output.1)
        // Only the licence itself: "Open Source (GPL-3.0). Based on Felucca." keeps the first part.
        if let end = text.range(of: ". ") { text = String(text[..<end.lowerBound]) }
        while text.hasSuffix(".") { text.removeLast() }
        return text.isEmpty ? nil : text
    }
}
