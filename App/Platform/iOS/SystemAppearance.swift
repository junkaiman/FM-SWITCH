import UIKit

/// UIKit's look, where SwiftUI can't set it.
enum SystemAppearance {
    @MainActor static func apply() {
        // Pull to refresh draws a PixelSpinner instead of the system spinner.
        UIRefreshControl.appearance().tintColor = .clear
    }
}
