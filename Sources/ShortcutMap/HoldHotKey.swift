import Carbon
import Foundation

@MainActor
final class HoldHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPressed: () -> Void
    private let onReleased: () -> Void

    init(onPressed: @escaping () -> Void, onReleased: @escaping () -> Void) {
        self.onPressed = onPressed
        self.onReleased = onReleased
    }

    func register() -> Bool {
        unregister()
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = eventTypes.withUnsafeBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                    var receivedID = EventHotKeyID()
                    let parameterStatus = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &receivedID
                    )
                    guard parameterStatus == noErr, receivedID.id == 1 else { return parameterStatus }
                    let owner = Unmanaged<HoldHotKey>.fromOpaque(userData).takeUnretainedValue()
                    let kind = GetEventKind(event)
                    Task { @MainActor in
                        if kind == UInt32(kEventHotKeyPressed) {
                            owner.onPressed()
                        } else if kind == UInt32(kEventHotKeyReleased) {
                            owner.onReleased()
                        }
                    }
                    return noErr
                },
                buffer.count,
                buffer.baseAddress,
                userData,
                &eventHandlerRef
            )
        }
        guard handlerStatus == noErr else {
            NSLog("ShortcutMap hotkey handler registration failed: %d", handlerStatus)
            return false
        }

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("SCMP"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        NSLog("ShortcutMap hotkey registration status: %d", status)
        UserDefaults.standard.set(Int(status), forKey: "HotKeyRegistrationStatus")
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    private func fourCharacterCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
