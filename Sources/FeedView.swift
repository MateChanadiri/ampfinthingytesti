import SwiftUI

/// Home, New and Radio: shelves of songs supplied by modules.
struct FeedView: View {
    let title: String
    let feed: ModuleStore.Feed

    private let store = ModuleStore.shared
    @State private var shelves: [Shelf] = []
    @State private var loading = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(shelves) { ShelfRow(shelf: $0) }
                }
                .padding(.vertical)
            }
            .overlay { placeholder }
            .navigationTitle(title)
            .refreshable { await load() }
            .task(id: store.modules.map(\.id)) { await load() }
            .animation(.smooth, value: shelves.count)
            .modifier(MiniPlayerInset())
        }
    }

    @ViewBuilder private var placeholder: some View {
        if store.modules.isEmpty {
            ContentUnavailableView {
                Label("No Modules", systemImage: "puzzlepiece.extension")
            } description: {
                Text("Add a .js module to bring in music.")
            } actions: {
                AddModuleButton().buttonStyle(.borderedProminent)
            }
        } else if loading && shelves.isEmpty {
            ProgressView()
        } else if loaded && shelves.isEmpty {
            ContentUnavailableView("Nothing Here", systemImage: "music.note", description: Text("Your modules returned nothing for \(title). Check Library for module errors."))
        }
    }

    private func load() async {
        guard !store.modules.isEmpty else { shelves = []; return }
        loading = true
        let result = await store.shelves(feed)
        guard !Task.isCancelled else { return }
        shelves = result
        loading = false
        loaded = true
    }
}

struct ShelfRow: View {
    let shelf: Shelf
    private let player = Player.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(shelf.title)
                .font(.title2.bold())
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(shelf.songs.enumerated()), id: \.offset) { _, song in
                        Button { player.play(song, in: shelf.songs) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Artwork(url: song.artwork, radius: 14)
                                    .frame(width: 156, height: 156)
                                    .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                                Text(song.title).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(song.artist).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(width: 156, alignment: .leading)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}
