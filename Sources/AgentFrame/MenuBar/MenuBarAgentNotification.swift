import AppKit
import SwiftUI

// MARK: - Popup view

private struct AgentPopupView: View {
    let name: String
    let statusLabel: String
    let dotColor: Color
    let canFocus: Bool
    let onTap: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text("—")
                .foregroundColor(.white.opacity(0.45))
                .font(.system(size: 12))
            Text(statusLabel)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
            if canFocus {
                Spacer(minLength: 6)
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(isHovered && canFocus ? 0.92 : 0.82))
        )
        .contentShape(Rectangle())
        .onTapGesture { if canFocus { onTap?() } }
        .onHover { inside in
            if canFocus { isHovered = inside }
            if inside && canFocus {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Controller

final class MenuBarAgentNotification {
    private var window: NSWindow?
    private var hideTimer: DispatchSourceTimer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show(agentName: String, status: AgentStatus, below buttonFrame: NSRect,
              dotColor: NSColor, onTap: (() -> Void)? = nil) {
        guard settings.multiAgentPopupEnabled else { return }

        let label: String
        switch status {
        case .busy:    label = settings.t("status.busy")
        case .waiting: label = settings.t("status.waiting")
        case .done:    label = settings.t("status.done")
        case .idle:    label = settings.t("status.idle")
        }

        let canFocus = onTap != nil
        let view = AgentPopupView(
            name: agentName, statusLabel: label,
            dotColor: Color(nsColor: dotColor),
            canFocus: canFocus, onTap: {
                onTap?()
            }
        )
        let hosting = NSHostingView(rootView: view)
        let fit = hosting.fittingSize
        let size = NSSize(width: max(160, fit.width), height: max(30, fit.height))

        let x = buttonFrame.midX - size.width / 2
        let y = buttonFrame.minY - size.height - 4

        let w = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: x, y: y), size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.backgroundColor = .clear
        w.isOpaque = false
        w.level = .statusBar
        w.ignoresMouseEvents = !canFocus
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        hosting.frame = NSRect(origin: .zero, size: size)
        w.contentView = hosting

        window?.orderOut(nil)
        window = w
        w.alphaValue = 0
        w.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            w.animator().alphaValue = 1
        }

        scheduleHide(tapAction: onTap)
    }

    // MARK: - Private

    private func scheduleHide(tapAction: (() -> Void)?) {
        hideTimer?.cancel()
        let duration = settings.multiAgentPopupDuration
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + duration)
        t.setEventHandler { [weak self] in self?.animateHide() }
        t.resume()
        hideTimer = t
    }

    func dismissImmediately() {
        hideTimer?.cancel()
        hideTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    private func animateHide() {
        guard let w = window else { return }
        hideTimer = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            w.orderOut(nil)
            if self?.window === w { self?.window = nil }
        })
    }
}
