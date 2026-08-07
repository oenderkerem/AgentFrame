import AppKit
import SwiftUI

// MARK: - View model

final class AgentStatusViewModel: ObservableObject {
    @Published var items: [AgentStatusItem] = []
    var onHide:  (() -> Void)?
    var onFocus: ((String) -> Void)?   // called with agent ID
}

struct AgentStatusItem: Identifiable {
    let id: String
    let name: String
    let status: AgentStatus
    let canFocus: Bool
}

// MARK: - SwiftUI view

struct AgentStatusView: View {
    @ObservedObject var model: AgentStatusViewModel
    let settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(model.items) { item in
                    AgentRow(item: item, settings: settings) {
                        model.onFocus?(item.id)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 10)

            Button {
                model.onHide?()
            } label: {
                Text(settings.t("multiagent.hud_hide"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: settings.agentWindowNSColor).opacity(settings.agentWindowOpacity))
        )
    }
}

private struct AgentRow: View {
    let item: AgentStatusItem
    let settings: AppSettings
    let onFocus: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor(for: item.status))
                .frame(width: 7, height: 7)
            Text(item.name)
                .font(.system(size: settings.agentWindowFontSize, weight: .medium))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            Text(statusLabel(item.status))
                .font(.system(size: settings.agentWindowFontSize - 1))
                .foregroundColor(.white.opacity(isHovered && item.canFocus ? 0.9 : 0.65))
            if item.canFocus {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: settings.agentWindowFontSize - 2))
                    .foregroundColor(.white.opacity(isHovered ? 0.85 : 0.3))
            }
        }
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(isHovered && item.canFocus ? 0.08 : 0))
                .padding(.horizontal, -4)
        )
        .onTapGesture { if item.canFocus { onFocus() } }
        .onHover { inside in
            if item.canFocus {
                isHovered = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    private func dotColor(for status: AgentStatus) -> Color {
        switch status {
        case .busy:    return Color(nsColor: settings.busyNSColor)
        case .waiting: return Color(nsColor: settings.waitingNSColor)
        case .done:    return Color(nsColor: settings.doneNSColor)
        case .idle:    return .gray
        }
    }

    private func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .busy:    return settings.t("status.busy")
        case .waiting: return settings.t("status.waiting")
        case .done:    return settings.t("status.done")
        case .idle:    return settings.t("status.idle")
        }
    }
}

// MARK: - Window controller

final class AgentStatusWindowController {
    private var panel: NSPanel?
    private var viewModel = AgentStatusViewModel()
    private var hideTimer: DispatchSourceTimer?
    private var isUserHidden = false
    private var lastKnownAgents: [AgentInfo] = []
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings

        viewModel.onHide = { [weak self] in
            self?.isUserHidden = true
            self?.cancelHideTimer()
            self?.panel?.orderOut(nil)
        }

        viewModel.onFocus = { [weak self] agentId in
            guard let agent = self?.lastKnownAgents.first(where: { $0.id == agentId }) else { return }
            WindowFocusManager.focus(agent: agent)
        }
    }

    func update(agents: [AgentInfo], registry: AgentRegistry) {
        guard settings.agentWindowEnabled else { return }

        isUserHidden = false
        lastKnownAgents = agents

        let items = agents
            .filter { $0.status != .idle }
            .map { AgentStatusItem(
                id: $0.id,
                name: registry.resolvedDisplayName(for: $0),
                status: $0.status,
                canFocus: WindowFocusManager.canFocus($0)
            )}

        viewModel.items = items

        if items.isEmpty {
            if !settings.agentWindowPermanent { panel?.orderOut(nil) }
            return
        }

        ensurePanel()
        positionPanel()
        panel?.orderFront(nil)

        if !settings.agentWindowPermanent {
            scheduleHide(after: settings.multiAgentPopupDuration + 1)
        }
    }

    func hide() {
        cancelHideTimer()
        panel?.orderOut(nil)
    }

    func recreate() {
        hide()
        panel?.close()
        panel = nil
    }

    // MARK: - Private

    private func ensurePanel() {
        if panel == nil {
            let view = AgentStatusView(model: viewModel, settings: settings)
            let hosting = NSHostingView(rootView: view)

            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.backgroundColor = .clear
            p.isOpaque = false
            p.level = .statusBar
            p.isFloatingPanel = true
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            p.isReleasedWhenClosed = false
            p.contentView = hosting
            panel = p
        }

        let hostingView = panel?.contentView as? NSHostingView<AgentStatusView>
        let fit = hostingView?.fittingSize ?? CGSize(width: 220, height: 44)
        panel?.setContentSize(NSSize(width: max(180, fit.width), height: max(36, fit.height)))
    }

    private func positionPanel() {
        guard let p = panel else { return }

        let screen: NSScreen
        let idx = settings.agentWindowScreenIndex
        if idx >= 0, idx < NSScreen.screens.count {
            screen = NSScreen.screens[idx]
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }

        let f = screen.visibleFrame
        let s = p.frame.size
        let pad: CGFloat = 16

        let origin: CGPoint
        switch settings.agentWindowCorner {
        case .topLeft:     origin = CGPoint(x: f.minX + pad,           y: f.maxY - s.height - pad)
        case .topRight:    origin = CGPoint(x: f.maxX - s.width - pad,  y: f.maxY - s.height - pad)
        case .bottomLeft:  origin = CGPoint(x: f.minX + pad,           y: f.minY + pad)
        case .bottomRight: origin = CGPoint(x: f.maxX - s.width - pad,  y: f.minY + pad)
        }

        p.setFrameOrigin(origin)
    }

    private func scheduleHide(after seconds: Double) {
        cancelHideTimer()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + seconds)
        t.setEventHandler { [weak self] in
            self?.panel?.orderOut(nil)
            self?.hideTimer = nil
        }
        t.resume()
        hideTimer = t
    }

    private func cancelHideTimer() {
        hideTimer?.cancel()
        hideTimer = nil
    }
}
