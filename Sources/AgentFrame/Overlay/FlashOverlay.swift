import AppKit
import SwiftUI

// MARK: - Flash view

struct FlashOverlayView: View {
    let color:     Color
    let opacity:   Double
    let showText:  Bool
    let closeText: String
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            color.opacity(opacity)
                .ignoresSafeArea()
            if showText {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    Text(closeText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(radius: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss?() }
    }
}

// MARK: - Flash window

final class FlashNSWindow: NSWindow {
    var onClick: (() -> Void)?

    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onClick?()
    }
}

final class FlashWindowController {
    private var window: FlashNSWindow?

    func show(on screen: NSScreen, color: NSColor, opacity: Double, persistent: Bool, duration: Double) {
        dismiss()

        let closeText = AppSettings.shared.t("flash.close_text")

        let w = FlashNSWindow(
            contentRect:  screen.frame,
            styleMask:    .borderless,
            backing:      .buffered,
            defer:        false
        )
        w.backgroundColor         = .clear
        w.isOpaque                = false
        w.level                   = .screenSaver
        w.collectionBehavior      = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed    = false
        w.ignoresMouseEvents      = !persistent
        w.alphaValue              = 0

        let view = FlashOverlayView(
            color:     Color(nsColor: color),
            opacity:   opacity,
            showText:  persistent,
            closeText: closeText,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        w.contentView = NSHostingView(rootView: view)
        if persistent { w.onClick = { [weak self] in self?.dismiss() } }

        w.orderFrontRegardless()
        if persistent { w.makeKey() }
        self.window = w

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = 1.0
        }) { [weak self] in
            guard !persistent else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        guard let w = window else { return }
        window = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            w.animator().alphaValue = 0
        }) {
            w.orderOut(nil)
        }
    }
}
