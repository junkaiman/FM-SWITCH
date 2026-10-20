import SwiftUI

/// A link: clicking opens it, and its right-click menu copies or shares it.
struct PixelLink<Label: View>: View {
    private let url: URL
    private let label: Label

    init(_ url: URL, @ViewBuilder label: () -> Label) {
        self.url = url
        self.label = label()
    }

    var body: some View {
        Link(destination: url) { label }
            .contextMenu {
                Button("Copy Link") { Pasteboard.copy(url) }
                ShareLink(item: url)
            }
    }
}
