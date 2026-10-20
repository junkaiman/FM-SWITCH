import SwiftUI

@main
struct FMSwitchApp: App {
    @State private var model = AppModel()

    init() {
        SystemAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.phosphor, model.settings.theme)
                .preferredColorScheme(.dark)
                .tint(model.settings.theme.bright)
                #if DEBUG && os(macOS)
                    .onAppear { DebugSnapshot.scheduleIfAsked() }
                #endif
                #if os(macOS)
                    .frame(minWidth: 420, minHeight: 560)
                #endif
        }
        #if os(macOS)
            // Opens wide enough for the sidebar layout.
            .defaultSize(width: 1180, height: 820)
        #endif
    }
}

/// Everything the screens share.
@MainActor
@Observable
final class AppModel {
    let settings = AppSettings()
    let catalogue = CatalogueStore()
    let library = FirmwareLibrary()
    let history = FlashHistory()
    let device: DeviceController

    init() {
        device = DeviceController(library: library, history: history)
        device.configure(settings.transportKind, settings: settings)
    }

    func applyConnectionSettings() {
        device.configure(settings.transportKind, settings: settings)
    }

    /// Starts MIDI again if it couldn't start before. iOS can start the app before it's opened (or
    /// straight after Xcode installs it), and CoreMIDI may refuse it then.
    func retryConnectionIfUnavailable() {
        guard device.transportError != nil else { return }
        applyConnectionSettings()
    }
}
