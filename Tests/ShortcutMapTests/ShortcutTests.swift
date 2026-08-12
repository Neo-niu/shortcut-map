import Testing
@testable import ShortcutMap

struct ShortcutTests {
    @Test func combinationUsesMacModifierOrder() {
        let shortcut = Shortcut(
            key: "K",
            modifiers: [.command, .shift, .option, .control],
            action: "Test",
            menuPath: "File",
            source: "Test"
        )
        #expect(shortcut.combination == "⌃⌥⇧⌘K")
    }

    @Test func combinationUppercasesKey() {
        let shortcut = Shortcut(
            key: "p",
            modifiers: [.command],
            action: "Print",
            menuPath: "File",
            source: "Test"
        )
        #expect(shortcut.combination == "⌘P")
    }

    @Test func chatGPTCatalogContainsModelSwitcher() {
        let shortcuts = AppShortcutCatalog.shortcuts(bundleIdentifier: "com.openai.codex", appName: "ChatGPT")
        #expect(shortcuts.count == 1)
        #expect(shortcuts.first?.combination == "⌃⇧M")
        #expect(shortcuts.first?.action == "切换模型")
    }

    @Test func globalCatalogMarksGlobalScope() {
        #expect(GlobalShortcutCatalog.shortcuts.first?.scope == .global)
        #expect(GlobalShortcutCatalog.shortcuts.first?.combination == "⌃⌥SPACE")
    }

    @Test func fnCombinationUsesMacModifierOrder() {
        let shortcut = Shortcut(
            key: "Space",
            modifiers: [.fn, .command],
            action: "Test",
            menuPath: "Test",
            source: "Test"
        )
        #expect(shortcut.combination == "Fn⌘SPACE")
    }

    @Test func singleFnIsNotDuplicated() {
        let shortcut = Shortcut(
            key: "Fn",
            modifiers: [.fn],
            action: "Test",
            menuPath: "Test",
            source: "Test"
        )
        #expect(shortcut.combination == "FN")
    }

    @Test func singleShiftIsNotDuplicated() {
        let shortcut = Shortcut(
            key: "⇧",
            modifiers: [.shift],
            action: "Test",
            menuPath: "Test",
            source: "Test"
        )
        #expect(shortcut.combination == "⇧")
    }
}
