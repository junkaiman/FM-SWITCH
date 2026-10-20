import SwiftUI

/// A scroll view that refreshes when pulled down, with ``PixelSpinner`` in place of the system's
/// spinner.
///
/// The spinner sits just above the content, in the gap pulling opens: it fills as the pull
/// grows, and spins while the refresh runs. On the Mac, which has no pull to refresh, it's a plain
/// scroll view.
struct PixelRefreshScrollView<Content: View>: View {
    /// How far to pull before the spinner is full; about where the system starts the refresh.
    private static var fullPull: CGFloat { 90 }

    @State private var pull: CGFloat = 0
    private let isRefreshing: Bool
    private let action: @Sendable () async -> Void
    private let content: Content

    /// - Parameters:
    ///   - isRefreshing: Whether a refresh is running, however it started.
    ///   - action: Runs the refresh.
    ///   - content: What scrolls.
    init(
        isRefreshing: Bool,
        action: @escaping @Sendable () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isRefreshing = isRefreshing
        self.action = action
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(alignment: .top) {
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .named(Self.space)).minY, initial: true) { _, top in
                            pull = max(0, top)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    PixelSpinner(fill: isRefreshing ? nil : min(pull / Self.fullPull, 1))
                        .offset(y: -34)
                        .opacity(pull > 4 ? 1 : 0)
                }
        }
        .coordinateSpace(.named(Self.space))
        .scrollIndicators(.hidden)
        .refreshable { await action() }
    }

    private static var space: String { "pixelRefresh" }
}

/// A lo-fi activity spinner: a ring of eight blocks around an empty middle, like an 8-bit loading
/// icon.
struct PixelSpinner: View {
    @Environment(\.phosphor) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How much of the ring to light, from 0 to 1, or nil to spin.
    var fill: Double?

    /// The ring's cells, clockwise from the top left, as (column, row).
    private static let ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: fill != nil || reduceMotion)) { timeline in
            let head = Int(timeline.date.timeIntervalSinceReferenceDate / 0.09) % Self.ring.count
            Canvas { context, size in
                let cell = size.width / 3
                for (index, (column, row)) in Self.ring.enumerated() {
                    let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect.insetBy(dx: 1, dy: 1)), with: .color(colour(of: index, head: head)))
                }
            }
            .frame(width: 21, height: 21)
        }
        .accessibilityElement()
        .accessibilityLabel(fill == nil ? "Refreshing" : "Pull to refresh")
    }

    private func colour(of index: Int, head: Int) -> Color {
        if let fill {
            return index < Int((fill * Double(Self.ring.count)).rounded(.down)) ? theme.bright : theme.faint
        }
        if reduceMotion { return index.isMultiple(of: 2) ? theme.bright : theme.faint }
        // The lit block runs round the ring with a fading tail.
        switch (head - index + Self.ring.count) % Self.ring.count {
        case 0: return theme.bright
        case 1, 2: return theme.dim
        default: return theme.faint
        }
    }
}
