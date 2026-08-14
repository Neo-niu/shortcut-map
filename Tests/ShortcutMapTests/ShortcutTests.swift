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

    @Test func overlayActivationModesHaveStableStoredValues() {
        #expect(OverlayActivationMode.hold.rawValue == "hold")
        #expect(OverlayActivationMode.toggle.rawValue == "toggle")
        #expect(OverlayActivationMode.allCases.count == 2)
    }

    @Test func accessibilityMenuModifierMaskUsesMacOSBitLayout() {
        #expect(AXShortcutReader.modifiers(rawValue: 0) == [.command])
        #expect(AXShortcutReader.modifiers(rawValue: 1 << 0) == [.shift, .command])
        #expect(AXShortcutReader.modifiers(rawValue: 1 << 1) == [.option, .command])
        #expect(AXShortcutReader.modifiers(rawValue: 1 << 2) == [.control, .command])
        #expect(AXShortcutReader.modifiers(rawValue: 1 << 3).isEmpty)
        #expect(AXShortcutReader.modifiers(rawValue: 0b1111) == [.shift, .option, .control])
    }

    @Test func versionComparisonUsesNumericComponents() {
        #expect(AppVersionComparator.isNewer("v0.1.1", than: "0.1.0"))
        #expect(AppVersionComparator.isNewer("1.0.0", than: "0.9.99"))
        #expect(!AppVersionComparator.isNewer("0.1.0", than: "0.1.0"))
        #expect(!AppVersionComparator.isNewer("0.1.9", than: "0.1.10"))
        #expect(!AppVersionComparator.isNewer("1.2.0", than: "1.2"))
        #expect(!AppVersionComparator.isReleaseNewer(
            tag: "v2026.08.13",
            than: "0.1.0",
            bundledReleaseTag: "v2026.08.13"
        ))
        #expect(AppVersionComparator.isReleaseNewer(
            tag: "v2026.08.14",
            than: "0.1.0",
            bundledReleaseTag: "v2026.08.13"
        ))
    }
}
