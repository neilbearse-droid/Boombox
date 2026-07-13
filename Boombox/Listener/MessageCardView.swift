import SwiftUI

/// The only error surface the listener ever sees: one friendly full-screen
/// card with literal wording and a single Back button. Never an alert.
struct MessageCardView: View {
    let message: String
    var buttonTitle: String = "Back"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.accentColor.opacity(0.15)))
            }
            .accessibilityLabel(buttonTitle)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
}
