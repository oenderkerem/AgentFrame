import AppKit
import SwiftUI

final class AboutWindowController: NSWindowController {
    init(settings: AppSettings) {
        let view = AboutView(settings: settings)
        let host = NSHostingController(rootView: view)

        let w = NSWindow(contentViewController: host)
        w.title             = settings.t("about.title")
        w.styleMask         = [.titled, .closable]
        w.setContentSize(NSSize(width: 480, height: 700))
        w.center()
        w.isReleasedWhenClosed = false

        super.init(window: w)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - View

private struct AboutView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Divider()
                howItWorks
                Divider()
                httpSection
                Divider()
                fileSection
                Divider()
                hookSection
                Spacer(minLength: 8)
            }
            .padding(28)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("AgentFrame")
                    .font(.title2).bold()
                Text(settings.t("about.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                Link(settings.t("about.support"),
                     destination: URL(string: "https://ko-fi.com/oender")!)
                    .font(.caption)
                    .foregroundColor(Color(red: 1.0, green: 0.37, blue: 0.36))
            }
            Spacer()
        }
    }

    // MARK: How it works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("about.how_it_works"))
                .font(.headline)
            Text(settings.t("about.how_desc"))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                statusRow(color: .orange,    icon: "rectangle.fill",           key: "about.state_busy")
                statusRow(color: .blue,      icon: "ellipsis.rectangle.fill",  key: "about.state_waiting")
                statusRow(color: .green,     icon: "checkmark.rectangle.fill", key: "about.state_done")
                statusRow(color: .secondary, icon: "rectangle.dashed",         key: "about.state_idle")
                statusRow(color: .secondary, icon: "slider.horizontal.3",      key: "about.customize_hint")
            }
        }
    }

    private func statusRow(color: Color, icon: String, key: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(settings.t(key))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    // MARK: HTTP API

    private var httpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("about.http_title"))
                .font(.headline)
            Text(settings.t("about.http_desc"))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                codeRow("POST /busy")
                codeRow("POST /done")
                codeRow("POST /idle")
                codeRow("POST /status   { \"status\": \"busy|done|idle\" }")
            }
        }
    }

    private func codeRow(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
    }

    // MARK: File Watching

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("about.file_title"))
                .font(.headline)
            Text(settings.t("about.file_desc"))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                codeRow("echo busy > ~/.claude/agent_frame_status")
                codeRow("echo done > ~/.claude/agent_frame_status")
                codeRow("echo idle > ~/.claude/agent_frame_status")
            }
        }
    }

    // MARK: Hooks

    private var hookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("about.hooks_title"))
                .font(.headline)
            Text(settings.t("about.hooks_desc"))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}
