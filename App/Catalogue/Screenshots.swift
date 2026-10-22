import Foundation

/// Finds the screenshots in a firmware project's README, by reading the images it shows.
///
/// Nothing is written down in this app: the images come from whatever the project's own
/// repository lists today, so a firmware's pictures change as its author updates the README.
enum Screenshots {
    /// Up to this many images, in the order the README shows them.
    private static let limit = 8

    /// The image URLs in the project's README, resolved against the repository, or [] if the
    /// README can't be read or shows no usable images.
    static func discover(repo: String, fetch: @escaping (URL) async throws -> Data) async -> [URL] {
        guard let owner = repo.split(separator: "/").first, let name = repo.split(separator: "/").last
        else { return [] }
        for branch in ["main", "master"] {
            guard let url = URL(string: "https://raw.githubusercontent.com/\(owner)/\(name)/\(branch)/README.md")
            else { continue }
            guard let data = try? await fetch(url), let text = String(data: data, encoding: .utf8) else {
                continue
            }
            let images = imageURLs(in: text, repo: repo)
            if !images.isEmpty { return Array(images.prefix(limit)) }
        }
        return []
    }

    /// The images a README shows: markdown `![alt](url)` and HTML `<img src="url">`, relative
    /// paths resolved. Logos, badges and icons aren't screenshots, so they're left out.
    static func imageURLs(in text: String, repo: String) -> [URL] {
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
                guard let matchRange = Range(match.range(at: group), in: text),
                    let url = resolve(text[matchRange], repo: repo)
                else { continue }
                if seen.insert(url.absoluteString).inserted { urls.append(url) }
            }
        }
        return urls.filter { !isOrnament($0) }
    }

    /// A README path, or an absolute address, as a fetchable URL.
    private static func resolve(_ address: Substring, repo: String) -> URL? {
        let text = String(address)
        if let url = URL(string: text), url.scheme != nil { return url }
        // A branch-qualified or plain relative path on GitHub.
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: "./"))
        return URL(string: "https://raw.githubusercontent.com/\(repo)/HEAD/\(cleaned)")
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
