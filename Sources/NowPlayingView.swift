import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    private let player = Player.shared

    @State private var scrubbing = false
    @State private var scrubValue = 0.0

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(.white.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .onTapGesture { dismiss() }

            Spacer(minLength: 0)

            Artwork(url: player.current?.artwork, radius: 24)
                .id(player.current?.id)
                .transition(.opacity)
                .scaleEffect(player.isPlaying ? 1 : 0.84)
                .shadow(color: .black.opacity(player.isPlaying ? 0.45 : 0.15), radius: player.isPlaying ? 32 : 10, y: 18)
                .animation(.spring(response: 0.55, dampingFraction: 0.65), value: player.isPlaying)
                .padding(.horizontal, 28)

            titleBlock
            scrubber
            transport

            if let error = player.error {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .foregroundStyle(.white)
        .background { backdrop.ignoresSafeArea() }
        .animation(.easeInOut(duration: 0.5), value: player.current?.id)
        .preferredColorScheme(.dark)
    }

    private var backdrop: some View {
        Color.black
            .overlay {
                if let s = player.current?.artwork, let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().transition(.opacity)
                        }
                    }
                    .blur(radius: 70)
                    .saturation(1.5)
                    .opacity(0.75)
                }
            }
            .overlay { Color.black.opacity(0.3) }
            .clipped()
    }

    private var titleBlock: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.current?.title ?? "Not Playing")
                    .font(.title2.bold())
                    .lineLimit(1)
                Text(player.current?.artist ?? "")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            if let song = player.current {
                DownloadButton(song: song)
                    .font(.title2)
                    .padding(10)
                    .glassBackground(in: Circle(), interactive: true)
            }
        }
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { scrubbing ? scrubValue : player.progress }, set: { scrubValue = $0 }),
                in: 0...max(player.duration, 1)
            ) { editing in
                if editing { scrubValue = player.progress }
                scrubbing = editing
                if !editing { player.seek(to: scrubValue) }
            }
            .tint(.white)
            HStack {
                Text(format(scrubbing ? scrubValue : player.progress))
                Spacer()
                Text("-" + format(max(player.duration - (scrubbing ? scrubValue : player.progress), 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            control("backward.fill", size: 64) { player.previous() }
            control(player.isPlaying ? "pause.fill" : "play.fill", size: 84) { player.toggle() }
            control("forward.fill", size: 64) { player.next() }
        }
        .padding(.top, 8)
    }

    private func control(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: size * 0.36))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .glassBackground(in: Circle(), interactive: true)
    }

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
