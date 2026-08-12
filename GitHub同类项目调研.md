# GitHub 同类项目调研

调研日期：2026-08-12
状态：首轮完成

## 结论

GitHub 上有高度相关项目，但暂未发现一个成熟项目同时完成以下四件事：

1. 汇总 macOS 全局快捷键；
2. 自动读取当前前台 App 快捷键；
3. 用完整虚拟键盘呈现可用按键；
4. 在按键旁显示“组合键 + 作用”，并随前台 App 切换。

最接近的组合是：以 KeyClu 或 KeyMinder 的菜单快捷键读取能力为参考，以 Keyty 或 KeyCastr 的事件监听和浮层呈现为参考，自行实现虚拟键盘映射层。

## 最相关项目

| 项目 | 能力 | 缺口 | 活跃度与许可 | 参考价值 |
|---|---|---|---|---|
| [KeyClu](https://github.com/Anze/KeyCluCask) | 展示当前 App 菜单快捷键；也可展示 macOS、skhd、自定义快捷键；支持搜索、收藏、导出 | 主要是分组清单，不是完整虚拟键盘；无法证明能枚举所有第三方全局热键 | 约 2.5k stars；2026-07 有提交；BSD-3-Clause-Clear | 最高，接近数据层和产品触发方式 |
| [KeyMinder](https://github.com/dvdweyer/KeyMinder) | 通过 Accessibility 读取当前 App 菜单，按菜单分组、搜索、按修饰键筛选 | 没有全局快捷键汇总和虚拟键盘 | 新项目，约 24 stars；2026-07 有提交；GPL-3.0 | 代码较新，适合研究 Accessibility 菜单解析；GPL 代码不能直接并入闭源产品 |
| [Keyty](https://github.com/keytyapp/Keyty) | 原生 Swift 实时展示键盘、鼠标、历史与浮层布局 | 展示“刚按了什么”，不读取当前 App 可用快捷键及作用 | 新项目，约 48 stars；2026-08 活跃；BSD-3-Clause | 适合参考虚拟键盘、事件监听、权限和浮层 |
| [KeyCastr](https://github.com/keycastr/keycastr) | 成熟的按键/鼠标事件可视化，可扩展 visualizer | 不理解按键作用，不生成 App 快捷键地图；Objective-C 较旧 | 约 15k stars；2026-05 有提交；BSD-3-Clause | 适合参考输入监听、安全输入过滤和浮层机制 |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Swift 包：注册、录制并检测本程序的全局快捷键冲突 | 不是系统级快捷键枚举器 | 约 2.7k stars；2026-06 活跃；MIT | 可用于本程序自己的唤起快捷键与设置界面 |

> 星标与活跃度是 2026-08-12 的 GitHub 快照，会随时间变化。

## 能否直接复用

- 可复用思路：Accessibility 菜单遍历、前台 App 监听、输入事件监听、浮层窗口、键位模型、权限引导。
- 可直接借鉴许可较宽松的项目：KeyClu、Keyty、KeyCastr、KeyboardShortcuts，但仍需保留许可与版权声明。
- KeyMinder 当前为 GPL-3.0：可以研究行为和接口，但若复制/衍生其代码，会影响整个产品的发布许可。
- 不建议直接 Fork 某一个项目作为产品基础，因为目标横跨“发现快捷键”和“实时可视化”两套架构。

## 产品空位

建议定位为“会随当前 App 变化的快捷键地图”，而不是普通的按键显示器：

- 主视图：Mac 虚拟键盘；按住 ⌘ / ⌥ / ⌃ / ⇧ 后，点亮当前可用组合。
- 旁注：动作名称、所属菜单、来源、是否全局、是否可能冲突。
- 自动切换：当前台 App 改变时刷新快捷键地图。
- 全局层：只展示有明确来源的系统设置、用户配置和已支持工具配置；不承诺无依据的“全量扫描”。

## 关键边界

macOS 的 Accessibility API 能读取许多 App 菜单中公开的快捷键，但以下内容可能缺失：

- 未出现在菜单中的内部快捷键；
- 网页自身或编辑器上下文相关的快捷键；
- 第三方后台程序以私有方式注册的全局热键；
- 根据焦点、文档或模式动态变化的命令。

因此每条快捷键应记录来源，例如“当前 App 菜单”“macOS 设置”“用户导入”“skhd 配置”，并显示覆盖边界。

## 建议的 MVP

1. 只做 macOS。
2. 读取当前前台 App 菜单快捷键。
3. 用 ANSI Mac 键盘布局高亮组合，旁边显示动作名称。
4. 支持按住修饰键过滤，以及搜索动作。
5. 第二阶段再接系统全局快捷键、Raycast/Alfred/Keyboard Maestro/skhd 等配置源。
