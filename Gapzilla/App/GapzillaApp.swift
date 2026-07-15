import SwiftUI
import UIKit

@main
struct GapzillaApp: App {
    @StateObject private var store = AppStore()

    init() {
        let ink = UIColor(red: 0.15, green: 0.14, blue: 0.25, alpha: 1)
        let secondary = UIColor(red: 0.40, green: 0.43, blue: 0.51, alpha: 1)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: ink]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: ink]
        UITabBar.appearance().unselectedItemTintColor = secondary
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.locale, Locale(identifier: store.language.rawValue))
                .tint(GapStyle.coral)
                .task { await store.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            switch store.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                WelcomeView()
            case .signedIn:
                if store.goals.isEmpty {
                    GoalSetupView()
                } else {
                    MainTabView()
                }
            }
        }
        .animation(.snappy, value: store.phase)
        .alert(
            store.text("出了点问题", "Something went wrong"),
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button(store.text("知道了", "OK"), role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            GlowBackground()
            VStack(spacing: 18) {
                LogoMark(size: 66)
                ProgressView()
                    .tint(GapStyle.coral)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: Int

    init() {
#if DEBUG
        let prefix = "--ui-preview-tab="
        let value = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })
            .flatMap { Int($0.dropFirst(prefix.count)) } ?? 0
        _selection = State(initialValue: value)
#else
        _selection = State(initialValue: 0)
#endif
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label(store.text("今天", "Today"), systemImage: "sun.max.fill") }
                .tag(0)
            HistoryView()
                .tabItem { Label(store.text("历史", "History"), systemImage: "calendar") }
                .tag(1)
            InsightsView()
                .tabItem { Label(store.text("分析", "Insights"), systemImage: "chart.xyaxis.line") }
                .tag(2)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
