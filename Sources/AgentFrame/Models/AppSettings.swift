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
    case idle, busy, done
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
        let httpBusy = "curl -s -X POST http://localhost:\(port)/busy"
        let httpDone = "curl -s -X POST http://localhost:\(port)/done"
        let fileBusy = "echo busy > \(filePath)"
        let fileDone = "echo done > \(filePath)"
        let busyCmd  = (mode == .file) ? fileBusy : httpBusy
        let doneCmd  = (mode == .file) ? fileDone : httpDone

        switch self {
        case .claudeCode:
            return """
            // ~/.claude/settings.json  — add under "hooks"
            {
              "hooks": {
                "PreToolUse": [{
                  "matcher": ".*",
                  "hooks": [{"type": "command", "command": "\(busyCmd)"}]
                }],
                "Stop": [{
                  "matcher": ".*",
                  "hooks": [{"type": "command", "command": "\(doneCmd)"}]
                }]
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
            """
        case .custom:
            return """
            // HTTP endpoints (curl or fetch):
            // Busy : \(httpBusy)
            // Done : \(httpDone)
            // Idle : curl -s -X POST http://localhost:\(port)/idle
            //
            // File alternative:
            // Busy : \(fileBusy)
            // Done : \(fileDone)
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

// MARK: - AppSettings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let systemSounds = ["None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    // Language
    @Published var languageCode: String      { didSet { ud.set(languageCode,         forKey: "languageCode") } }

    // Sound
    @Published var soundEnabled: Bool        { didSet { ud.set(soundEnabled,          forKey: "soundEnabled") } }
    @Published var busySoundName: String     { didSet { ud.set(busySoundName,         forKey: "busySoundName") } }
    @Published var doneSoundName: String     { didSet { ud.set(doneSoundName,         forKey: "doneSoundName") } }

    // Frame appearance
    @Published var busyEnabled: Bool         { didSet { ud.set(busyEnabled,           forKey: "busyEnabled") } }
    @Published var busyColorHex: String      { didSet { ud.set(busyColorHex,          forKey: "busyColorHex") } }
    @Published var doneColorHex: String      { didSet { ud.set(doneColorHex,          forKey: "doneColorHex") } }
    @Published var busyOpacity: Double       { didSet { ud.set(busyOpacity,           forKey: "busyOpacity") } }
    @Published var doneOpacity: Double       { didSet { ud.set(doneOpacity,           forKey: "doneOpacity") } }
    @Published var frameEdgesRaw: Int        { didSet { ud.set(frameEdgesRaw,         forKey: "frameEdgesRaw") } }
    @Published var frameThickness: Double    { didSet { ud.set(frameThickness,        forKey: "frameThickness") } }

    // System
    @Published var launchAtLogin: Bool       { didSet { ud.set(launchAtLogin,         forKey: "launchAtLogin") } }

    // Display
    @Published var selectedScreenIndex: Int  { didSet { ud.set(selectedScreenIndex,   forKey: "selectedScreenIndex") } }
    @Published var followActiveScreen: Bool  { didSet { ud.set(followActiveScreen,    forKey: "followActiveScreen") } }

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
    var busyNSColor: NSColor { NSColor(hex: busyColorHex) ?? .red }
    var doneNSColor: NSColor { NSColor(hex: doneColorHex) ?? NSColor(hex: "#00CC44")! }

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
            : "curl -s -X POST http://localhost:\(httpPort)/busy"
    }

    private func doneCommand() -> String {
        let expanded = (statusFilePath as NSString).expandingTildeInPath
        return integrationMode == .file
            ? "echo done > \(expanded)"
            : "curl -s -X POST http://localhost:\(httpPort)/done"
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

    private let ud = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        let storedLang      = d.string(forKey: "languageCode") ?? "en"
        languageCode        = storedLang == "de" ? "de" : "en"
        soundEnabled        = d.object(forKey: "soundEnabled")        as? Bool   ?? true
        busySoundName       = d.string(forKey: "busySoundName")                  ?? "Tink"
        doneSoundName       = d.string(forKey: "doneSoundName")                  ?? "Glass"
        busyEnabled         = d.object(forKey: "busyEnabled")         as? Bool   ?? true
        busyColorHex        = d.string(forKey: "busyColorHex")                   ?? "#FF4400"
        doneColorHex        = d.string(forKey: "doneColorHex")                   ?? "#00CC44"
        busyOpacity         = d.object(forKey: "busyOpacity")         as? Double ?? 0.85
        doneOpacity         = d.object(forKey: "doneOpacity")         as? Double ?? 0.85
        frameEdgesRaw       = d.object(forKey: "frameEdgesRaw")       as? Int    ?? FrameEdges.all.rawValue
        frameThickness      = d.object(forKey: "frameThickness")      as? Double ?? 8.0
        launchAtLogin       = d.object(forKey: "launchAtLogin")       as? Bool   ?? false
        selectedScreenIndex = d.object(forKey: "selectedScreenIndex") as? Int    ?? -1
        followActiveScreen  = d.object(forKey: "followActiveScreen")  as? Bool   ?? false
        flashEnabled        = d.object(forKey: "flashEnabled")        as? Bool   ?? true
        flashDuration       = d.object(forKey: "flashDuration")       as? Double ?? 1.5
        flashPersistent     = d.object(forKey: "flashPersistent")     as? Bool   ?? false
        autoResetAfterDone  = d.object(forKey: "autoResetAfterDone")  as? Bool   ?? true
        autoResetDelay      = d.object(forKey: "autoResetDelay")      as? Double ?? 2.0
        integrationModeRaw  = d.object(forKey: "integrationModeRaw")  as? Int    ?? IntegrationMode.both.rawValue
        httpPort            = d.object(forKey: "httpPort")            as? Int    ?? 7842
        statusFilePath      = d.string(forKey: "statusFilePath")                 ?? "~/.claude/agent_frame_status"
        agentProviderRaw    = d.object(forKey: "agentProviderRaw")    as? Int    ?? AgentProvider.claudeCode.rawValue
    }
}
