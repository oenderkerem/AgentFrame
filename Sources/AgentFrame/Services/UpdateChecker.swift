import AppKit
import Combine

final class UpdateChecker: ObservableObject {
    private static let apiURL      = "https://api.github.com/repos/oenderkerem/AgentFrame/releases/latest"
    static let releasesURL         = "https://github.com/oenderkerem/AgentFrame/releases/latest"

    @Published var availableVersion: String? = nil
    @Published var releaseNotes: String? = nil

    private var timer: Timer?
    private let interval: TimeInterval = 6 * 3600  // every 6 hours

    func start() {
        check()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func openReleasesPage() {
        guard let url = URL(string: Self.releasesURL) else { return }
        NSWorkspace.shared.open(url)
    }

    private func check() {
        guard !currentVersion.contains("dev") else { return }
        guard let url = URL(string: Self.apiURL) else { return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("AgentFrame/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag  = json["tag_name"] as? String else { return }

            let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let body   = json["body"] as? String
            DispatchQueue.main.async {
                if self.isNewer(remote) {
                    self.availableVersion = remote
                    self.releaseNotes     = body?.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    self.availableVersion = nil
                    self.releaseNotes     = nil
                }
            }
        }.resume()
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private func isNewer(_ remote: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.split(separator: ".").compactMap { Int($0) } }
        let r = parts(remote), c = parts(currentVersion)
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}
