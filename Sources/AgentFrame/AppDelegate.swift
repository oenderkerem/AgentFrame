import AppKit
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var menuBarController: MenuBarController!
    private(set) var overlayManager:    FrameOverlayManager!
    private(set) var statusMonitor:     StatusMonitor!
    private(set) var updateChecker:     UpdateChecker!

    private var updateWC:       UpdateWindowController?
    private var agentStatusWC:  AgentStatusWindowController?
    private var menuBarNotif:   MenuBarAgentNotification?
    private var cancellables = Set<AnyCancellable>()

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

        agentStatusWC = AgentStatusWindowController(settings: settings)
        menuBarNotif  = MenuBarAgentNotification(settings: settings)

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

        statusMonitor.onAgentUpdate = { [weak self] agent in
            guard let self, self.settings.multiAgentEnabled else { return }
            DispatchQueue.main.async {
                // Update HUD window
                if self.settings.agentWindowEnabled {
                    self.agentStatusWC?.update(
                        agents: self.statusMonitor.registry.agents,
                        registry: self.statusMonitor.registry
                    )
                }

                // Brief popup below menu bar icon
                if self.settings.multiAgentPopupEnabled,
                   let button = self.menuBarController.statusItemButton,
                   let buttonWindow = button.window {
                    let buttonFrame = buttonWindow.convertToScreen(button.frame)
                    let color = self.dotColor(for: agent.status)
                    let displayName = self.statusMonitor.registry.resolvedDisplayName(for: agent)
                    let capturedAgent = agent
                    let notif = self.menuBarNotif
                    let tapAction: (() -> Void)? = WindowFocusManager.canFocus(agent) ? {
                        WindowFocusManager.focus(agent: capturedAgent)
                        notif?.dismissImmediately()
                    } : nil
                    self.menuBarNotif?.show(
                        agentName: displayName,
                        status: agent.status,
                        below: buttonFrame,
                        dotColor: color,
                        onTap: tapAction
                    )
                }

                // Rebuild menu for per-agent items
                if self.settings.multiAgentMenuItemsEnabled {
                    self.menuBarController.buildMenu()
                }
            }
        }

        // Reset registry when multi-agent mode is toggled
        settings.$multiAgentEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMonitor.restart()
                self?.agentStatusWC?.hide()
            }
            .store(in: &cancellables)

        statusMonitor.start()
        updateChecker.start()
        applyLaunchAtLogin(settings.launchAtLogin)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        observeUpdates()
    }

    private func observeUpdates() {
        updateChecker.$availableVersion
            .compactMap { $0 }
            .filter { version in
                let shown = UserDefaults.standard.string(forKey: "lastShownUpdateVersion")
                return shown != version
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] version in
                UserDefaults.standard.set(version, forKey: "lastShownUpdateVersion")
                self?.showUpdateWindow()
            }
            .store(in: &cancellables)
    }

    func showUpdateWindow() {
        if updateWC == nil {
            updateWC = UpdateWindowController(settings: settings, updateChecker: updateChecker)
        }
        updateWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dotColor(for status: AgentStatus) -> NSColor {
        switch status {
        case .busy:    return settings.busyNSColor
        case .waiting: return settings.waitingNSColor
        case .done:    return settings.doneNSColor
        case .idle:    return .secondaryLabelColor
        }
    }

    @objc private func screensDidChange() {
        overlayManager.recreateWindows()
        agentStatusWC?.recreate()
    }

    func applyLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
