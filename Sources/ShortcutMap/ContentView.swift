import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: ShortcutModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.trusted {
                permissionView
            } else {
                mainContent
            }
        }
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 34, height: 34)
            } else {
                Image(systemName: "keyboard").font(.title2).frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.appName).font(.headline)
                Text("当前识别对象 · \(model.shortcuts.count) 个菜单快捷键")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Picker("App", selection: $model.selectedAppPID) {
                Label("跟随当前 App", systemImage: "scope")
                    .tag(Optional<pid_t>.none)
                Divider()
                ForEach(model.availableApps) { app in
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        Text(app.name)
                    }
                    .tag(Optional(app.id))
                }
            }
            .labelsHidden()
            .frame(width: 190)
            .help("选择要查看快捷键的 App")
            TextField("搜索功能或组合键", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            Button { model.refresh() } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择修饰键").font(.subheadline.weight(.semibold))
                    HStack {
                        ForEach(Shortcut.Modifier.allCases, id: \.self) { modifier in
                            Button {
                                model.toggle(modifier)
                            } label: {
                                Text(modifier.rawValue)
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 48, height: 38)
                                    .background(
                                        model.selectedModifiers.contains(modifier) ? Color.accentColor : Color.secondary.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 9)
                                    )
                                    .foregroundStyle(model.selectedModifiers.contains(modifier) ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("精确匹配组合").font(.caption).foregroundStyle(.secondary)
                    }
                }

                KeyboardView(highlighted: model.highlightedKeys)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let issue = model.issue {
                    Label(issue, systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("点亮 \(model.highlightedKeys.count) 个键；右侧显示 \(model.filteredShortcuts.count) 条作用说明。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)
            .frame(minWidth: 650, maxWidth: .infinity, alignment: .topLeading)

            Divider()

            shortcutList
                .frame(width: 390)
        }
    }

    private var shortcutList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("快捷键作用").font(.headline)
                Spacer()
                Text("\(model.filteredShortcuts.count)").foregroundStyle(.secondary)
            }
            .padding(16)
            Divider()
            List(model.filteredShortcuts) { shortcut in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(shortcut.action).font(.body.weight(.medium))
                        Spacer(minLength: 8)
                        Text(shortcut.combination)
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Text(shortcut.menuPath.isEmpty ? shortcut.source : shortcut.menuPath)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard.badge.eye")
                .font(.system(size: 54)).foregroundStyle(Color.accentColor)
            Text("需要辅助功能权限").font(.title2.weight(.bold))
            Text("辅助功能只用于读取其他 App 公开的菜单标题和快捷键。系统热键不需要监控你的键盘输入。")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
            VStack(spacing: 10) {
                permissionRow(
                    title: "辅助功能",
                    granted: model.trusted,
                    action: model.requestPermission
                )
            }
            .frame(width: 360)
            Text("授权后回到这里，程序会自动重新扫描。")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? Color.green : Color.orange)
            Text(title).font(.body.weight(.medium))
            Spacer()
            if granted {
                Text("已授权").foregroundStyle(.secondary)
            } else {
                Button("去授权", action: action).buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
