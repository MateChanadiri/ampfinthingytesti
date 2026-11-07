import SwiftUI

struct SearchView: View {
    private let store = ModuleStore.shared
    private let player = Player.shared
    private let downloads = Downloads.shared

    @State private var query = ""
    @State private var results: [Song] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(results.enumerated()), id: \.offset) { _, song in
                    SongRow(song: song) { player.play(song, in: results) }
                }
            }
            .listStyle(.plain)
            .overlay { placeholder }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Artists, Songs, and More")
            .task(id: query) { await search() }
            .animation(.smooth, value: results.count)
            .modifier(MiniPlayerInset())
            .alert("Download failed", isPresented: Binding(get: { downloads.lastError != nil }, set: { if !$0 { downloads.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloads.lastError ?? "")
            }
        }
    }

    @ViewBuilder private var placeholder: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text(store.modules.isEmpty ? "Add a module in Library first." : "Search across your modules."))
        } else if searching && results.isEmpty {
            ProgressView()
        } else if results.isEmpty {
            ContentUnavailableView.search(text: q)
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; searching = false; return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        searching = true
        let found = await store.search(q)
        guard !Task.isCancelled else { return }
        results = found
        searching = false
    }
}
