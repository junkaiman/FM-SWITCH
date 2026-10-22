import SwiftUI

/// A firmware's picture, fetched from its GitHub social preview, framed like the pixel panels.
/// GitHub serves it at 1280 x 640, so it reads as a wide banner.
struct FirmwareImage: View {
    @Environment(\.phosphor) private var theme
    let entry: CatalogueEntry
    /// The height of the banner.
    var height: CGFloat = 150

    var body: some View {
        ZStack {
            Rectangle().fill(theme.surface)
            if let url = entry.socialPreviewURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder("NO PICTURE")
                    default:
                        placeholder("…")
                    }
                }
            } else {
                placeholder("NO PICTURE")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .overlay(PixelBox().strokeBorder(theme.faint, lineWidth: 2))
        .accessibilityLabel("Picture of \(entry.name)")
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.pixel(11, relativeTo: .caption))
            .foregroundStyle(theme.faint)
    }
}
