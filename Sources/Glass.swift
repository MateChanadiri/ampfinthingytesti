import SwiftUI

// iOS 26 Liquid Glass when available, frosted material before that.
// `compiler(>=6.2)` keeps the file building on older Xcode too.
extension View {
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Square cover art with a placeholder and a fade-in.
struct Artwork: View {
    let url: String?
    var radius: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Image(systemName: "music.note").font(.title).foregroundStyle(.secondary) }
            .overlay {
                if let url, let u = URL(string: url) {
                    AsyncImage(url: u, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().transition(.opacity)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
