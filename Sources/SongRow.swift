import SwiftUI

struct SongRow: View {
    let song: Song
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    Artwork(url: song.artwork, radius: 8)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).lineLimit(1)
                        if !song.subtitle.isEmpty {
                            Text(song.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            DownloadButton(song: song)
        }
    }
}

struct DownloadButton: View {
    let song: Song
    private let downloads = Downloads.shared

    var body: some View {
        if downloads.isDownloaded(song) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else if downloads.active.contains(song.id) {
            ProgressView()
        } else {
            Button {
                Task { await downloads.download(song) }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }
}
