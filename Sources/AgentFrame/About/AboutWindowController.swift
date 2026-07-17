import AppKit
import SwiftUI

final class AboutWindowController: NSWindowController {
    init(settings: AppSettings) {
        let view = AboutView(settings: settings)
        let host = NSHostingController(rootView: view)

        let w = NSWindow(contentViewController: host)
        w.title             = settings.t("about.title")
        w.styleMask         = [.titled, .closable]
        w.setContentSize(NSSize(width: 480, height: 820))
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
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
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
                codeRow("POST /agent_frame/busy")
                codeRow("POST /agent_frame/waiting")
                codeRow("POST /agent_frame/done")
                codeRow("POST /agent_frame/idle")
                codeRow("POST /agent_frame/status   { \"status\": \"busy|...\" }")
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
            VStack(spacing: 4) {
                hookRow(name: "PreToolUse",   signal: "busy",    key: "about.hook_pretooluse")
                hookRow(name: "PostToolUse",  signal: "busy",    key: "about.hook_posttooluse")
                hookRow(name: "Notification", signal: "waiting", key: "about.hook_notification")
                hookRow(name: "Stop",         signal: "done",    key: "about.hook_stop")
                hookRow(name: "SubagentStop", signal: "done",    key: "about.hook_subagent_stop")
            }
            Text(settings.t("about.hook_notification_note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hookRow(name: String, signal: String, key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(name)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
                .frame(width: 118, alignment: .leading)
            Text("→ \(signal)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(settings.t(key))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

}
