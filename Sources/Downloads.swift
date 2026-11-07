import Foundation
import Observation

/// Downloaded songs live in Documents/Music (visible in the Files app).
@MainActor @Observable
final class Downloads {
    static let shared = Downloads()

    struct Entry: Codable { var song: Song; var file: String }

    private(set) var entries: [Entry] = []
    private(set) var active: Set<String> = []
    var lastError: String?
    private let dir: URL

    var songs: [Song] { entries.map(\.song) }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: dir.appendingPathComponent("library.json")),
           let saved = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
    }

    func isDownloaded(_ song: Song) -> Bool {
        entries.contains { $0.song.id == song.id }
    }

    func localURL(for song: Song) -> URL? {
        guard let e = entries.first(where: { $0.song.id == song.id }) else { return nil }
        let url = dir.appendingPathComponent(e.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ song: Song) async {
        guard !active.contains(song.id), !isDownloaded(song) else { return }
        active.insert(song.id)
        defer { active.remove(song.id) }
        do {
            let remote = try await ModuleStore.shared.resolve(song, download: true)
            let (tmp, resp) = try await URLSession.shared.download(from: remote)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw AppError(message: "Download failed (HTTP \(http.statusCode))")
            }
            let name = UUID().uuidString + "." + Self.fileExtension(remote, resp)
            try FileManager.default.moveItem(at: tmp, to: dir.appendingPathComponent(name))
            entries.append(Entry(song: song, file: name))
            save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func remove(_ song: Song) {
        if let url = localURL(for: song) { try? FileManager.default.removeItem(at: url) }
        entries.removeAll { $0.song.id == song.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: dir.appendingPathComponent("library.json"), options: .atomic)
        }
    }

    nonisolated private static func fileExtension(_ url: URL, _ resp: URLResponse) -> String {
        let known = ["mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "mp4"]
        let e = url.pathExtension.lowercased()
        if known.contains(e) { return e }
        switch resp.mimeType ?? "" {
        case "audio/mp4", "audio/x-m4a", "audio/aac": return "m4a"
        case "audio/flac", "audio/x-flac": return "flac"
        case "audio/wav", "audio/x-wav": return "wav"
        default: return "mp3"
        }
    }
}
