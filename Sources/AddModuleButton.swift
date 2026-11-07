import SwiftUI
import UniformTypeIdentifiers

/// The file chooser: pick one or more .js modules.
struct AddModuleButton: View {
    private let store = ModuleStore.shared
    @State private var picking = false
    @State private var message: String?

    var body: some View {
        Button {
            picking = true
        } label: {
            Label("Add Module", systemImage: "puzzlepiece.extension.fill")
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.javaScript, .plainText, .text], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    do { try store.add(from: url) } catch { message = "\(url.lastPathComponent): \(error.localizedDescription)" }
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .alert("Couldn't add module", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }
}
