import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            AgentListView()
                .tabItem {
                    Label("Agents", systemImage: "person.3")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
        }
    }
}
