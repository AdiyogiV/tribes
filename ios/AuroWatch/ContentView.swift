import SwiftUI

/// Root view — tab-based navigation.
/// Starts with 2 tabs (Cosmic Now + Nadi). More tabs are added in later phases.
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CosmicNowView()
                .tag(0)

            NadiMonitorView()
                .tag(1)

            // Phase 2: Daily Insight
            // InsightView()
            //     .tag(2)

            // Phase 2: Muhurat Timeline
            // MuhuratView()
            //     .tag(3)

            // Phase 3: Notifications
            // NotificationsView()
            //     .tag(4)
        }
        .tabViewStyle(.verticalPage) // watchOS 10+ vertical paging
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSyncManager())
        .environmentObject(HealthKitManager())
        .environmentObject(LocalCache())
}
