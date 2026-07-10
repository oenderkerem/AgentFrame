import SwiftUI

private let portFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .none
    f.usesGroupingSeparator = false
    return f
}()

struct IntegrationTab: View {
    @ObservedObject var settings:      AppSettings
    @ObservedObject var statusMonitor: StatusMonitor
    @State private var copied = false
    @State private var installResult: HookInstallResult? = nil

    private func transportRow(icon: String, titleKey: String, descKey: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(titleKey)).fontWeight(.medium)
                Text(settings.t(descKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var snippet: String {
        settings.agentProvider.hooksSnippet(
            port:     settings.httpPort,
            filePath: (settings.statusFilePath as NSString).expandingTildeInPath,
            mode:     settings.integrationMode
        )
    }

    private var hookDescription: String {
        switch settings.agentProvider {
        case .claudeCode: return settings.t("integration.hook_desc_claude")
        case .codex:      return settings.t("integration.hook_desc_codex")
        case .custom:     return settings.t("integration.hook_desc_custom")
        }
    }

    private var supportsAutoInstall: Bool {
        settings.agentProvider == .claudeCode || settings.agentProvider == .codex
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(settings.t("integration.overview_title")) {
                    Text(settings.t("integration.overview_desc"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    transportRow(icon: "network",                  titleKey: "integration.transport_http_title",  descKey: "integration.transport_http_desc")
                    transportRow(icon: "doc.text.magnifyingglass", titleKey: "integration.transport_file_title", descKey: "integration.transport_file_desc")
                    Label(settings.t("integration.overview_global_hint"), systemImage: "checkmark.seal")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section(settings.t("integration.server_status")) {
                    ServerStatusView(settings: settings, statusMonitor: statusMonitor)
                }

                Section(settings.t("integration.agent")) {
                    Picker(settings.t("integration.agent"), selection: Binding(
                        get: { settings.agentProvider },
                        set: { settings.agentProvider = $0 }
                    )) {
                        ForEach(AgentProvider.allCases, id: \.rawValue) { p in
                            Text(p.displayName(settings)).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(settings.t("integration.transport")) {
                    Picker(settings.t("integration.method"), selection: Binding(
                        get: { settings.integrationMode },
                        set: { settings.integrationMode = $0 }
                    )) {
                        ForEach(IntegrationMode.allCases, id: \.rawValue) { m in
                            Text(m.label(settings)).tag(m)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if settings.integrationMode == .http || settings.integrationMode == .both {
                        HStack {
                            Text("HTTP-Port")
                            TextField("Port", value: $settings.httpPort, formatter: portFormatter)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    if settings.integrationMode == .file || settings.integrationMode == .both {
                        HStack {
                            Text(settings.t("integration.file_path"))
                            TextField(settings.t("integration.path_placeholder"),
                                      text: $settings.statusFilePath)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Section(settings.t("integration.hook_config")) {
                    Text(hookDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView {
                        Text(snippet)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                    }
                    .frame(height: 120)

                    HStack(spacing: 12) {
                        Button(copied
                               ? settings.t("integration.copied")
                               : settings.t("integration.copy_to_clipboard")) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        }

                        if supportsAutoInstall {
                            Button(settings.t("integration.install_auto")) {
                                installResult = settings.installHooks()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { installResult = nil }
                            }
                        }
                    }

                    if let result = installResult {
                        switch result {
                        case .success(let path):
                            Label(
                                String(format: settings.t("integration.installed"), path),
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                            .font(.caption)
                        case .failure(let err):
                            Label(err, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding([.top, .horizontal])

            Divider()

            HStack {
                Spacer()
                Button(settings.t("integration.apply_restart")) {
                    statusMonitor.restart()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - Server status indicator

private struct ServerStatusView: View {
    @ObservedObject var settings:      AppSettings
    @ObservedObject var statusMonitor: StatusMonitor
    @State private var httpExpanded  = false
    @State private var fileExpanded  = false

    var body: some View {
        let mode     = settings.integrationMode
        let showHTTP = mode == .http || mode == .both
        let showFile = mode == .file || mode == .both

        VStack(alignment: .leading, spacing: 8) {
            if showHTTP {
                statusRow(
                    running:   statusMonitor.httpServerRunning,
                    error:     statusMonitor.httpServerError,
                    okLabel:   String(format: settings.t("integration.server_running"), settings.httpPort),
                    idleLabel: settings.t("integration.server_starting"),
                    expanded:  $httpExpanded
                )
            }
            if showFile {
                statusRow(
                    running:   statusMonitor.fileWatcherRunning,
                    error:     statusMonitor.fileWatcherError,
                    okLabel:   settings.t("integration.file_watch_active"),
                    idleLabel: nil,
                    expanded:  $fileExpanded
                )
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusRow(running: Bool, error: ServiceDiagnostic?,
                           okLabel: String, idleLabel: String?,
                           expanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(running ? Color.green : (error != nil ? Color.red : Color.orange))
                    .frame(width: 8, height: 8)

                if running {
                    Text(okLabel)
                } else if let diag = error {
                    Text(diag.message)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let label = idleLabel {
                    Text(label).foregroundStyle(.secondary)
                }

                Spacer()

                if error != nil {
                    Button(expanded.wrappedValue
                           ? settings.t("integration.error_hide")
                           : settings.t("integration.error_details")) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expanded.wrappedValue.toggle()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }

            if let diag = error, expanded.wrappedValue {
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView {
                        Text(diag.fullDescription)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(height: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)

                    Button(settings.t("integration.copy_error")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(diag.fullDescription, forType: .string)
                    }
                    .font(.caption)
                }
                .transition(.opacity)
            }
        }
    }
}
