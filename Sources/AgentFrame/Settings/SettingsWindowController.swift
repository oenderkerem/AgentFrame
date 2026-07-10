import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings, statusMonitor: StatusMonitor) {
        let view = SettingsView(settings: settings, statusMonitor: statusMonitor)
        let host = NSHostingController(rootView: view)

        let w = NSWindow(contentViewController: host)
        w.title             = "AgentFrame"
        w.styleMask         = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 540, height: 480))
        w.center()
        w.isReleasedWhenClosed = false

        super.init(window: w)
    }

    required init?(coder: NSCoder) { fatalError() }
}
