import Foundation

struct Shortcut: Identifiable, Hashable, Sendable {
    enum Scope: String, CaseIterable, Hashable, Sendable {
        case global
        case currentApp
        case inputMethod
    }

    enum Modifier: String, CaseIterable, Hashable, Sendable {
        case fn = "Fn"
        case command = "⌘"
        case option = "⌥"
        case control = "⌃"
        case shift = "⇧"
    }

    let id: String
    let key: String
    let modifiers: Set<Modifier>
    let action: String
    let menuPath: String
    let source: String
    let scope: Scope

    var combination: String {
        let order: [Modifier] = [.fn, .control, .option, .shift, .command]
        let displayedModifiers = order.filter { modifier in
            modifiers.contains(modifier) && key.caseInsensitiveCompare(modifier.rawValue) != .orderedSame
        }
        return displayedModifiers.map(\.rawValue).joined() + key.uppercased()
    }

    init(
        key: String,
        modifiers: Set<Modifier>,
        action: String,
        menuPath: String,
        source: String,
        scope: Scope = .currentApp
    ) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
        self.menuPath = menuPath
        self.source = source
        self.scope = scope
        self.id = [scope.rawValue, source, menuPath, action, modifiers.map(\.rawValue).sorted().joined(), key].joined(separator: "|")
    }
}
