import AppKit
import ApplicationServices
import Foundation

struct AXReadResult: Sendable {
    let shortcuts: [Shortcut]
    let issue: String?
}

enum AXShortcutReader {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func read(pid: pid_t, appName: String) -> AXReadResult {
        guard isTrusted() else {
            return AXReadResult(shortcuts: [], issue: "需要开启“辅助功能”权限后才能读取其他 App 的菜单。")
        }

        let app = AXUIElementCreateApplication(pid)
        guard let menuBar: AXUIElement = value(app, attribute: kAXMenuBarAttribute as String) else {
            return AXReadResult(shortcuts: [], issue: "\(appName) 没有向辅助功能接口公开菜单栏。")
        }

        var output: [Shortcut] = []
        walk(menuBar, path: [], appName: appName, output: &output)
        let unique = Dictionary(grouping: output, by: \.id).compactMap(\.value.first)
        return AXReadResult(
            shortcuts: unique.sorted {
                ($0.menuPath, $0.action, $0.combination) < ($1.menuPath, $1.action, $1.combination)
            },
            issue: unique.isEmpty ? "没有从 \(appName) 的菜单中读到快捷键。" : nil
        )
    }

    private static func walk(_ element: AXUIElement, path: [String], appName: String, output: inout [Shortcut]) {
        let role: String? = value(element, attribute: kAXRoleAttribute as String)
        let title: String = value(element, attribute: kAXTitleAttribute as String) ?? ""
        var nextPath = path

        if !title.isEmpty, role == (kAXMenuBarItemRole as String) || role == (kAXMenuItemRole as String) {
            nextPath.append(title)
        }

        if role == (kAXMenuItemRole as String),
           !title.isEmpty,
           let key = shortcutKey(for: element),
           !key.isEmpty {
            let parentPath = nextPath.dropLast().joined(separator: " › ")
            output.append(
                Shortcut(
                    key: key,
                    modifiers: modifiers(for: element),
                    action: title,
                    menuPath: parentPath,
                    source: "\(appName) 菜单"
                )
            )
        }

        let children: [AXUIElement] = value(element, attribute: kAXChildrenAttribute as String) ?? []
        for child in children {
            walk(child, path: nextPath, appName: appName, output: &output)
        }
    }

    private static func shortcutKey(for element: AXUIElement) -> String? {
        if let character: String = value(element, attribute: kAXMenuItemCmdCharAttribute as String), !character.isEmpty {
            return normalize(character)
        }
        if let virtualKey: NSNumber = value(element, attribute: kAXMenuItemCmdVirtualKeyAttribute as String) {
            return virtualKeyNames[virtualKey.intValue] ?? "Key \(virtualKey.intValue)"
        }
        return nil
    }

    private static func modifiers(for element: AXUIElement) -> Set<Shortcut.Modifier> {
        let raw: NSNumber? = value(element, attribute: kAXMenuItemCmdModifiersAttribute as String)
        return modifiers(rawValue: raw?.uint32Value ?? 0)
    }

    static func modifiers(rawValue flags: UInt32) -> Set<Shortcut.Modifier> {
        var result: Set<Shortcut.Modifier> = []
        if flags & (1 << 3) == 0 { result.insert(.command) }
        if flags & (1 << 0) != 0 { result.insert(.shift) }
        if flags & (1 << 1) != 0 { result.insert(.option) }
        if flags & (1 << 2) != 0 { result.insert(.control) }
        return result
    }

    private static func normalize(_ value: String) -> String {
        let special: [String: String] = [
            "\r": "↩", "\n": "↩", "\t": "⇥", "\u{1b}": "⎋", " ": "Space",
            "\u{8}": "⌫", "\u{7f}": "⌫", "\u{f700}": "↑", "\u{f701}": "↓",
            "\u{f702}": "←", "\u{f703}": "→", "\u{f728}": "⌦"
        ]
        return special[value] ?? value.uppercased()
    }

    private static func value<T>(_ element: AXUIElement, attribute: String) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }
        return raw as? T
    }

    private static let virtualKeyNames: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 71: "Clear",
        76: "↩", 115: "Home", 116: "Page Up", 117: "⌦", 119: "End", 121: "Page Down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}
