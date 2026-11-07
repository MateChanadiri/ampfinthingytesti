import SwiftUI

struct MiniPlayer: View {
    private let player = Player.shared

    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: player.current?.artwork, radius: 8)
                .frame(width: 38, height: 38)
            Text(player.current?.title ?? "Not Playing")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(player.current == nil ? .secondary : .primary)
            Spacer(minLength: 0)
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.title3)
                    .frame(width: 34, height: 34)
            }
            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .frame(width: 34, height: 34)
            }
        }
        .buttonStyle(.plain)
        .disabled(player.current == nil)
        .padding(.horizontal, 8)
        .animation(.smooth, value: player.current?.id)
    }
}
