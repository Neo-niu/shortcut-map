import SwiftUI

struct KeyboardView: View {
    let highlighted: Set<String>

    private let rows: [[String]] = [
        ["⎋", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "⌫"],
        ["⇥", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
        ["Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "↩"],
        ["⇧", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "⇧"],
        ["Fn", "⌃", "⌥", "⌘", "Space", "⌘", "⌥", "←", "↑", "↓", "→"]
    ]

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 7) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        keyView(key)
                    }
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
    }

    private func keyView(_ key: String) -> some View {
        let isHighlighted = highlighted.contains(key.uppercased())
        let width: CGFloat = switch key {
        case "Space": 250
        case "⇧", "Caps", "↩", "⌫": 66
        case "⇥": 58
        default: 42
        }

        return Text(key)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .frame(width: width, height: 40)
            .foregroundStyle(isHighlighted ? Color.black : Color.primary)
            .background(isHighlighted ? Color.accentColor : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.10)))
            .shadow(color: isHighlighted ? Color.accentColor.opacity(0.35) : .clear, radius: 8)
    }
}
