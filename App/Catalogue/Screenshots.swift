import Foundation

/// Finds the screenshots in a firmware project's README, by reading the images it shows.
///
/// Nothing is written down in this app: the images come from whatever the project's own
/// repository lists today, so a firmware's pictures change as its author updates the README.
enum Screenshots {
    /// Up to this many images, in the order the README shows them.
    private static let limit = 8

    /// The images in the project's README, or [] if no mirror can be read or it shows no
    /// usable images.
    ///
    /// Files come from raw.githubusercontent.com, with jsDelivr's CDN as a fallback: on some
    /// networks the raw host is unreachable, and the CDN serves the same files worldwide.
    /// The mirror that supplied the README also serves the images, so they load.
    static func discover(repo: String, fetch: @escaping (URL) async throws -> Data) async -> [URL] {
        let parts = repo.split(separator: "/")
        guard parts.count == 2 else { return [] }
        let owner = String(parts[0]), name = String(parts[1])
        for mirror in Mirror.allCases {
            guard let readme = mirror.readme(owner: owner, name: name),
                let data = try? await fetch(readme),
                let text = String(data: data, encoding: .utf8)
            else { continue }
            let images = imageURLs(in: text, repo: repo, mirror: mirror)
            if !images.isEmpty { return Array(images.prefix(limit)) }
        }
        return []
    }

    /// A GitHub file mirror: how to reach a repository's README and its images.
    enum Mirror: String, CaseIterable {
        case raw = "raw.githubusercontent.com"
        case jsDelivr = "cdn.jsdelivr.net"
        /// Kai's own VPS reverse-proxying the raw host, for networks where both GitHub hosts
        /// are unreachable.
        case proxy = "junkaiman.com/ghraw"

        func readme(owner: String, name: String) -> URL? {
            switch self {
            case .raw: URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/HEAD/README.md")
            case .jsDelivr: URL(string: "https://cdn.jsdelivr.net/gh/\(owner)/\(name)@HEAD/README.md")
            case .proxy: URL(string: "https://junkaiman.com/ghraw/\(owner)/\(name)/HEAD/README.md")
            }
        }

        /// A relative README path as an image URL on this mirror.
        func image(_ path: String, repo: String) -> URL? {
            let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "./"))
            switch self {
            case .raw: return URL(string: "https://raw.githubusercontent.com/\(repo)/HEAD/\(cleaned)")
            case .jsDelivr: return URL(string: "https://cdn.jsdelivr.net/gh/\(repo)@HEAD/\(cleaned)")
            case .proxy: return URL(string: "https://junkaiman.com/ghraw/\(repo)/HEAD/\(cleaned)")
            }
        }
    }

    /// The images a README shows: markdown `![alt](url)` and HTML `<img src="url">`, relative
    /// paths resolved against the mirror. Logos, badges and icons aren't screenshots, so
    /// they're left out.
    static func imageURLs(in text: String, repo: String, mirror: Mirror = .raw) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        let pattern =
            #"(?:!\[[^\]]*\]\(|<img[^>]*src=")([^")\s]+\.(?:png|jpe?g|gif|webp))"# +
            #"|(?:!\[[^\]]*\]\(|<img[^>]*src=')([^'\s]+\.(?:png|jpe?g|gif|webp))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            for group in [1, 2] {
                guard let matchRange = Range(match.range(at: group), in: text) else { continue }
                let address = String(text[matchRange])
                let url: URL?
                if let absolute = URL(string: address), absolute.scheme != nil {
                    url = absolute
                } else {
                    url = mirror.image(address, repo: repo)
                }
                guard let url, seen.insert(url.absoluteString).inserted else { continue }
                urls.append(url)
            }
        }
        return urls.filter { !isOrnament($0) }
    }

    /// Logos, badges and shields: small, named for decoration, or served by GitHub's badge
    /// service. None of them show the firmware running.
    private static func isOrnament(_ url: URL) -> Bool {
        let words = ["logo", "icon", "badge", "shield", "banner", "avatar"]
        let path = url.path.lowercased()
        if path.contains("img.shields.io") || path.contains("badgen.net") { return true }
        return words.contains { path.contains($0) }
    }
}
