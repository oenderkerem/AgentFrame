import AppKit
import SwiftUI

final class FrameOverlayManager {
    private var overlayWindow:      NSWindow?
    private var viewModel           = FrameOverlayViewModel()
    private let flashCtrl           = FlashWindowController()
    private let settings:             AppSettings
    private var currentStatus:        AgentStatus = .idle
    private var mouseTrackingTimer:   DispatchSourceTimer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Public

    func update(status: AgentStatus) {
        currentStatus = status
        viewModel.apply(status: status, settings: settings)

        switch status {
        case .idle:
            stopMouseTracking()
            overlayWindow?.orderOut(nil)
        case .busy, .waiting:
            ensureOverlayWindow()
            overlayWindow?.orderFrontRegardless()
            startMouseTracking()
        case .done:
            ensureOverlayWindow()
            overlayWindow?.orderFrontRegardless()
            startMouseTracking()
            if settings.flashEnabled {
                let scr = targetScreen()
                flashCtrl.show(
                    on:         scr,
                    color:      settings.doneNSColor,
                    opacity:    settings.doneOpacity,
                    persistent: settings.flashPersistent,
                    duration:   settings.flashDuration
                )
            }
        }
    }

    func recreateWindows() {
        stopMouseTracking()
        overlayWindow?.close()
        overlayWindow = nil
        if currentStatus != .idle {
            ensureOverlayWindow()
            overlayWindow?.orderFrontRegardless()
            startMouseTracking()
        }
    }

    // MARK: - Private

    private func targetScreen() -> NSScreen {
        if settings.followActiveScreen {
            let cursor = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) })
                ?? NSScreen.main ?? NSScreen.screens[0]
        }
        let idx = settings.selectedScreenIndex
        if idx >= 0 && idx < NSScreen.screens.count {
            return NSScreen.screens[idx]
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private func ensureOverlayWindow() {
        guard overlayWindow == nil else {
            moveOverlayToScreen(targetScreen())
            return
        }
        let screen = targetScreen()
        let w = NSWindow(
            contentRect:  screen.frame,
            styleMask:    .borderless,
            backing:      .buffered,
            defer:        false
        )
        w.backgroundColor         = .clear
        w.isOpaque                = false
        w.level                   = .screenSaver
        w.ignoresMouseEvents      = true
        w.collectionBehavior      = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed    = false
        w.contentView             = NSHostingView(rootView: FrameOverlayView(model: viewModel))
        overlayWindow = w
    }

    private func moveOverlayToScreen(_ screen: NSScreen) {
        overlayWindow?.setFrame(screen.frame, display: true)
    }

    private func startMouseTracking() {
        stopMouseTracking()
        guard settings.liveMouseTracking else { return }
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self, self.settings.followActiveScreen,
                  self.settings.liveMouseTracking, self.currentStatus != .idle else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let screen = self.targetScreen()
                guard self.overlayWindow?.frame != screen.frame else { return }
                self.moveOverlayToScreen(screen)
            }
        }
        timer.resume()
        mouseTrackingTimer = timer
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.cancel()
        mouseTrackingTimer = nil
    }
}
