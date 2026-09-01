import Foundation
import Combine

struct AgentInfo: Identifiable {
    let id: String
    var displayName: String
    var status: AgentStatus
    var lastUpdate: Date
    // Window focus info — populated from HTTP body, preserved across status updates
    var ppid: pid_t?
    var termSessionId: String?
    var itermSessionId: String?
}

final class AgentRegistry: ObservableObject {
    @Published private(set) var agents: [AgentInfo] = []

    private let staleThreshold: TimeInterval = 300
    private var cleanupTimer: DispatchSourceTimer?

    func start() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 60, repeating: 60)
        t.setEventHandler { [weak self] in self?.removeStale() }
        t.resume()
        cleanupTimer = t
    }

    func stop() {
        cleanupTimer?.cancel()
        cleanupTimer = nil
        agents.removeAll()
    }

    func update(
        id: String, displayName: String, status: AgentStatus,
        ppid: pid_t? = nil, termSessionId: String? = nil, itermSessionId: String? = nil
    ) {
        if let i = agents.firstIndex(where: { $0.id == id }) {
            agents[i].status      = status
            agents[i].lastUpdate  = Date()
            agents[i].displayName = displayName
            // Only overwrite focus info when new non-empty values arrive
            if let p = ppid                               { agents[i].ppid           = p }
            if let t = termSessionId,  !t.isEmpty         { agents[i].termSessionId  = t }
            if let s = itermSessionId, !s.isEmpty         { agents[i].itermSessionId = s }
        } else {
            var info = AgentInfo(id: id, displayName: displayName, status: status, lastUpdate: Date())
            info.ppid           = ppid
            info.termSessionId  = termSessionId.flatMap  { $0.isEmpty ? nil : $0 }
            info.itermSessionId = itermSessionId.flatMap { $0.isEmpty ? nil : $0 }
            agents.append(info)
        }
    }

    func resolvedDisplayName(for agent: AgentInfo) -> String {
        let same = agents.filter { $0.displayName == agent.displayName }
        guard same.count > 1 else { return agent.displayName }
        let sorted = same.sorted { $0.id < $1.id }
        guard let i = sorted.firstIndex(where: { $0.id == agent.id }), i > 0 else {
            return agent.displayName
        }
        return "\(agent.displayName) (\(i + 1))"
    }

    var activeAgents: [AgentInfo] {
        agents.filter { $0.status != .idle }
    }

    var aggregateStatus: AgentStatus {
        let active = activeAgents
        if active.isEmpty                                       { return .idle }
        if active.contains(where: { $0.status == .busy })      { return .busy }
        if active.contains(where: { $0.status == .waiting })   { return .waiting }
        if active.contains(where: { $0.status == .done })      { return .done }
        return .idle
    }

    func clearAll() {
        agents.removeAll()
    }

    private func removeStale() {
        let cutoff = Date().addingTimeInterval(-staleThreshold)
        agents.removeAll { $0.status == .idle && $0.lastUpdate < cutoff }
    }
}
