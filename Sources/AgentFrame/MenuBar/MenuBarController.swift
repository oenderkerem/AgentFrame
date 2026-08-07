import AppKit
import Combine

final class MenuBarController {
    private var statusItem: NSStatusItem!
    private let settings:       AppSettings
    private let overlayManager: FrameOverlayManager
    private let statusMonitor:  StatusMonitor
    private let updateChecker:  UpdateChecker
    private var settingsWC:     SettingsWindowController?
    private var aboutWC:        AboutWindowController?
    private var cancellables = Set<AnyCancellable>()

    var statusItemButton: NSButton? { statusItem.button }

    private enum MenuTag: Int { case statusLabel = 1 }

    init(settings: AppSettings, overlayManager: FrameOverlayManager,
         statusMonitor: StatusMonitor, updateChecker: UpdateChecker) {
        self.settings       = settings
        self.overlayManager = overlayManager
        self.statusMonitor  = statusMonitor
        self.updateChecker  = updateChecker
        setup()

        settings.objectWillChange
            .merge(with: statusMonitor.objectWillChange)
            .merge(with: updateChecker.objectWillChange)
            .debounce(for: .milliseconds(80), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.buildMenu() }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil)
        img?.isTemplate = true
        statusItem.button?.image = img
        buildMenu()
    }

    func buildMenu() {
        let menu = NSMenu()

        // Server warning (shown only when HTTP is enabled and not running)
        if (settings.integrationMode == .http || settings.integrationMode == .both), !statusMonitor.httpServerRunning {
            let errorMsg: String
            if statusMonitor.httpServerError != nil {
                errorMsg = String(format: settings.t("menu.server_port_in_use"), settings.httpPort)
            } else {
                errorMsg = settings.t("menu.server_starting_warn")
            }
            let warnItem = NSMenuItem(title: errorMsg, action: #selector(openSettings), keyEquivalent: "")
            warnItem.target = self
            menu.addItem(warnItem)
            menu.addItem(.separator())
        }

        // Status label
        let labelItem = NSMenuItem(title: statusTitle(for: statusMonitor.currentStatus), action: nil, keyEquivalent: "")
        labelItem.isEnabled = false
        labelItem.tag = MenuTag.statusLabel.rawValue
        menu.addItem(labelItem)

        // Per-agent items (multi-agent mode)
        if settings.multiAgentEnabled && settings.multiAgentMenuItemsEnabled {
            for agent in statusMonitor.registry.activeAgents {
                let displayName = statusMonitor.registry.resolvedDisplayName(for: agent)
                let focusable = WindowFocusManager.canFocus(agent)
                let item = NSMenuItem(title: "", action: focusable ? #selector(focusAgent(_:)) : nil, keyEquivalent: "")
                item.target = focusable ? self : nil
                item.isEnabled = focusable
                item.representedObject = agent.id
                item.attributedTitle = agentMenuItemString(name: displayName, status: agent.status, focusable: focusable)
                menu.addItem(item)
            }
        }

        // Server status
        if settings.integrationMode == .http || settings.integrationMode == .both {
            let serverItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            serverItem.isEnabled = false
            serverItem.attributedTitle = serverStatusString()
            menu.addItem(serverItem)
        }

        menu.addItem(.separator())

        if let version = updateChecker.availableVersion {
            let updateItem = NSMenuItem(
                title: String(format: settings.t("menu.update_available"), version),
                action: #selector(openUpdate),
                keyEquivalent: "")
            updateItem.target = self
            updateItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
            menu.addItem(updateItem)
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: settings.t("menu.settings"),
                                      action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: settings.t("menu.about"),
                                   action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let kofiItem = NSMenuItem(title: settings.t("menu.support_kofi"),
                                  action: #selector(openKofi), keyEquivalent: "")
        kofiItem.target = self
        kofiItem.image = NSImage(systemSymbolName: "heart", accessibilityDescription: nil)
        menu.addItem(kofiItem)

        menu.addItem(NSMenuItem(title: settings.t("menu.quit"),
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Status updates

    func updateStatus(_ status: AgentStatus) {
        statusItem.menu?.item(withTag: MenuTag.statusLabel.rawValue)?.title = statusTitle(for: status)
    }

    private func serverStatusString() -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let small = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)

        if statusMonitor.httpServerRunning {
            let str = NSMutableAttributedString(
                string: "● ",
                attributes: [.foregroundColor: NSColor.systemGreen, .font: font])
            str.append(NSAttributedString(
                string: "Port \(settings.httpPort)",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: small]))
            return str
        } else if statusMonitor.httpServerError != nil {
            let str = NSMutableAttributedString(
                string: "● ",
                attributes: [.foregroundColor: NSColor.systemRed, .font: font])
            str.append(NSAttributedString(
                string: String(format: settings.t("menu.server_port_unavailable"), settings.httpPort),
                attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: small]))
            return str
        } else {
            return NSAttributedString(
                string: "◌ \(settings.t("menu.server_starting"))",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: small])
        }
    }

    @objc private func focusAgent(_ sender: NSMenuItem) {
        guard let agentId = sender.representedObject as? String,
              let agent = statusMonitor.registry.agents.first(where: { $0.id == agentId }) else { return }
        WindowFocusManager.focus(agent: agent)
    }

    private func agentMenuItemString(name: String, status: AgentStatus, focusable: Bool) -> NSAttributedString {
        let font  = NSFont.menuFont(ofSize: 0)
        let small = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)

        let dotColor: NSColor
        switch status {
        case .busy:    dotColor = settings.busyNSColor
        case .waiting: dotColor = settings.waitingNSColor
        case .done:    dotColor = settings.doneNSColor
        case .idle:    dotColor = .secondaryLabelColor
        }

        let str = NSMutableAttributedString(
            string: "● ",
            attributes: [.foregroundColor: dotColor, .font: font])
        str.append(NSAttributedString(
            string: name,
            attributes: [.foregroundColor: NSColor.labelColor, .font: small]))
        str.append(NSAttributedString(
            string: "  \(statusTitle(for: status))",
            attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: small]))
        if focusable {
            str.append(NSAttributedString(
                string: "  ↗",
                attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: small]))
        }
        return str
    }

    private func statusTitle(for status: AgentStatus) -> String {
        switch status {
        case .idle:    return settings.t("menu.status_idle")
        case .busy:    return settings.t("menu.status_busy")
        case .waiting: return settings.t("menu.status_waiting")
        case .done:    return settings.t("menu.status_done")
        }
    }

    // MARK: - Actions

    @objc private func openUpdate() {
        guard let delegate = NSApp.delegate as? AppDelegate else {
            updateChecker.openReleasesPage()
            return
        }
        delegate.showUpdateWindow()
    }

    @objc private func openKofi() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/oender")!)
    }

    @objc private func openAbout() {
        if aboutWC == nil {
            aboutWC = AboutWindowController(settings: settings)
        }
        aboutWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(settings: settings, statusMonitor: statusMonitor)
        }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}
