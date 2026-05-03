import SwiftUI

/// Root view — full-screen vertical pager. Swipe up/down to switch pages.
/// No navigation bar, no scroll within pages.
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CosmicNowView()
                .tag(0)

            VedicTimeTextView()
                .tag(1)

            SkyView()
                .tag(2)

            NadiMonitorView()
                .tag(3)

            InsightView()
                .tag(4)

            MuhuratView()
                .tag(5)

            OjasView()
                .tag(6)

            AyurvedaHubView()
                .tag(7)
        }
        .tabViewStyle(.verticalPage)
        .ignoresSafeArea(.all)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSyncManager())
        .environmentObject(HealthKitManager())
        .environmentObject(LocalCache())
}
