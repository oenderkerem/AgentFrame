import AppKit
import Combine

// MARK: - Supporting types

struct FrameEdges: OptionSet {
    let rawValue: Int
    static let top    = FrameEdges(rawValue: 1 << 0)
    static let right  = FrameEdges(rawValue: 1 << 1)
    static let bottom = FrameEdges(rawValue: 1 << 2)
    static let left   = FrameEdges(rawValue: 1 << 3)
    static let all:  FrameEdges = [.top, .right, .bottom, .left]
    static let none: FrameEdges = []
}

enum AgentStatus: String {
    case idle, busy, waiting, done
}

enum IntegrationMode: Int, CaseIterable {
    case http = 0, file = 1, both = 2
    func label(_ s: AppSettings) -> String {
        switch self {
        case .http:  return "HTTP-Server"
        case .file:  return s.t("integration.mode_file_watch")
        case .both:  return s.t("integration.mode_both")
        }
    }
}

// MARK: - AgentProvider
// Add new cases here to support additional AI agents.
enum AgentProvider: Int, CaseIterable {
    case claudeCode = 0
    case codex      = 1
    case custom     = 2

    func displayName(_ s: AppSettings) -> String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex:      return "OpenAI Codex"
        case .custom:     return s.t("agent.custom")
        }
    }

    func hooksSnippet(port: Int, filePath: String, mode: IntegrationMode) -> String {
        let httpBusy    = "curl -s --max-time 1 -X POST http://localhost:\(port)/agent_frame/busy || true"
        let httpWaiting = "curl -s --max-time 1 -X POST http://localhost:\(port)/agent_frame/waiting || true"
        let httpDone    = "curl -s --max-time 1 -X POST http://localhost:\(port)/agent_frame/done || true"
        let fileBusy    = "echo busy > \(filePath)"
        let fileWaiting = "echo waiting > \(filePath)"
        let fileDone    = "echo done > \(filePath)"
        let busyCmd     = (mode == .file) ? fileBusy    : httpBusy
        let waitingCmd  = (mode == .file) ? fileWaiting : httpWaiting
        let doneCmd     = (mode == .file) ? fileDone    : httpDone

        switch self {
        case .claudeCode:
            return """
            // ~/.claude/settings.json  — add under "hooks"
            {
              "hooks": {
                "PreToolUse":   [{"matcher": ".*", "hooks": [{"type": "command", "command": "\(busyCmd)"}]}],
                "PostToolUse":  [{"matcher": ".*", "hooks": [{"type": "command", "command": "\(busyCmd)"}]}],
                "Notification": [{"matcher": ".*", "hooks": [{"type": "command", "command": "\(waitingCmd)"}]}],
                "Stop":         [{"matcher": ".*", "hooks": [{"type": "command", "command": "\(doneCmd)"}]}]
              }
            }
            """
        case .codex:
            return """
            // ~/.codex/config.json — add or update:
            {
              "onStart": "\(busyCmd)",
              "onFinish": "\(doneCmd)"
            }
            // Note: Codex has no notification hook — waiting state
            // must be triggered manually via POST /waiting if needed.
            """
        case .custom:
            return """
            // HTTP endpoints (curl or fetch):
            // Busy    : \(httpBusy)
            // Waiting : \(httpWaiting)
            // Done    : \(httpDone)
            // Idle    : curl -s --max-time 1 -X POST http://localhost:\(port)/agent_frame/idle || true
            //
            // File alternative:
            // Busy    : \(fileBusy)
            // Waiting : \(fileWaiting)
            // Done    : \(fileDone)
            """
        }
    }
}

// MARK: - NSColor hex helpers

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            srgbRed:   CGFloat((v >> 16) & 0xFF) / 255,
            green:     CGFloat((v >>  8) & 0xFF) / 255,
            blue:      CGFloat( v        & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        guard let c = usingColorSpace(.deviceRGB) else { return "#FF0000" }
        return String(format: "#%02X%02X%02X",
            Int((c.redComponent   * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent  * 255).rounded())
        )
    }
}

// MARK: - Hook installation result

enum HookInstallResult {
    case success(path: String)
    case failure(String)
}

// MARK: - Installed hooks summary

struct InstalledHooks {
    var claudeCode: [String] = []
    var codex:      [String] = []
    var isEmpty: Bool { claudeCode.isEmpty && codex.isEmpty }
}

// MARK: - AppSettings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let systemSounds = ["None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    // Language
    @Published var languageCode: String      { didSet { ud.set(languageCode,         forKey: "languageCode") } }

    // Sound
    @Published var soundEnabled: Bool        { didSet { ud.set(soundEnabled,          forKey: "soundEnabled") } }
    @Published var busySoundName: String     { didSet { ud.set(busySoundName,         forKey: "busySoundName") } }
    @Published var waitingSoundName: String  { didSet { ud.set(waitingSoundName,      forKey: "waitingSoundName") } }
    @Published var doneSoundName: String     { didSet { ud.set(doneSoundName,         forKey: "doneSoundName") } }

    // Frame appearance
    @Published var busyEnabled: Bool         { didSet { ud.set(busyEnabled,           forKey: "busyEnabled") } }
    @Published var busyColorHex: String      { didSet { ud.set(busyColorHex,          forKey: "busyColorHex") } }
    @Published var waitingColorHex: String   { didSet { ud.set(waitingColorHex,       forKey: "waitingColorHex") } }
    @Published var doneColorHex: String      { didSet { ud.set(doneColorHex,          forKey: "doneColorHex") } }
    @Published var busyOpacity: Double       { didSet { ud.set(busyOpacity,           forKey: "busyOpacity") } }
    @Published var waitingOpacity: Double    { didSet { ud.set(waitingOpacity,        forKey: "waitingOpacity") } }
    @Published var doneOpacity: Double       { didSet { ud.set(doneOpacity,           forKey: "doneOpacity") } }
    @Published var frameEdgesRaw: Int        { didSet { ud.set(frameEdgesRaw,         forKey: "frameEdgesRaw") } }
    @Published var frameThickness: Double    { didSet { ud.set(frameThickness,        forKey: "frameThickness") } }

    // System
    @Published var launchAtLogin: Bool       { didSet { ud.set(launchAtLogin,         forKey: "launchAtLogin") } }

    // Display
    @Published var selectedScreenIndex: Int  { didSet { ud.set(selectedScreenIndex,   forKey: "selectedScreenIndex") } }
    @Published var followActiveScreen: Bool  { didSet { ud.set(followActiveScreen,    forKey: "followActiveScreen") } }
    @Published var liveMouseTracking: Bool   { didSet { ud.set(liveMouseTracking,     forKey: "liveMouseTracking") } }

    // Flash
    @Published var flashEnabled: Bool        { didSet { ud.set(flashEnabled,          forKey: "flashEnabled") } }
    @Published var flashDuration: Double     { didSet { ud.set(flashDuration,         forKey: "flashDuration") } }
    @Published var flashPersistent: Bool     { didSet { ud.set(flashPersistent,       forKey: "flashPersistent") } }
    @Published var autoResetAfterDone: Bool  { didSet { ud.set(autoResetAfterDone,    forKey: "autoResetAfterDone") } }
    @Published var autoResetDelay: Double    { didSet { ud.set(autoResetDelay,        forKey: "autoResetDelay") } }

    // Integration
    @Published var integrationModeRaw: Int   { didSet { ud.set(integrationModeRaw,    forKey: "integrationModeRaw") } }
    @Published var httpPort: Int             { didSet { ud.set(httpPort,              forKey: "httpPort") } }
    @Published var statusFilePath: String    { didSet { ud.set(statusFilePath,        forKey: "statusFilePath") } }
    @Published var agentProviderRaw: Int     { didSet { ud.set(agentProviderRaw,      forKey: "agentProviderRaw") } }
    @Published var stuckBusyResetEnabled: Bool   { didSet { ud.set(stuckBusyResetEnabled,  forKey: "stuckBusyResetEnabled") } }
    @Published var stuckBusyResetMinutes: Double { didSet { ud.set(stuckBusyResetMinutes,  forKey: "stuckBusyResetMinutes") } }

    // MARK: - Localization

    func t(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    // MARK: - Computed helpers

    var frameEdges: FrameEdges {
        get { FrameEdges(rawValue: frameEdgesRaw) }
        set { frameEdgesRaw = newValue.rawValue }
    }
    var integrationMode: IntegrationMode {
        get { IntegrationMode(rawValue: integrationModeRaw) ?? .both }
        set { integrationModeRaw = newValue.rawValue }
    }
    var agentProvider: AgentProvider {
        get { AgentProvider(rawValue: agentProviderRaw) ?? .claudeCode }
        set { agentProviderRaw = newValue.rawValue }
    }
    var busyNSColor:    NSColor { NSColor(hex: busyColorHex)    ?? .systemOrange }
    var waitingNSColor: NSColor { NSColor(hex: waitingColorHex) ?? .systemBlue }
    var doneNSColor:    NSColor { NSColor(hex: doneColorHex)    ?? .systemGreen }

    // MARK: - Hook installation

    func installHooks() -> HookInstallResult {
        switch agentProvider {
        case .claudeCode: return installClaudeCodeHooks()
        case .codex:      return installCodexHooks()
        case .custom:     return .failure(t("integration.install_not_supported"))
        }
    }

    private func busyCommand() -> String {
        let expanded = (statusFilePath as NSString).expandingTildeInPath
        return integrationMode == .file
            ? "echo busy > \(expanded)"
            : "curl -s --max-time 1 -X POST http://localhost:\(httpPort)/agent_frame/busy || true"
    }

    private func waitingCommand() -> String {
        let expanded = (statusFilePath as NSString).expandingTildeInPath
        return integrationMode == .file
            ? "echo waiting > \(expanded)"
            : "curl -s --max-time 1 -X POST http://localhost:\(httpPort)/agent_frame/waiting || true"
    }

    private func doneCommand() -> String {
        let expanded = (statusFilePath as NSString).expandingTildeInPath
        return integrationMode == .file
            ? "echo done > \(expanded)"
            : "curl -s --max-time 1 -X POST http://localhost:\(httpPort)/agent_frame/done || true"
    }

    private func installClaudeCodeHooks() -> HookInstallResult {
        let settingsPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/settings.json")
        let settingsURL = URL(fileURLWithPath: settingsPath)

        do {
            var root: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: settingsPath) {
                let data = try Data(contentsOf: settingsURL)
                root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }

            var hooksDict = (root["hooks"] as? [String: Any]) ?? [:]
            let pattern = integrationMode == .file
                ? (statusFilePath as NSString).expandingTildeInPath
                : "localhost:\(httpPort)/"

            func withAgentFrameEntry(in arr: [[String: Any]], cmd: String) -> [[String: Any]] {
                var result = arr.filter { entry in
                    guard let inner = entry["hooks"] as? [[String: Any]] else { return true }
                    return !inner.contains { ($0["command"] as? String)?.contains(pattern) == true }
                }
                result.append(["matcher": ".*", "hooks": [["type": "command", "command": cmd]]])
                return result
            }

            hooksDict["PreToolUse"] = withAgentFrameEntry(
                in: (hooksDict["PreToolUse"] as? [[String: Any]]) ?? [], cmd: busyCommand())
            hooksDict["PostToolUse"] = withAgentFrameEntry(
                in: (hooksDict["PostToolUse"] as? [[String: Any]]) ?? [], cmd: busyCommand())
            hooksDict["Notification"] = withAgentFrameEntry(
                in: (hooksDict["Notification"] as? [[String: Any]]) ?? [], cmd: waitingCommand())
            hooksDict["Stop"] = withAgentFrameEntry(
                in: (hooksDict["Stop"] as? [[String: Any]]) ?? [], cmd: doneCommand())
            root["hooks"] = hooksDict

            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsURL)
            return .success(path: settingsPath)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func installCodexHooks() -> HookInstallResult {
        let configPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".codex/config.json")
        let configURL = URL(fileURLWithPath: configPath)

        do {
            var root: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: configPath) {
                let data = try Data(contentsOf: configURL)
                root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }

            root["onStart"]  = busyCommand()
            root["onFinish"] = doneCommand()

            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: configURL)
            return .success(path: configPath)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Hook removal

    func removeAllAgentHooks() -> [String: HookInstallResult] {
        ["claudeCode": removeClaudeCodeHooks(), "codex": removeCodexHooks()]
    }

    func readInstalledHooks() -> InstalledHooks {
        var result = InstalledHooks()
        let patterns = agentFrameHookPatterns()

        let settingsPath = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/settings.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hooksDict = root["hooks"] as? [String: Any] {
            for key in ["PreToolUse", "PostToolUse", "Notification", "Stop", "SubagentStop"] {
                if let arr = hooksDict[key] as? [[String: Any]] {
                    let hasMatch = arr.contains { entry in
                        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
                        return inner.contains { hook in
                            guard let cmd = hook["command"] as? String else { return false }
                            return patterns.contains { cmd.contains($0) }
                        }
                    }
                    if hasMatch { result.claudeCode.append(key) }
                }
            }
        }

        let configPath = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/config.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            func matches(_ v: Any?) -> Bool {
                guard let cmd = v as? String else { return false }
                return patterns.contains { cmd.contains($0) }
            }
            if matches(root["onStart"])  { result.codex.append("onStart") }
            if matches(root["onFinish"]) { result.codex.append("onFinish") }
        }

        return result
    }

    private func agentFrameHookPatterns() -> [String] {
        let expanded = (statusFilePath as NSString).expandingTildeInPath
        return ["/agent_frame/", expanded]
    }

    private func removeClaudeCodeHooks() -> HookInstallResult {
        let settingsPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".claude/settings.json")
        let settingsURL = URL(fileURLWithPath: settingsPath)

        guard FileManager.default.fileExists(atPath: settingsPath) else {
            return .success(path: settingsPath)
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            guard var hooksDict = root["hooks"] as? [String: Any] else {
                return .success(path: settingsPath)
            }

            let patterns = agentFrameHookPatterns()
            func isAgentFrameEntry(_ entry: [String: Any]) -> Bool {
                guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
                return inner.contains { hook in
                    guard let cmd = hook["command"] as? String else { return false }
                    return patterns.contains { cmd.contains($0) }
                }
            }

            for key in ["PreToolUse", "PostToolUse", "Notification", "Stop", "SubagentStop"] { // SubagentStop kept for removal only
                if let arr = hooksDict[key] as? [[String: Any]] {
                    let filtered = arr.filter { !isAgentFrameEntry($0) }
                    if filtered.isEmpty {
                        hooksDict.removeValue(forKey: key)
                    } else {
                        hooksDict[key] = filtered
                    }
                }
            }
            root["hooks"] = hooksDict

            let outData = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try outData.write(to: settingsURL)
            return .success(path: settingsPath)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func removeCodexHooks() -> HookInstallResult {
        let configPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent(".codex/config.json")
        let configURL = URL(fileURLWithPath: configPath)

        guard FileManager.default.fileExists(atPath: configPath) else {
            return .success(path: configPath)
        }

        do {
            let data = try Data(contentsOf: configURL)
            var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

            let patterns = agentFrameHookPatterns()
            func matchesAgentFrame(_ value: Any?) -> Bool {
                guard let cmd = value as? String else { return false }
                return patterns.contains { cmd.contains($0) }
            }

            if matchesAgentFrame(root["onStart"])  { root.removeValue(forKey: "onStart") }
            if matchesAgentFrame(root["onFinish"]) { root.removeValue(forKey: "onFinish") }

            let outData = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try outData.write(to: configURL)
            return .success(path: configPath)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private let ud = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        let storedLang      = d.string(forKey: "languageCode") ?? "en"
        languageCode        = storedLang == "de" ? "de" : "en"
        soundEnabled        = d.object(forKey: "soundEnabled")        as? Bool   ?? true
        busySoundName       = d.string(forKey: "busySoundName")                  ?? "Tink"
        waitingSoundName    = d.string(forKey: "waitingSoundName")               ?? "Ping"
        doneSoundName       = d.string(forKey: "doneSoundName")                  ?? "Glass"
        busyEnabled         = d.object(forKey: "busyEnabled")         as? Bool   ?? true
        busyColorHex        = d.string(forKey: "busyColorHex")                   ?? "#FF4400"
        waitingColorHex     = d.string(forKey: "waitingColorHex")                ?? "#007AFF"
        doneColorHex        = d.string(forKey: "doneColorHex")                   ?? "#00CC44"
        busyOpacity         = d.object(forKey: "busyOpacity")         as? Double ?? 0.85
        waitingOpacity      = d.object(forKey: "waitingOpacity")      as? Double ?? 0.85
        doneOpacity         = d.object(forKey: "doneOpacity")         as? Double ?? 0.85
        frameEdgesRaw       = d.object(forKey: "frameEdgesRaw")       as? Int    ?? FrameEdges.all.rawValue
        frameThickness      = d.object(forKey: "frameThickness")      as? Double ?? 8.0
        launchAtLogin       = d.object(forKey: "launchAtLogin")       as? Bool   ?? false
        selectedScreenIndex = d.object(forKey: "selectedScreenIndex") as? Int    ?? -1
        followActiveScreen  = d.object(forKey: "followActiveScreen")  as? Bool   ?? false
        liveMouseTracking   = d.object(forKey: "liveMouseTracking")   as? Bool   ?? true
        flashEnabled        = d.object(forKey: "flashEnabled")        as? Bool   ?? true
        flashDuration       = d.object(forKey: "flashDuration")       as? Double ?? 1.5
        flashPersistent     = d.object(forKey: "flashPersistent")     as? Bool   ?? false
        autoResetAfterDone  = d.object(forKey: "autoResetAfterDone")  as? Bool   ?? true
        autoResetDelay      = d.object(forKey: "autoResetDelay")      as? Double ?? 2.0
        integrationModeRaw   = d.object(forKey: "integrationModeRaw")   as? Int    ?? IntegrationMode.both.rawValue
        httpPort             = d.object(forKey: "httpPort")             as? Int    ?? 7842
        statusFilePath       = d.string(forKey: "statusFilePath")                  ?? "~/.claude/agent_frame_status"
        agentProviderRaw     = d.object(forKey: "agentProviderRaw")     as? Int    ?? AgentProvider.claudeCode.rawValue
        stuckBusyResetEnabled = d.object(forKey: "stuckBusyResetEnabled") as? Bool  ?? true
        stuckBusyResetMinutes = d.object(forKey: "stuckBusyResetMinutes") as? Double ?? 5.0
    }
}
