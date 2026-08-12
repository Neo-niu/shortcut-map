import Carbon
import Foundation

enum GlobalShortcutCatalog {
    static let shortcuts = [
        Shortcut(
            key: "Space",
            modifiers: [.control, .option],
            action: "按住显示快捷键地图",
            menuPath: "快捷键地图",
            source: "快捷键地图系统热键",
            scope: .global
        )
    ]
}

enum InputMethodCatalog {
    private static let weTypeSettingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WeType/mmkv/wetype.settings")

    static var currentName: String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            return "当前输入法"
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    static func shortcuts() -> [Shortcut] {
        guard isWeType(currentName),
              let values = try? MMKVSettingsReader.read(url: weTypeSettingsURL) else { return [] }

        return [
            voiceShortcut(
                values: values,
                enabledKey: "voicePTTHotKey",
                keyCodesKey: "voicePTTShortcut_keyCodes",
                action: "按住语音输入"
            ),
            voiceShortcut(
                values: values,
                enabledKey: "voiceToggleHotKey",
                keyCodesKey: "voiceToggleShortcut_keyCodes",
                action: "切换语音输入"
            )
        ].compactMap { $0 }
    }

    private static func isWeType(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("微信输入法") || name.localizedCaseInsensitiveContains("WeType")
    }

    private static func voiceShortcut(
        values: [String: Data],
        enabledKey: String,
        keyCodesKey: String,
        action: String
    ) -> Shortcut? {
        guard values[enabledKey]?.first == 1,
              let data = values[keyCodesKey],
              let text = mmkvString(data),
              let json = text.data(using: .utf8),
              let keyCodes = try? JSONDecoder().decode([Int].self, from: json),
              let parsed = parseKeyCodes(keyCodes) else { return nil }

        return Shortcut(
            key: parsed.key,
            modifiers: parsed.modifiers,
            action: action,
            menuPath: "微信输入法设置 › 语音输入",
            source: "微信输入法本机配置",
            scope: .inputMethod
        )
    }

    private static func parseKeyCodes(_ keyCodes: [Int]) -> (key: String, modifiers: Set<Shortcut.Modifier>)? {
        var modifiers = Set<Shortcut.Modifier>()
        var key: String?
        for code in keyCodes {
            switch code {
            case 63: modifiers.insert(.fn)
            case 59, 62: modifiers.insert(.control)
            case 58, 61: modifiers.insert(.option)
            case 55, 54: modifiers.insert(.command)
            case 56, 60: modifiers.insert(.shift)
            case 49: key = "Space"
            default: return nil
            }
        }
        if key == nil, modifiers.count == 1, let modifier = modifiers.first {
            key = modifier.rawValue
        }
        guard let key else { return nil }
        return (key, modifiers)
    }

    private static func mmkvString(_ data: Data) -> String? {
        var offset = 0
        guard let length = MMKVSettingsReader.readVarint(data, offset: &offset),
              length == data.count - offset else { return nil }
        return String(data: data[offset...], encoding: .utf8)
    }
}

enum MMKVSettingsReader {
    static func read(url: URL) throws -> [String: Data] {
        let file = try Data(contentsOf: url, options: .mappedIfSafe)
        guard file.count >= 8 else { return [:] }
        let payloadLength = Int(file.prefix(4).enumerated().reduce(UInt32(0)) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        })
        let end = min(file.count, payloadLength + 4)
        var offset = 8
        var result: [String: Data] = [:]
        while offset < end {
            guard let keyLength = readVarint(file, offset: &offset), keyLength > 0,
                  offset + keyLength <= end else { break }
            let keyData = file[offset..<(offset + keyLength)]
            offset += keyLength
            guard let valueLength = readVarint(file, offset: &offset),
                  offset + valueLength <= end else { break }
            if let key = String(data: keyData, encoding: .utf8) {
                result[key] = Data(file[offset..<(offset + valueLength)])
            }
            offset += valueLength
        }
        return result
    }

    static func readVarint(_ data: Data, offset: inout Int) -> Int? {
        var value = 0
        var shift = 0
        while offset < data.count, shift <= 28 {
            let byte = Int(data[offset])
            offset += 1
            value |= (byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        return nil
    }
}
