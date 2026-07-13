import SwiftUI

/// The badge worn by the currently playing tile. Static bars in Calm Mode or
/// when the system Reduce Motion setting is on.
struct EqualizerBadge: View {
    let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let staticHeights: [Double] = [0.5, 0.9, 0.65]

    var body: some View {
        let moving = animated && !reduceMotion
        TimelineView(.animation(minimumInterval: 0.12, paused: !moving)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    let fraction = moving
                        ? 0.35 + 0.65 * abs(sin(t * 3 + Double(i) * 1.1))
                        : Self.staticHeights[i]
                    Capsule()
                        .fill(.white)
                        .frame(width: 5, height: 22 * fraction)
                }
            }
            .frame(width: 30, height: 24, alignment: .bottom)
        }
        .padding(8)
        .background(Circle().fill(Color.black.opacity(0.45)))
        .accessibilityHidden(true)
    }
}
