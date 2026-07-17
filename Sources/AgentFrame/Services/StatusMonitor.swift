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

// MARK: - HTTP Server

final class HTTPStatusServer {
    private var listener: NWListener?
    var onStatus: ((AgentStatus) -> Void)?

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
                  let status = Self.parse(req) else { return }
            self?.onStatus?(status)
        }
    }

    private static func parse(_ request: String) -> AgentStatus? {
        let lines = request.split(separator: "\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2, parts[0] == "POST" else { return nil }
        switch String(parts[1]).trimmingCharacters(in: .whitespaces) {
        case "/agent_frame/busy":    return .busy
        case "/agent_frame/waiting": return .waiting
        case "/agent_frame/done":    return .done
        case "/agent_frame/idle":    return .idle
        case "/agent_frame/status":
            let body = request.components(separatedBy: "\r\n\r\n").last ?? ""
            if body.contains("\"busy\"")    { return .busy }
            if body.contains("\"waiting\"") { return .waiting }
            if body.contains("\"done\"")    { return .done }
            if body.contains("\"idle\"")    { return .idle }
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

// MARK: - StatusMonitor

final class StatusMonitor: ObservableObject {
    @Published private(set) var httpServerRunning    = false
    @Published private(set) var httpServerError:    ServiceDiagnostic? = nil
    @Published private(set) var fileWatcherRunning   = false
    @Published private(set) var fileWatcherError:   ServiceDiagnostic? = nil

    private let httpServer  = HTTPStatusServer()
    private let fileWatcher = FileStatusWatcher()
    private let settings: AppSettings

    var onStatusChange: ((AgentStatus) -> Void)?
    private(set) var currentStatus: AgentStatus = .idle
    private var busyTimeoutWork: DispatchWorkItem?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        let mode = settings.integrationMode

        if mode == .http || mode == .both {
            httpServer.onStatus = { [weak self] s in DispatchQueue.main.async { self?.handle(s) } }
            httpServer.start(port: UInt16(settings.httpPort)) { [weak self] running, diagnostic in
                self?.httpServerRunning = running
                self?.httpServerError   = diagnostic
            }
        }

        if mode == .file || mode == .both {
            fileWatcher.onStatus = { [weak self] s in DispatchQueue.main.async { self?.handle(s) } }
            do {
                try fileWatcher.start(filePath: settings.statusFilePath)
                fileWatcherRunning = true
                fileWatcherError   = nil
            } catch {
                fileWatcherRunning = false
                fileWatcherError   = .capture(message: error.localizedDescription)
            }
        }
    }

    func stop() {
        busyTimeoutWork?.cancel()
        busyTimeoutWork = nil
        httpServer.stop()
        fileWatcher.stop()
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
        handle(status)
    }

    private func handle(_ status: AgentStatus) {
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

        guard status == .busy,
              settings.stuckBusyResetEnabled,
              settings.stuckBusyResetMinutes > 0 else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.handle(.idle)
        }
        busyTimeoutWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settings.stuckBusyResetMinutes * 60, execute: work)
    }
}
