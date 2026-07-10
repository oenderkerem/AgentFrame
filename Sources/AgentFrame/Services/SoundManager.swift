import AppKit

enum SoundManager {
    static func play(for status: AgentStatus, settings: AppSettings) {
        guard settings.soundEnabled else { return }
        let name: String
        switch status {
        case .busy: name = settings.busySoundName
        case .done: name = settings.doneSoundName
        case .idle: return
        }
        guard name != "None", !name.isEmpty else { return }
        NSSound(named: .init(name))?.play()
    }
}
