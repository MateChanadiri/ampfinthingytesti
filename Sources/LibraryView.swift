import SwiftUI

struct LibraryView: View {
    private let store = ModuleStore.shared
    private let downloads = Downloads.shared
    private let player = Player.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Modules") {
                    ForEach(store.modules) { module in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(module.name)
                            Text(store.runErrors[module.id] ?? module.id)
                                .font(.caption)
                                .foregroundStyle(store.runErrors[module.id] == nil ? Color.secondary : Color.red)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { store.modules[$0] }.forEach(store.remove)
                    }
                    ForEach(store.loadErrors, id: \.self) { error in
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    AddModuleButton()
                }

                Section("Downloaded") {
                    if downloads.songs.isEmpty {
                        Text("Download songs from Search and they show up here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(downloads.songs.enumerated()), id: \.offset) { _, song in
                        SongRow(song: song) { player.play(song, in: downloads.songs) }
                    }
                    .onDelete { offsets in
                        offsets.map { downloads.songs[$0] }.forEach(downloads.remove)
                    }
                }
            }
            .navigationTitle("Library")
            .modifier(MiniPlayerInset())
            .alert("Download failed", isPresented: Binding(get: { downloads.lastError != nil }, set: { if !$0 { downloads.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloads.lastError ?? "")
            }
        }
    }
}
