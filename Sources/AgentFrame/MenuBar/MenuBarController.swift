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
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: settings.t("menu.about"),
                                   action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

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

    private func statusTitle(for status: AgentStatus) -> String {
        switch status {
        case .idle: return settings.t("menu.status_idle")
        case .busy: return settings.t("menu.status_busy")
        case .done: return settings.t("menu.status_done")
        }
    }

    // MARK: - Actions

    @objc private func openUpdate() {
        updateChecker.openReleasesPage()
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
