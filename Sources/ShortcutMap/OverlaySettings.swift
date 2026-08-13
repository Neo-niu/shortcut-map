import SwiftUI

enum OverlayActivationMode: String, CaseIterable, Identifiable {
    case hold
    case toggle

    static let defaultsKey = "OverlayActivationMode"

    var id: Self { self }

    var title: String {
        switch self {
        case .hold: "长按显示"
        case .toggle: "切换显示"
        }
    }

    var detail: String {
        switch self {
        case .hold: "按住 ⌃⌥Space 显示，松开后隐藏"
        case .toggle: "按一次 ⌃⌥Space 显示，再按一次隐藏"
        }
    }

    static var current: Self {
        guard let stored = UserDefaults.standard.string(forKey: defaultsKey),
              let mode = Self(rawValue: stored) else {
            return .hold
        }
        return mode
    }
}

struct SettingsView: View {
    @AppStorage(OverlayActivationMode.defaultsKey)
    private var activationMode = OverlayActivationMode.hold.rawValue

    var body: some View {
        Form {
            Picker("浮窗唤起方式", selection: $activationMode) {
                ForEach(OverlayActivationMode.allCases) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.title)
                        Text(mode.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(mode.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 190)
    }
}
