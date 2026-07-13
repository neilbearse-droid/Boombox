import SwiftUI

/// The 4-digit PIN pad. Handles first-run PIN creation, verification with
/// the five-attempt lockout, and PIN changes from settings.
struct PINGateView: View {
    enum Mode {
        /// Verify the existing PIN (creates one on first run).
        case unlock
        /// Set a new PIN (used by Change PIN in settings).
        case change
    }

    private enum Phase {
        case verify
        case createNew
        case confirmNew(String)
    }

    let mode: Mode
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var phase: Phase
    @State private var digits = ""
    @State private var errorText: String?

    init(mode: Mode, onSuccess: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        _phase = State(initialValue: (mode == .change || !PINManager.hasPIN) ? .createNew : .verify)
    }

    private var title: String {
        switch phase {
        case .verify: return "Enter PIN"
        case .createNew: return "Create a PIN"
        case .confirmNew: return "Re-enter PIN"
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let lockout = PINManager.lockoutRemaining
            VStack(spacing: 28) {
                Spacer()

                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                dots

                Group {
                    if let lockout {
                        Text("Locked. Try again in \(Int(lockout.rounded(.up)))s.")
                    } else if let errorText {
                        Text(errorText)
                    } else {
                        Text(" ")
                    }
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.red)

                keypad(disabled: lockout != nil)

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }

    private var dots: some View {
        HStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 2)
                    .background(
                        Circle().fill(i < digits.count ? Color.primary : Color.clear))
                    .frame(width: 18, height: 18)
            }
        }
        .accessibilityLabel("\(digits.count) of 4 digits entered")
    }

    private func keypad(disabled: Bool) -> some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["cancel", "0", "delete"],
        ]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key, disabled: disabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadButton(_ key: String, disabled: Bool) -> some View {
        switch key {
        case "cancel":
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 76, height: 76)
            }
            .accessibilityLabel("Cancel")
        case "delete":
            Button {
                if !digits.isEmpty { digits.removeLast() }
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 76, height: 76)
            }
            .disabled(disabled)
            .accessibilityLabel("Delete")
        default:
            Button {
                tap(key)
            } label: {
                Text(key)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .disabled(disabled)
        }
    }

    private func tap(_ digit: String) {
        guard digits.count < 4 else { return }
        errorText = nil
        digits += digit
        guard digits.count == 4 else { return }
        let pin = digits
        // Let the fourth dot render before resolving.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            resolve(pin)
        }
    }

    private func resolve(_ pin: String) {
        switch phase {
        case .verify:
            if PINManager.verify(pin) {
                onSuccess()
            } else {
                digits = ""
                errorText = PINManager.lockoutRemaining != nil ? nil : "Wrong PIN. Try again."
            }
        case .createNew:
            phase = .confirmNew(pin)
            digits = ""
        case .confirmNew(let first):
            if pin == first {
                PINManager.savePIN(pin)
                onSuccess()
            } else {
                phase = .createNew
                digits = ""
                errorText = "PINs didn't match. Start again."
            }
        }
    }
}
