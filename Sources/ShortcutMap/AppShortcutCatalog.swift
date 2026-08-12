import Foundation

enum AppShortcutCatalog {
    static func shortcuts(bundleIdentifier: String?, appName: String) -> [Shortcut] {
        switch bundleIdentifier {
        case "com.openai.codex":
            return [
                Shortcut(
                    key: "M",
                    modifiers: [.control, .shift],
                    action: "切换模型",
                    menuPath: "App 专属快捷键",
                    source: "ChatGPT 内置规则"
                )
            ]
        default:
            return []
        }
    }
}
