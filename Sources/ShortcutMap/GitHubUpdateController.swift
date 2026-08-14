import AppKit
import Foundation

enum AppVersionComparator {
    static func isReleaseNewer(tag: String, than currentVersion: String, bundledReleaseTag: String?) -> Bool {
        if bundledReleaseTag == tag { return false }
        let value = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let parts = value.split(separator: ".")
        if parts.count == 3, parts[0].count == 4, Int(parts[0]) != nil {
            return bundledReleaseTag != nil
        }
        return isNewer(tag, than: currentVersion)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = numericParts(candidate)
        let currentParts = numericParts(current)
        let count = max(candidateParts.count, currentParts.count)
        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart { return candidatePart > currentPart }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        version.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }
}

@MainActor
final class GitHubUpdateController {
    private struct Release: Decodable, Sendable {
        let tagName: String
        let body: String?
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case htmlURL = "html_url"
        }
    }

    private let repository = "Neo-niu/shortcut-map"
    private let defaults = UserDefaults.standard
    private let checkInterval: TimeInterval = 24 * 60 * 60
    private var checkTask: Task<Void, Never>?
    private var lastCheckKey: String { "githubUpdate.lastCheck.\(repository)" }
    private var skippedVersionKey: String { "githubUpdate.skippedVersion.\(repository)" }

    func scheduleAutomaticCheck() {
        if let lastCheck = defaults.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < checkInterval { return }
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await self?.check(manual: false)
        }
    }

    func checkManually() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in await self?.check(manual: true) }
    }

    func cancel() {
        checkTask?.cancel()
        checkTask = nil
    }

    private func check(manual: Bool) async {
        do {
            let release = try await fetchLatestRelease()
            defaults.set(Date(), forKey: lastCheckKey)
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            let bundledReleaseTag = Bundle.main.object(forInfoDictionaryKey: "GitHubReleaseTag") as? String
            guard AppVersionComparator.isReleaseNewer(
                tag: release.tagName,
                than: currentVersion,
                bundledReleaseTag: bundledReleaseTag
            ) else {
                if manual { showMessage(title: "快捷键地图已是最新版", detail: "当前版本：\(currentVersion)") }
                return
            }
            if !manual, defaults.string(forKey: skippedVersionKey) == release.tagName { return }
            showAvailable(release, currentVersion: currentVersion)
        } catch {
            if manual { showMessage(title: "暂时无法检查更新", detail: "请检查网络后重试。\n\(error.localizedDescription)", warning: true) }
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Shortcut-Map-update-checker", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    private func showAvailable(_ release: Release, currentVersion: String) {
        let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let alert = NSAlert()
        alert.messageText = "快捷键地图有新版本 \(release.tagName)"
        alert.informativeText = notes.isEmpty ? "当前版本：\(currentVersion)" : "当前版本：\(currentVersion)\n\n\(String(notes.prefix(800)))"
        alert.addButton(withTitle: "查看并下载")
        alert.addButton(withTitle: "稍后提醒")
        alert.addButton(withTitle: "跳过此版本")
        NSRunningApplication.current.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: NSWorkspace.shared.open(release.htmlURL)
        case .alertThirdButtonReturn: defaults.set(release.tagName, forKey: skippedVersionKey)
        default: break
        }
    }

    private func showMessage(title: String, detail: String, warning: Bool = false) {
        let alert = NSAlert()
        alert.alertStyle = warning ? .warning : .informational
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        NSRunningApplication.current.activate()
        alert.runModal()
    }
}
