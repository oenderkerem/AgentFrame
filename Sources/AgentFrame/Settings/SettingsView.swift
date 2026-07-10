import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings:      AppSettings
    @ObservedObject var statusMonitor: StatusMonitor

    var body: some View {
        TabView {
            GeneralTab(settings: settings, statusMonitor: statusMonitor)
                .tabItem { Label(settings.t("settings.tab_general"), systemImage: "gear") }

            IntegrationTab(settings: settings, statusMonitor: statusMonitor)
                .tabItem { Label("Integration", systemImage: "plug") }
        }
        .padding(12)
        .frame(minWidth: 520, minHeight: 560)
    }
}
