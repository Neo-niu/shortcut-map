import AppKit
import Foundation

@MainActor
final class ShortcutModel: ObservableObject {
    struct AppOption: Identifiable, Equatable {
        let id: pid_t
        let name: String
        let bundleIdentifier: String?
        let icon: NSImage?

        static func == (lhs: AppOption, rhs: AppOption) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private(set) var shortcuts: [Shortcut] = []
    @Published private(set) var appName = "等待识别"
    @Published private(set) var appIcon: NSImage?
    @Published private(set) var inputMethodName = InputMethodCatalog.currentName
    @Published private(set) var issue: String?
    @Published private(set) var trusted: Bool
    @Published var selectedModifiers: Set<Shortcut.Modifier> = [.command]
    @Published var query = ""
    @Published private(set) var availableApps: [AppOption] = []
    @Published var selectedAppPID: pid_t? {
        didSet { applyAppSelection() }
    }

    private var targetApplication: NSRunningApplication?
    private var targetBundleIdentifier: String?
    private var activationObserver: NSObjectProtocol?
    private var permissionTimer: Timer?

    init() {
        let demoMode = ProcessInfo.processInfo.arguments.contains("--demo")
        trusted = demoMode || AXShortcutReader.isTrusted()
        if demoMode {
            appName = "ChatGPT"
            inputMethodName = "微信输入法"
            shortcuts = GlobalShortcutCatalog.shortcuts + Self.demoShortcuts
            return
        }

        refreshAvailableApps()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in self?.consider(app) }
        }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let nowTrusted = AXShortcutReader.isTrusted()
                if nowTrusted != self.trusted {
                    self.trusted = nowTrusted
                    if nowTrusted { self.refresh() }
                }
            }
        }

        if let front = NSWorkspace.shared.frontmostApplication {
            consider(front)
        }
    }

    var filteredShortcuts: [Shortcut] {
        shortcuts.filter { shortcut in
            let matchesModifiers = selectedModifiers.isEmpty || shortcut.modifiers == selectedModifiers
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = needle.isEmpty || [shortcut.action, shortcut.combination, shortcut.menuPath]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(needle)
            return matchesModifiers && matchesQuery
        }
    }

    var highlightedKeys: Set<String> {
        Set(filteredShortcuts.map { $0.key.uppercased() })
    }

    func toggle(_ modifier: Shortcut.Modifier) {
        if selectedModifiers.contains(modifier) {
            selectedModifiers.remove(modifier)
        } else {
            selectedModifiers.insert(modifier)
        }
    }

    func requestPermission() {
        trusted = AXShortcutReader.isTrusted(prompt: true)
    }


    func refresh() {
        refreshAvailableApps()
        guard let app = targetApplication else {
            issue = "请先切换到要识别的 App，再回到快捷键地图。"
            return
        }
        trusted = AXShortcutReader.isTrusted()
        let result = AXShortcutReader.read(pid: app.processIdentifier, appName: app.localizedName ?? "当前 App")
        let catalog = AppShortcutCatalog.shortcuts(bundleIdentifier: targetBundleIdentifier, appName: appName)
        inputMethodName = InputMethodCatalog.currentName
        let appShortcuts = catalog + result.shortcuts.filter { candidate in
            !catalog.contains(where: { $0.key == candidate.key && $0.modifiers == candidate.modifiers })
        }
        shortcuts = GlobalShortcutCatalog.shortcuts + appShortcuts + InputMethodCatalog.shortcuts()
        issue = shortcuts.isEmpty ? result.issue : nil
    }

    /// Re-resolve the frontmost app when operating in follow mode.
    /// Activation notifications are best-effort and can be missed while the
    /// app is hidden or an overlay is being presented.
    func refreshCurrentContext() {
        if selectedAppPID == nil,
           let front = focusedOrFrontmostApplication(),
           front.bundleIdentifier != Bundle.main.bundleIdentifier,
           front.activationPolicy == .regular {
            targetApplication = front
            targetBundleIdentifier = front.bundleIdentifier
            appName = front.localizedName ?? "未知 App"
            appIcon = front.icon
        }
        refresh()
    }

    /// The workspace's frontmost application can briefly be a background
    /// utility when a global hot key fires. The Accessibility focused app is
    /// the application that actually owns keyboard focus, so prefer it when
    /// available and fall back to NSWorkspace only when AX cannot resolve it.
    private func focusedOrFrontmostApplication() -> NSRunningApplication? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedValue
        )
        if status == .success, let focusedValue {
            let focusedElement = focusedValue as! AXUIElement
            var pid: pid_t = 0
            if AXUIElementGetPid(focusedElement, &pid) == .success,
               let app = NSRunningApplication(processIdentifier: pid),
               !app.isTerminated {
                return app
            }
        }
        return NSWorkspace.shared.frontmostApplication
    }

    func refreshAvailableApps() {
        availableApps = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier &&
                !$0.isTerminated
            }
            .map {
                AppOption(
                    id: $0.processIdentifier,
                    name: $0.localizedName ?? "未知 App",
                    bundleIdentifier: $0.bundleIdentifier,
                    icon: $0.icon
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        if let selectedAppPID, !availableApps.contains(where: { $0.id == selectedAppPID }) {
            self.selectedAppPID = nil
        }
    }

    private func applyAppSelection() {
        guard let selectedAppPID else {
            if let front = NSWorkspace.shared.frontmostApplication { consider(front) }
            return
        }
        guard let app = NSRunningApplication(processIdentifier: selectedAppPID), !app.isTerminated else {
            self.selectedAppPID = nil
            return
        }
        setTarget(app)
    }

    private func consider(_ app: NSRunningApplication) {
        guard selectedAppPID == nil else { return }
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier,
              app.activationPolicy == .regular else { return }
        setTarget(app)
    }

    private func setTarget(_ app: NSRunningApplication) {
        targetApplication = app
        targetBundleIdentifier = app.bundleIdentifier
        appName = app.localizedName ?? "未知 App"
        appIcon = app.icon
        refresh()
    }

    private static let demoShortcuts: [Shortcut] = [
        Shortcut(key: "M", modifiers: [.control, .shift], action: "切换模型", menuPath: "App 专属快捷键", source: "ChatGPT 内置规则"),
        Shortcut(key: "N", modifiers: [.command], action: "新建窗口", menuPath: "文件", source: "演示 App 菜单"),
        Shortcut(key: "O", modifiers: [.command], action: "打开…", menuPath: "文件", source: "演示 App 菜单"),
        Shortcut(key: "S", modifiers: [.command], action: "保存", menuPath: "文件", source: "演示 App 菜单"),
        Shortcut(key: "P", modifiers: [.command], action: "打印…", menuPath: "文件", source: "演示 App 菜单"),
        Shortcut(key: "F", modifiers: [.command], action: "查找…", menuPath: "编辑 › 查找", source: "演示 App 菜单"),
        Shortcut(key: "Z", modifiers: [.command], action: "撤销", menuPath: "编辑", source: "演示 App 菜单"),
        Shortcut(key: "Z", modifiers: [.command, .shift], action: "重做", menuPath: "编辑", source: "演示 App 菜单")
    ]
}
