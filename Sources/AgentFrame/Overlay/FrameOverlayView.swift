import SwiftUI

struct FrameOverlayView: View {
    @ObservedObject var model: FrameOverlayViewModel

    var body: some View {
        Canvas { ctx, size in
            guard model.visible else { return }
            let t = model.thickness
            let e = model.edges
            let c = model.swiftUIColor

            if e.contains(.top) {
                ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: t)), with: .color(c))
            }
            if e.contains(.bottom) {
                ctx.fill(Path(CGRect(x: 0, y: size.height - t, width: size.width, height: t)), with: .color(c))
            }
            if e.contains(.left) {
                ctx.fill(Path(CGRect(x: 0, y: 0, width: t, height: size.height)), with: .color(c))
            }
            if e.contains(.right) {
                ctx.fill(Path(CGRect(x: size.width - t, y: 0, width: t, height: size.height)), with: .color(c))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

final class FrameOverlayViewModel: ObservableObject {
    @Published var edges:     FrameEdges = .all
    @Published var thickness: Double     = 8
    @Published var nsColor:   NSColor    = .red
    @Published var opacity:   Double     = 0.85
    @Published var visible:   Bool       = false

    var swiftUIColor: Color {
        Color(nsColor: nsColor).opacity(opacity)
    }

    func apply(status: AgentStatus, settings: AppSettings) {
        edges     = settings.frameEdges
        thickness = settings.frameThickness
        switch status {
        case .idle:
            visible = false
        case .busy:
            nsColor  = settings.busyNSColor
            opacity  = settings.busyOpacity
            visible  = true
        case .done:
            nsColor  = settings.doneNSColor
            opacity  = settings.doneOpacity
            visible  = true
        }
    }
}
