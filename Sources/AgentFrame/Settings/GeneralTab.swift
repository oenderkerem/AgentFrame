import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var statusMonitor: StatusMonitor
    @State private var screens = NSScreen.screens

    var body: some View {
        Form {
            // Language
            Section {
                Picker(settings.t("general.language"), selection: $settings.languageCode) {
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                }
                .pickerStyle(.radioGroup)
            }

            // Notifications
            Section {
                Toggle(settings.t("general.sound_enabled"), isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    SoundPicker(label: settings.t("general.sound_busy"),
                                selection: $settings.busySoundName)
                    SoundPicker(label: settings.t("general.sound_waiting"),
                                selection: $settings.waitingSoundName)
                    SoundPicker(label: settings.t("general.sound_done"),
                                selection: $settings.doneSoundName)
                }
            }

            // System
            Section {
                Toggle(settings.t("general.launch_at_login"), isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { enabled in
                        if let delegate = NSApp.delegate as? AppDelegate {
                            delegate.applyLaunchAtLogin(enabled)
                        }
                    }
            }

            // Frame (with section header)
            Section {
                // Appearance
                
                HStack(spacing: 16) {
                    EdgeToggle(label: settings.t("display.edge_top"),    edge: .top,    settings: settings)
                    EdgeToggle(label: settings.t("display.edge_bottom"), edge: .bottom, settings: settings)
                    EdgeToggle(label: settings.t("display.edge_left"),   edge: .left,   settings: settings)
                    EdgeToggle(label: settings.t("display.edge_right"),  edge: .right,  settings: settings)
                }
                .padding(.vertical, 4)

                HStack {
                    Text(settings.t("display.thickness"))
                    Slider(value: $settings.frameThickness, in: 2...40, step: 1)
                    Text("\(Int(settings.frameThickness)) px")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                Toggle(settings.t("display.busy_enabled"), isOn: $settings.busyEnabled)
                
                if settings.busyEnabled {
                    ColorRow(colorHex: $settings.busyColorHex, opacity: $settings.busyOpacity,
                             label: settings.t("display.color_busy"),
                             opacityLabel: settings.t("display.opacity"))
                }

                ColorRow(colorHex: $settings.waitingColorHex, opacity: $settings.waitingOpacity,
                         label: settings.t("display.color_waiting"),
                         opacityLabel: settings.t("display.opacity"))

                ColorRow(colorHex: $settings.doneColorHex, opacity: $settings.doneOpacity,
                         label: settings.t("display.color_done"),
                         opacityLabel: settings.t("display.opacity"))

                // Auto-hide
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(settings.t("display.auto_hide"), isOn: $settings.autoResetAfterDone)
                        .disabled(settings.flashPersistent)
                    Text(settings.t("display.auto_hide_help"))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if settings.autoResetAfterDone && !settings.flashPersistent {
                    HStack {
                        Text(settings.t("display.auto_hide_delay"))
                        Slider(value: $settings.autoResetDelay, in: 0.5...30.0, step: 0.5)
                        Text(String(format: "%.1f s", settings.autoResetDelay))
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                
                Toggle(settings.t("display.flash_enable"), isOn: $settings.flashEnabled)

                if settings.flashEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(settings.t("display.flash_persistent"), isOn: $settings.flashPersistent)
                    }

                    if !settings.flashPersistent {
                        HStack {
                            Text(settings.t("display.flash_duration"))
                            Slider(value: $settings.flashDuration, in: 0.3...10.0, step: 0.1)
                            Text(String(format: "%.1f s", settings.flashDuration))
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }

                // Screen subsection
                SubsectionHeader(title: settings.t("display.screen"))
                
                Text(settings.t("display.screen_help"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Toggle(settings.t("display.follow_screen"), isOn: $settings.followActiveScreen)
                if settings.followActiveScreen {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(settings.t("display.live_tracking"), isOn: $settings.liveMouseTracking)
                        Text(settings.t("display.live_tracking_help"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !settings.followActiveScreen {
                    Picker(settings.t("display.select_screen"),
                           selection: $settings.selectedScreenIndex) {
                        Text(settings.t("display.main_screen")).tag(-1)
                        ForEach(screens.indices, id: \.self) { i in
                            Text(screenLabel(for: i)).tag(i)
                        }
                    }
                }

            } header: {
                Text(settings.t("display.frame_settings"))
            }

            // Preview
            Section(settings.t("general.preview")) {
                HStack(spacing: 12) {
                    Button(settings.t("menu.test_busy")) { statusMonitor.setStatus(.busy) }
                    Button(settings.t("menu.test_done")) { statusMonitor.setStatus(.done) }
                    Button(settings.t("menu.test_idle")) { statusMonitor.setStatus(.idle) }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            screens = NSScreen.screens
        }
    }

    private func screenLabel(for index: Int) -> String {
        let s = screens[index]
        let main = s == NSScreen.main ? " (\(settings.t("display.screen_main_suffix")))" : ""
        let r = s.frame
        return "\(settings.t("display.screen_prefix")) \(index + 1)\(main) — \(Int(r.width))×\(Int(r.height))"
    }
}

// MARK: - Sub-views

private struct SubsectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }
}

private struct SoundPicker: View {
    let label: String
    @Binding var selection: String

    var body: some View {
        HStack {
            Picker(label, selection: $selection) {
                ForEach(AppSettings.systemSounds, id: \.self) { Text($0).tag($0) }
            }
            Button("▶") {
                guard selection != "None", !selection.isEmpty else { return }
                NSSound(named: .init(selection))?.play()
            }
            .buttonStyle(.borderless)
            .help("Preview")
        }
    }
}

private struct EdgeToggle: View {
    let label: String
    let edge: FrameEdges
    @ObservedObject var settings: AppSettings

    var body: some View {
        Toggle(label, isOn: Binding(
            get: { settings.frameEdges.contains(edge) },
            set: { on in
                if on { settings.frameEdges.insert(edge) }
                else  { settings.frameEdges.remove(edge) }
            }
        ))
        .toggleStyle(.checkbox)
    }
}

private struct ColorRow: View {
    @Binding var colorHex: String
    @Binding var opacity:  Double
    let label:        String
    let opacityLabel: String

    private var color: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: colorHex) ?? .red) },
            set: { c in
                if let ns = NSColor(c).usingColorSpace(.deviceRGB) {
                    colorHex = ns.hexString
                }
            }
        )
    }

    var body: some View {
        HStack {
            ColorPicker(label, selection: color, supportsOpacity: false)
            Spacer()
            Text(opacityLabel)
            Slider(value: $opacity, in: 0.05...1.0, step: 0.05)
                .frame(width: 120)
            Text("\(Int(opacity * 100)) %")
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
