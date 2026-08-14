import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlayContentSize = NSSize(width: 1580, height: 680)
    private let overlayShadowInset: CGFloat = 36
    private var overlayDesignSize: NSSize {
        NSSize(
            width: overlayContentSize.width + overlayShadowInset * 2,
            height: overlayContentSize.height + overlayShadowInset * 2
        )
    }
    let model = ShortcutModel()

    private var overlayPanel: NSPanel?
    private var holdHotKey: HoldHotKey?
    private var started = false
    private var overlayShownAt: ContinuousClock.Instant?
    private var pendingHideTask: Task<Void, Never>?
    private let updateController = GitHubUpdateController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
        updateController.scheduleAutomaticCheck()
    }

    func start() {
        guard !started else { return }
        started = true
        configureOverlay()
        installHoldShortcut()
        if ProcessInfo.processInfo.arguments.contains("--overlay-demo") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1200))
                showOverlay()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pendingHideTask?.cancel()
        holdHotKey?.unregister()
        updateController.cancel()
    }

    func checkForUpdates() {
        updateController.checkManually()
    }

    private func configureOverlay() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: overlayDesignSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The system shadow follows the rectangular NSPanel, not the rounded
        // SwiftUI surface. Draw the shadow inside a transparent inset instead.
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        updateOverlayContent(scale: 1, panel: panel)
        overlayPanel = panel
    }

    private func installHoldShortcut() {
        let hotKey = HoldHotKey(
            onPressed: { [weak self] in self?.hotKeyPressed() },
            onReleased: { [weak self] in self?.hotKeyReleased() }
        )
        holdHotKey = hotKey
        _ = hotKey.register()
    }

    private func hotKeyPressed() {
        switch OverlayActivationMode.current {
        case .hold:
            showOverlay()
        case .toggle:
            if overlayPanel?.isVisible == true {
                hideOverlay(immediately: true)
            } else {
                showOverlay()
            }
        }
    }

    private func hotKeyReleased() {
        guard OverlayActivationMode.current == .hold else { return }
        hideOverlay()
    }

    private func showOverlay() {
        pendingHideTask?.cancel()
        pendingHideTask = nil
        if model.trusted { model.refreshCurrentContext() }
        guard let panel = overlayPanel else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let horizontalMargin: CGFloat = 24
            let verticalMargin: CGFloat = 20
            let availableWidth = max(1, visibleFrame.width - horizontalMargin * 2)
            let availableHeight = max(1, visibleFrame.height - verticalMargin * 2)
            let scale = min(1, availableWidth / overlayDesignSize.width, availableHeight / overlayDesignSize.height)
            updateOverlayContent(scale: scale, panel: panel)
            let size = NSSize(width: overlayDesignSize.width * scale, height: overlayDesignSize.height * scale)
            panel.setContentSize(size)
            panel.setFrameOrigin(NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            ))
        }
        panel.orderFrontRegardless()
        overlayShownAt = .now
    }

    private func updateOverlayContent(scale: CGFloat, panel: NSPanel) {
        let scaledSize = NSSize(width: overlayDesignSize.width * scale, height: overlayDesignSize.height * scale)
        let root = ShortcutOverlayView(model: model)
            .padding(overlayShadowInset)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: scaledSize.width, height: scaledSize.height, alignment: .topLeading)
        panel.contentViewController = NSHostingController(rootView: root)
    }

    private func hideOverlay(immediately: Bool = false) {
        pendingHideTask?.cancel()
        pendingHideTask = nil
        if immediately {
            overlayPanel?.orderOut(nil)
            overlayShownAt = nil
            return
        }
        guard let shownAt = overlayShownAt else {
            overlayPanel?.orderOut(nil)
            return
        }
        let elapsed = shownAt.duration(to: .now)
        let minimum = ProcessInfo.processInfo.arguments.contains("--hotkey-test-linger")
            ? Duration.seconds(3)
            : Duration.milliseconds(180)
        if elapsed < minimum {
            pendingHideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: minimum - elapsed)
                guard !Task.isCancelled else { return }
                self?.overlayPanel?.orderOut(nil)
                self?.overlayShownAt = nil
                self?.pendingHideTask = nil
            }
        } else {
            overlayPanel?.orderOut(nil)
            overlayShownAt = nil
        }
    }
}
