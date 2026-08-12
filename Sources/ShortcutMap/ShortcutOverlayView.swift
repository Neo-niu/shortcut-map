import SwiftUI

struct ShortcutOverlayView: View {
    @ObservedObject var model: ShortcutModel

    private var lineShortcuts: [Shortcut] {
        Array(model.shortcuts.sorted { lhs, rhs in
            let lhsPriority = lhs.source.contains("内置规则") ? 0 : 1
            let rhsPriority = rhs.source.contains("内置规则") ? 0 : 1
            return (lhsPriority, lhs.combination) < (rhsPriority, rhs.combination)
        }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let icon = model.appIcon {
                    Image(nsImage: icon).resizable().frame(width: 38, height: 38)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.appName) 快捷键地图")
                        .font(.title2.weight(.bold))
                    Text("按住 ⌃⌥Space 查看 · 松开即隐藏")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.shortcuts.count) 个已识别")
                    .font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }

            if model.shortcuts.isEmpty {
                ContentUnavailableView(
                    "没有可展示的快捷键",
                    systemImage: "keyboard.badge.ellipsis",
                    description: Text(model.issue ?? "当前 App 未公开菜单快捷键")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    ShortcutDiagramView(shortcuts: lineShortcuts, appName: model.appName, inputMethodName: model.inputMethodName)
                        .frame(width: 900)
                    CompleteShortcutGrid(
                        shortcuts: model.shortcuts,
                        appName: model.appName,
                        inputMethodName: model.inputMethodName
                    )
                    .frame(width: 610)
                }
            }
        }
        .padding(26)
        .frame(width: 1580, height: 680)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.62), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.28), radius: 35, y: 16)
    }
}

private struct CompleteShortcutGrid: View {
    let shortcuts: [Shortcut]
    let appName: String
    let inputMethodName: String

    private func groups(for scope: Shortcut.Scope) -> [(String, [Shortcut])] {
        let grouped = Dictionary(grouping: shortcuts.filter { $0.scope == scope }) { shortcut in
            if shortcut.modifiers.isEmpty { return "无修饰键" }
            return shortcut.modifiers
                .sorted { modifierOrder($0) < modifierOrder($1) }
                .map(\.rawValue)
                .joined()
        }
        return grouped.sorted { modifierGroupOrder($0.key) < modifierGroupOrder($1.key) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("完整目录").font(.headline)
                Spacer()
                Text("全部 \(shortcuts.count) 条").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Shortcut.Scope.allCases, id: \.self) { scope in
                        let scopedShortcuts = shortcuts.filter { $0.scope == scope }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Image(systemName: scopeIcon(scope))
                                Text(scopeTitle(scope)).font(.subheadline.weight(.bold))
                                Spacer()
                                Text("\(scopedShortcuts.count) 条").font(.caption).foregroundStyle(.secondary)
                            }
                            if scopedShortcuts.isEmpty {
                                Text("尚未识别到可验证快捷键")
                                    .font(.caption).foregroundStyle(.tertiary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(groups(for: scope), id: \.0) { group, items in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 5) {
                                            ForEach(items) { shortcut in
                                                HStack(spacing: 5) {
                                                    Text(shortcut.combination)
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundStyle(Color.accentColor)
                                                        .frame(minWidth: 34, alignment: .leading)
                                                    Text(shortcut.action)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .lineLimit(1)
                                                    Spacer(minLength: 0)
                                                }
                                                .padding(.horizontal, 6)
                                                .frame(height: 25)
                                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                                                .help("\(shortcut.menuPath) · \(shortcut.source)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(14)
        .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }

    private func scopeTitle(_ scope: Shortcut.Scope) -> String {
        switch scope {
        case .global: "全局"
        case .currentApp: "当前 App · \(appName)"
        case .inputMethod: "输入法 · \(inputMethodName)"
        }
    }

    private func scopeIcon(_ scope: Shortcut.Scope) -> String {
        switch scope {
        case .global: "globe"
        case .currentApp: "macwindow"
        case .inputMethod: "character.cursor.ibeam"
        }
    }

    private func modifierOrder(_ modifier: Shortcut.Modifier) -> Int {
        switch modifier {
        case .fn: 0
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }

    private func modifierGroupOrder(_ value: String) -> String {
        let order = ["⌘", "⇧⌘", "⌥⌘", "⌃⌘", "⌥", "⌃", "⇧", "无修饰键"]
        let index = order.firstIndex(of: value) ?? order.count
        return String(format: "%02d-%@", index, value)
    }
}

private struct ShortcutDiagramView: View {
    let shortcuts: [Shortcut]
    let appName: String
    let inputMethodName: String

    private let colors: [Color] = [.cyan, .purple, .orange]
    private let keyboardOrigin = CGPoint(x: 42, y: 24)
    private let keySize = CGSize(width: 42, height: 42)
    private let gap: CGFloat = 7

    private let rows: [[KeySpec]] = [
        [KeySpec("⎋"), KeySpec("1"), KeySpec("2"), KeySpec("3"), KeySpec("4"), KeySpec("5"), KeySpec("6"), KeySpec("7"), KeySpec("8"), KeySpec("9"), KeySpec("0"), KeySpec("-"), KeySpec("="), KeySpec("⌫", 1.5)],
        [KeySpec("⇥", 1.35), KeySpec("Q"), KeySpec("W"), KeySpec("E"), KeySpec("R"), KeySpec("T"), KeySpec("Y"), KeySpec("U"), KeySpec("I"), KeySpec("O"), KeySpec("P"), KeySpec("["), KeySpec("]"), KeySpec("\\")],
        [KeySpec("Caps", 1.55), KeySpec("A"), KeySpec("S"), KeySpec("D"), KeySpec("F"), KeySpec("G"), KeySpec("H"), KeySpec("J"), KeySpec("K"), KeySpec("L"), KeySpec(";"), KeySpec("'"), KeySpec("↩", 1.55)],
        [KeySpec("⇧", 2.05), KeySpec("Z"), KeySpec("X"), KeySpec("C"), KeySpec("V"), KeySpec("B"), KeySpec("N"), KeySpec("M"), KeySpec(","), KeySpec("."), KeySpec("/"), KeySpec("⇧", 2.05)],
        [KeySpec("Fn", 0.9), KeySpec("⌃", 1.2), KeySpec("⌥", 1.2), KeySpec("⌘", 1.35), KeySpec("Space", 5.6), KeySpec("⌘", 1.35), KeySpec("⌥", 1.2), KeySpec("←"), KeySpec("↑"), KeySpec("↓"), KeySpec("→")]
    ]

    var body: some View {
        GeometryReader { geometry in
            let positions = keyPositions()
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for (index, shortcut) in shortcuts.enumerated() {
                        let color = colors[index % colors.count]
                        let labelPoint = CGPoint(x: 150 + CGFloat(index) * 300, y: 455)
                        for token in keyTokens(shortcut) {
                            guard let point = positions[token]?.first else { continue }
                            var path = Path()
                            path.move(to: point)
                            path.addCurve(
                                to: labelPoint,
                                control1: CGPoint(x: point.x, y: point.y + 75),
                                control2: CGPoint(x: labelPoint.x, y: labelPoint.y - 70)
                            )
                            context.stroke(path, with: .color(color.opacity(0.80)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(color))
                        }
                    }
                }

                keyboard(positions: positions)

                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    callout(shortcut, color: colors[index % colors.count])
                        .frame(width: 270, alignment: .leading)
                        .position(x: 150 + CGFloat(index) * 300, y: 500)
                }
            }
        }
    }

    private func keyboard(positions: [String: [CGPoint]]) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(.black.opacity(0.18))
                .frame(width: 850, height: 274)
                .offset(x: 18, y: 10)
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                let placements = placements(for: row, rowIndex: rowIndex)
                ForEach(Array(placements.enumerated()), id: \.offset) { _, placement in
                    let activeColors = shortcuts.enumerated().compactMap { index, shortcut in
                        keyTokens(shortcut).contains(placement.spec.label) ? colors[index % colors.count] : nil
                    }
                    Text(placement.spec.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(width: placement.width, height: keySize.height)
                        .foregroundStyle(activeColors.isEmpty ? Color.primary : Color.white)
                        .background(
                            activeColors.first?.opacity(0.82) ?? Color.white.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12)))
                        .position(placement.center)
                }
            }
        }
    }

    private func callout(_ shortcut: Shortcut, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(shortcut.combination)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text("\(scopeTitle(shortcut.scope)) \(shortcut.action)")
                .font(.headline)
            Text(shortcut.source)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35)))
    }

    private func scopeTitle(_ scope: Shortcut.Scope) -> String {
        switch scope {
        case .global: "全局"
        case .currentApp: appName
        case .inputMethod: inputMethodName
        }
    }

    private func keyTokens(_ shortcut: Shortcut) -> Set<String> {
        var tokens = Set(shortcut.modifiers.map(\.rawValue))
        tokens.insert(shortcut.key.uppercased())
        return tokens
    }

    private func keyPositions() -> [String: [CGPoint]] {
        var result: [String: [CGPoint]] = [:]
        for (rowIndex, row) in rows.enumerated() {
            for placement in placements(for: row, rowIndex: rowIndex) {
                result[placement.spec.label, default: []].append(placement.center)
            }
        }
        return result
    }

    private func placements(for row: [KeySpec], rowIndex: Int) -> [KeyPlacement] {
        var x = keyboardOrigin.x
        let y = keyboardOrigin.y + CGFloat(rowIndex) * (keySize.height + gap)
        return row.map { spec in
            let width = keySize.width * spec.width + gap * (spec.width - 1)
            let center = CGPoint(x: x + width / 2, y: y + keySize.height / 2)
            x += width + gap
            return KeyPlacement(spec: spec, center: center, width: width)
        }
    }
}

private struct KeySpec {
    let label: String
    let width: CGFloat
    init(_ label: String, _ width: CGFloat = 1) {
        self.label = label
        self.width = width
    }
}

private struct KeyPlacement {
    let spec: KeySpec
    let center: CGPoint
    let width: CGFloat
}
