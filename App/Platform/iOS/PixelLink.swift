import SafariServices
import SwiftUI
import UIKit

/// A link: tapping opens it in the in-app browser, and pressing and holding opens the share
/// sheet, as links do elsewhere on iPhone and iPad.
struct PixelLink<Label: View>: View {
    /// Where the link is in its window, for pointing the iPad's share popover at it.
    @State private var frame = CGRect.zero
    @State private var shares = 0
    private let url: URL
    private let label: Label

    init(_ url: URL, @ViewBuilder label: () -> Label) {
        self.url = url
        self.label = label()
    }

    var body: some View {
        label
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                frame = newFrame
            }
            .onTapGesture { InAppBrowser.present(url) }
            .onLongPressGesture { share() }
            .sensoryFeedback(.impact, trigger: shares)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isLink)
            .accessibilityAction { InAppBrowser.present(url) }
            .accessibilityAction(named: "Share") { share() }
    }

    private func share() {
        shares += 1
        ShareSheet.present(url, from: frame)
    }
}

/// The in-app browser: the page stays in the app instead of jumping out to Safari.
/// Presented as a half-height sheet the user can drag up, like the app's other overlays.
/// Safari's own menu still offers opening it outside.
@MainActor
enum InAppBrowser {
    static func present(_ url: URL) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow,
            var top = window.rootViewController
        else { return }
        while let presented = top.presentedViewController {
            top = presented
        }
        let browser = SFSafariViewController(url: url)
        // Half the screen first; dragging the grabber (or scrolling) expands it to full.
        if let sheet = browser.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersGrabberVisible = true
        }
        top.present(browser, animated: true)
    }
}

/// The system share sheet, which SwiftUI's ShareLink can't open from a press and hold.
@MainActor
private enum ShareSheet {
    static func present(_ url: URL, from frame: CGRect) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow,
            var top = window.rootViewController
        else { return }
        while let presented = top.presentedViewController {
            top = presented
        }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // On iPad the sheet is a popover, which needs something to point at.
        sheet.popoverPresentationController?.sourceView = window
        sheet.popoverPresentationController?.sourceRect = frame
        top.present(sheet, animated: true)
    }
}
