import SwiftUI

enum AppTab: Hashable { case home, new, radio, library, search }

struct RootView: View {
    @State private var tab: AppTab = .home
    @Namespace private var namespace
    @Bindable private var player = Player.shared

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                FeedView(title: "Home", feed: .home)
            }
            Tab("New", systemImage: "square.grid.2x2.fill", value: AppTab.new) {
                FeedView(title: "New", feed: .new)
            }
            Tab("Radio", systemImage: "dot.radiowaves.left.and.right", value: AppTab.radio) {
                FeedView(title: "Radio", feed: .radio)
            }
            Tab("Library", systemImage: "play.square.stack.fill", value: AppTab.library) {
                LibraryView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
    }

    @ViewBuilder private var withMiniPlayer: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    MiniPlayer()
                        .matchedTransitionSource(id: "player", in: namespace)
                        .contentShape(Rectangle())
                        .onTapGesture { player.showFullPlayer = true }
                }
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    var body: some View {
        withMiniPlayer
            .fullScreenCover(isPresented: $player.showFullPlayer) {
                NowPlayingView()
                    .navigationTransition(.zoom(sourceID: "player", in: namespace))
            }
    }
}

/// Before iOS 26 there is no tab-bar accessory, so each tab pins the mini player itself.
struct MiniPlayerInset: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) { LegacyMiniPlayer() }
        }
        #else
        content.safeAreaInset(edge: .bottom, spacing: 0) { LegacyMiniPlayer() }
        #endif
    }
}

private struct LegacyMiniPlayer: View {
    var body: some View {
        MiniPlayer()
            .padding(.horizontal, 14)
            .frame(height: 56)
            .glassBackground(in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { Player.shared.showFullPlayer = true }
    }
}
