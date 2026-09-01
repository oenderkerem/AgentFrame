import Foundation
import Network

// MARK: - Diagnostic

struct ServiceDiagnostic {
    let message: String
    let stackTrace: String

    var fullDescription: String {
        "Error: \(message)\n\nStack Trace:\n\(stackTrace)"
    }

    static func capture(message: String) -> ServiceDiagnostic {
        ServiceDiagnostic(
            message: message,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )
    }
}

// MARK: - File Watcher Errors

enum FileWatcherError: LocalizedError {
    case cannotCreateDirectory(String, underlying: Error)
    case cannotCreateFile(String)
    case cannotOpen(String, posixCode: Int32)

    var errorDescription: String? {
        switch self {
        case .cannotCreateDirectory(let path, let err):
            return "Cannot create directory '\(path)': \(err.localizedDescription)"
        case .cannotCreateFile(let path):
            return "Cannot create status file at '\(path)' — check write permissions"
        case .cannotOpen(let path, let code):
            let posix = String(utf8String: strerror(code)) ?? "POSIX error \(code)"
            return "Cannot open '\(path)': \(posix) (errno \(code))"
        }
    }
}

// MARK: - Agent Update

struct AgentUpdate {
    let status: AgentStatus
    let agentName: String
    let agentId: String
    var ppid: pid_t?
    var termSessionId: String?
    var itermSessionId: String?
}

// MARK: - HTTP Server

final class HTTPStatusServer {
    private var listener: NWListener?
    var onAgentUpdate: ((AgentUpdate) -> Void)?

    func start(port: UInt16, onState: @escaping (Bool, ServiceDiagnostic?) -> Void) {
        guard let p = NWEndpoint.Port(rawValue: port) else {
            DispatchQueue.main.async {
                onState(false, .capture(message: "Invalid port number: \(port)"))
            }
            return
        }

        let l: NWListener
        do {
            l = try NWListener(using: .tcp, on: p)
        } catch {
            DispatchQueue.main.async {
                onState(false, .capture(message: error.localizedDescription))
            }
            return
        }
        listener = l

        l.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DispatchQueue.main.async { onState(true, nil) }
            case .failed(let error):
                DispatchQueue.main.async {
                    onState(false, .capture(message: error.localizedDescription))
                }
            case .cancelled:
                DispatchQueue.main.async { onState(false, nil) }
            default:
                break
            }
        }

        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .utility))
            self?.readRequest(conn)
        }
        l.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
    }

    private func readRequest(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            defer {
                let resp = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
                conn.send(content: resp.data(using: .utf8),
                          completion: .contentProcessed { _ in conn.cancel() })
            }
            guard let data, let req = String(data: data, encoding: .utf8),
                  let update = Self.parse(req) else { return }
            self?.onAgentUpdate?(update)
        }
    }

    private static func parse(_ request: String) -> AgentUpdate? {
        let lines = request.split(separator: "\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2, parts[0] == "POST" else { return nil }

        let path = String(parts[1]).trimmingCharacters(in: .whitespaces)
        let body = request.components(separatedBy: "\r\n\r\n").last ?? ""

        var agentName    = "Agent"
        var agentPidStr  = ""
        var ppid:         pid_t?
        var termSession:  String?
        var itermSession: String?

        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let name = json["name"] as? String, !name.isEmpty { agentName = name }
            if let pid = json["pid"] as? String       { agentPidStr = pid; ppid = pid_t(pid) }
            else if let pid = json["pid"] as? Int     { agentPidStr = "\(pid)"; ppid = pid_t(pid) }
            termSession  = json["term_session"]  as? String
            itermSession = json["iterm_session"] as? String
        }
        let agentId = agentPidStr.isEmpty ? agentName : "\(agentName):\(agentPidStr)"

        func update(_ status: AgentStatus) -> AgentUpdate {
            AgentUpdate(status: status, agentName: agentName, agentId: agentId,
                        ppid: ppid, termSessionId: termSession, itermSessionId: itermSession)
        }

        switch path {
        case "/agent_frame/busy":    return update(.busy)
        case "/agent_frame/waiting": return update(.waiting)
        case "/agent_frame/done":    return update(.done)
        case "/agent_frame/idle":    return update(.idle)
        case "/agent_frame/status":
            if body.contains("\"busy\"")    { return update(.busy) }
            if body.contains("\"waiting\"") { return update(.waiting) }
            if body.contains("\"done\"")    { return update(.done) }
            if body.contains("\"idle\"")    { return update(.idle) }
            return nil
        default: return nil
        }
    }
}

// MARK: - File Watcher

final class FileStatusWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    var onStatus: ((AgentStatus) -> Void)?

    func start(filePath: String) throws {
        let path = (filePath as NSString).expandingTildeInPath

        if !FileManager.default.fileExists(atPath: path) {
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent().path
            do {
                try FileManager.default.createDirectory(
                    atPath: dir, withIntermediateDirectories: true)
            } catch {
                throw FileWatcherError.cannotCreateDirectory(dir, underlying: error)
            }
            guard FileManager.default.createFile(atPath: path, contents: nil) else {
                throw FileWatcherError.cannotCreateFile(path)
            }
        }

        fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            throw FileWatcherError.cannotOpen(path, posixCode: errno)
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .global(qos: .utility))
        src.setEventHandler { [weak self, path] in
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  let status = AgentStatus(rawValue: raw) else { return }
            self?.onStatus?(status)
        }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
        if fd >= 0 { close(fd); fd = -1 }
    }
}

// MARK: - Directory Status Watcher (multi-agent file mode)

final class DirectoryStatusWatcher {
    var onAgentUpdate: ((String, AgentStatus) -> Void)?

    private var timer: DispatchSourceTimer?
    private var lastSeen: [String: String] = [:]
    private var dirPath = ""

    func start(directoryPath: String) throws {
        dirPath = (directoryPath as NSString).expandingTildeInPath
        do {
            try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        } catch {
            throw FileWatcherError.cannotCreateDirectory(dirPath, underlying: error)
        }

        scan()

        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.scan() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        lastSeen.removeAll()
    }

    private func scan() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { return }

        var current: [String: String] = [:]

        for filename in files where !filename.hasPrefix(".") {
            let path = (dirPath as NSString).appendingPathComponent(filename)
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            current[filename] = raw
            if lastSeen[filename] != raw, let status = AgentStatus(rawValue: raw) {
                let name = filename
                let s = status
                DispatchQueue.main.async { [weak self] in self?.onAgentUpdate?(name, s) }
            }
        }

        for (filename, _) in lastSeen where current[filename] == nil {
            let name = filename
            DispatchQueue.main.async { [weak self] in self?.onAgentUpdate?(name, .idle) }
        }

        lastSeen = current
    }
}

// MARK: - StatusMonitor

final class StatusMonitor: ObservableObject {
    @Published private(set) var httpServerRunning    = false
    @Published private(set) var httpServerError:    ServiceDiagnostic? = nil
    @Published private(set) var fileWatcherRunning   = false
    @Published private(set) var fileWatcherError:   ServiceDiagnostic? = nil

    private let httpServer  = HTTPStatusServer()
    private let fileWatcher = FileStatusWatcher()
    private var dirWatcher: DirectoryStatusWatcher?
    private let settings: AppSettings

    let registry = AgentRegistry()

    var onStatusChange: ((AgentStatus) -> Void)?
    var onAgentUpdate: ((AgentInfo) -> Void)?

    private(set) var currentStatus: AgentStatus = .idle
    private var busyTimeoutWork: DispatchWorkItem?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        let mode = settings.integrationMode

        if mode == .http || mode == .both {
            httpServer.onAgentUpdate = { [weak self] update in
                DispatchQueue.main.async { self?.handle(update) }
            }
            httpServer.start(port: UInt16(settings.httpPort)) { [weak self] running, diagnostic in
                self?.httpServerRunning = running
                self?.httpServerError   = diagnostic
            }
        }

        if mode == .file || mode == .both {
            if settings.multiAgentEnabled {
                startDirectoryWatcher()
            } else {
                startFileWatcher()
            }
        }

        registry.start()
    }

    func stop() {
        busyTimeoutWork?.cancel()
        busyTimeoutWork = nil
        httpServer.stop()
        fileWatcher.stop()
        dirWatcher?.stop()
        dirWatcher = nil
        registry.stop()
        httpServerRunning  = false
        httpServerError    = nil
        fileWatcherRunning = false
        fileWatcherError   = nil
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.start()
        }
    }

    func setStatus(_ status: AgentStatus) {
        handle(AgentUpdate(status: status, agentName: "Agent", agentId: "single"))
    }

    // MARK: - Private

    private func startFileWatcher() {
        fileWatcher.onStatus = { [weak self] s in
            DispatchQueue.main.async {
                self?.handle(AgentUpdate(status: s, agentName: "Agent", agentId: "single"))
            }
        }
        do {
            try fileWatcher.start(filePath: settings.statusFilePath)
            fileWatcherRunning = true
            fileWatcherError   = nil
        } catch {
            fileWatcherRunning = false
            fileWatcherError   = .capture(message: error.localizedDescription)
        }
    }

    private func startDirectoryWatcher() {
        let dw = DirectoryStatusWatcher()
        dw.onAgentUpdate = { [weak self] name, status in
            self?.handle(AgentUpdate(status: status, agentName: name, agentId: name))
        }
        do {
            try dw.start(directoryPath: settings.multiAgentDirPath)
            fileWatcherRunning = true
            fileWatcherError   = nil
        } catch {
            fileWatcherRunning = false
            fileWatcherError   = .capture(message: error.localizedDescription)
        }
        dirWatcher = dw
    }

    private func handle(_ update: AgentUpdate) {
        if settings.multiAgentEnabled {
            handleMultiAgent(update)
        } else {
            handleSingle(update.status)
        }
    }

    private func handleMultiAgent(_ update: AgentUpdate) {
        // Per-agent waiting filter: only accept waiting if agent was busy
        if update.status == .waiting {
            let agentStatus = registry.agents.first(where: { $0.id == update.agentId })?.status
            if agentStatus != .busy { return }
        }

        registry.update(
            id: update.agentId, displayName: update.agentName, status: update.status,
            ppid: update.ppid, termSessionId: update.termSessionId, itermSessionId: update.itermSessionId
        )

        let newAggregate = registry.aggregateStatus
        if newAggregate != currentStatus {
            currentStatus = newAggregate
            onStatusChange?(newAggregate)
            manageBusyTimeout(for: newAggregate)
        }

        if let info = registry.agents.first(where: { $0.id == update.agentId }) {
            onAgentUpdate?(info)
        }
    }

    private func handleSingle(_ status: AgentStatus) {
        busyTimeoutWork?.cancel()
        busyTimeoutWork = nil

        // The Notification hook fires for ALL Claude Code notifications, including
        // task-completion alerts — not only "waiting for input" events. Only honour
        // the waiting signal when the agent is actively busy; ignore it otherwise.
        if status == .waiting && currentStatus != .busy { return }

        if status != currentStatus {
            currentStatus = status
            onStatusChange?(status)
        }

        manageBusyTimeout(for: status)
    }

    private func manageBusyTimeout(for status: AgentStatus) {
        busyTimeoutWork?.cancel()
        busyTimeoutWork = nil

        guard status == .busy,
              settings.stuckBusyResetEnabled,
              settings.stuckBusyResetMinutes > 0 else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.settings.multiAgentEnabled {
                for agent in self.registry.agents where agent.status == .busy {
                    self.registry.update(id: agent.id, displayName: agent.displayName, status: .idle)
                }
                let agg = self.registry.aggregateStatus
                if agg != self.currentStatus {
                    self.currentStatus = agg
                    self.onStatusChange?(agg)
                }
            } else {
                self.handleSingle(.idle)
            }
        }
        busyTimeoutWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settings.stuckBusyResetMinutes * 60, execute: work)
    }
}
