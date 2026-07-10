import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var menuBarController: MenuBarController!
    private(set) var overlayManager:    FrameOverlayManager!
    private(set) var statusMonitor:     StatusMonitor!
    private(set) var updateChecker:     UpdateChecker!

    let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMonitor    = StatusMonitor(settings: settings)
        overlayManager   = FrameOverlayManager(settings: settings)
        updateChecker    = UpdateChecker()
        menuBarController = MenuBarController(
            settings:       settings,
            overlayManager: overlayManager,
            statusMonitor:  statusMonitor,
            updateChecker:  updateChecker
        )

        statusMonitor.onStatusChange = { [weak self] status in
            guard let self else { return }
            let effective: AgentStatus = (status == .busy && !self.settings.busyEnabled) ? .idle : status
            // Note: .waiting intentionally has no auto-reset — stays until next signal
            DispatchQueue.main.async {
                self.overlayManager.update(status: effective)
                self.menuBarController.updateStatus(effective)
                SoundManager.play(for: effective, settings: self.settings)

                if effective == .done && self.settings.autoResetAfterDone && !self.settings.flashPersistent {
                    let delay = self.settings.autoResetDelay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        guard self?.statusMonitor.currentStatus == .done else { return }
                        self?.statusMonitor.setStatus(.idle)
                    }
                }
            }
        }

        statusMonitor.start()
        updateChecker.start()
        applyLaunchAtLogin(settings.launchAtLogin)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensDidChange() {
        overlayManager.recreateWindows()
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
