import SwiftUI

struct MultiAgentTab: View {
    @ObservedObject var settings: AppSettings
    @State private var screens = NSScreen.screens
    @State private var hookInstallResult: HookInstallResult? = nil

    var body: some View {
        Form {
            Section {
                Toggle(settings.t("multiagent.enable"), isOn: $settings.multiAgentEnabled)
                    .onChange(of: settings.multiAgentEnabled) { enabled in
                        if enabled {
                            hookInstallResult = nil
                            DispatchQueue.main.async { promptHookReinstall() }
                        } else {
                            hookInstallResult = nil
                        }
                    }

                Text(settings.t("multiagent.enable_help"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let result = hookInstallResult {
                    switch result {
                    case .success(let path):
                        Label(String(format: settings.t("integration.installed"), path),
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failure(let err):
                        Label(err, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }

            if settings.multiAgentEnabled {
                Section(settings.t("multiagent.section_menubar")) {
                    Toggle(settings.t("multiagent.menu_items"), isOn: $settings.multiAgentMenuItemsEnabled)

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(settings.t("multiagent.popup_enabled"), isOn: $settings.multiAgentPopupEnabled)
                        Text(settings.t("multiagent.popup_help"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if settings.multiAgentPopupEnabled {
                        HStack {
                            Text(settings.t("multiagent.popup_duration"))
                            Slider(value: $settings.multiAgentPopupDuration, in: 1...15, step: 0.5)
                            Text(String(format: "%.1f s", settings.multiAgentPopupDuration))
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }

                Section(settings.t("multiagent.section_window")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(settings.t("multiagent.window_enabled"), isOn: $settings.agentWindowEnabled)
                        Text(settings.t("multiagent.window_help"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if settings.agentWindowEnabled {
                        Toggle(settings.t("multiagent.window_permanent"), isOn: $settings.agentWindowPermanent)

                        Picker(settings.t("multiagent.window_corner"), selection: Binding(
                            get: { settings.agentWindowCorner },
                            set: { settings.agentWindowCorner = $0 }
                        )) {
                            ForEach(WindowCorner.allCases, id: \.rawValue) { c in
                                Text(c.label(settings)).tag(c)
                            }
                        }

                        Picker(settings.t("multiagent.window_screen"), selection: $settings.agentWindowScreenIndex) {
                            Text(settings.t("display.main_screen")).tag(-1)
                            ForEach(screens.indices, id: \.self) { i in
                                Text(screenLabel(for: i)).tag(i)
                            }
                        }

                        HStack {
                            ColorPicker(settings.t("multiagent.window_color"), selection: windowColor, supportsOpacity: false)
                        }

                        HStack {
                            Text(settings.t("display.opacity"))
                            Slider(value: $settings.agentWindowOpacity, in: 0.1...1.0, step: 0.05)
                            Text("\(Int(settings.agentWindowOpacity * 100)) %")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }

                        HStack {
                            Text(settings.t("multiagent.window_font_size"))
                            Slider(value: $settings.agentWindowFontSize, in: 10...20, step: 1)
                            Text("\(Int(settings.agentWindowFontSize)) pt")
                                .frame(width: 45, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }

                if settings.integrationMode == .file {
                    Section {
                        Label(settings.t("multiagent.file_mode_hint"), systemImage: "folder")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(settings.multiAgentDirPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in screens = NSScreen.screens }
    }

    // MARK: - Hook reinstall prompt

    private func promptHookReinstall() {
        let supportsAutoInstall = settings.agentProvider == .claudeCode || settings.agentProvider == .codex

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = settings.t("multiagent.hook_prompt_title")
        alert.informativeText = supportsAutoInstall
            ? settings.t("multiagent.hook_prompt_msg")
            : settings.t("multiagent.hook_prompt_msg_custom")

        if supportsAutoInstall {
            alert.addButton(withTitle: settings.t("multiagent.hook_prompt_install"))
            alert.addButton(withTitle: settings.t("multiagent.hook_prompt_later"))
        } else {
            alert.addButton(withTitle: settings.t("multiagent.hook_prompt_ok"))
        }

        guard supportsAutoInstall, alert.runModal() == .alertFirstButtonReturn else { return }

        hookInstallResult = settings.installHooks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            hookInstallResult = nil
        }
    }

    // MARK: - Helpers

    private var windowColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: settings.agentWindowNSColor) },
            set: { c in
                if let ns = NSColor(c).usingColorSpace(.deviceRGB) {
                    settings.agentWindowColorHex = ns.hexString
                }
            }
        )
    }

    private func screenLabel(for index: Int) -> String {
        let s = screens[index]
        let main = s == NSScreen.main ? " (\(settings.t("display.screen_main_suffix")))" : ""
        let r = s.frame
        return "\(settings.t("display.screen_prefix")) \(index + 1)\(main) — \(Int(r.width))×\(Int(r.height))"
    }
}
