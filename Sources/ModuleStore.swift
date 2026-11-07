import Foundation
import Observation

@MainActor @Observable
final class ModuleStore {
    static let shared = ModuleStore()

    enum Feed: String { case home, new, radio }

    private(set) var modules: [JSModule] = []
    private(set) var loadErrors: [String] = []
    private(set) var runErrors: [String: String] = [:]
    private let dir: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Modules", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        reload()
    }

    private func reload() {
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "js" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var loaded: [JSModule] = []
        var errors: [String] = []
        for file in files {
            do {
                let source = try String(contentsOf: file, encoding: .utf8)
                loaded.append(try JSModule(id: file.lastPathComponent, source: source))
            } catch {
                errors.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        modules = loaded
        loadErrors = errors
    }

    /// Copies a user-picked .js file into the app and starts it.
    func add(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let source = try String(contentsOf: url, encoding: .utf8)
        let fileName = url.deletingPathExtension().lastPathComponent + ".js"
        _ = try JSModule(id: fileName, source: source) // validates before saving
        try source.write(to: dir.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        reload()
    }

    func remove(_ module: JSModule) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(module.id))
        reload()
    }

    // MARK: Calling modules

    func shelves(_ feed: Feed) async -> [Shelf] {
        await gather(feed.rawValue, nil)
    }

    func search(_ query: String) async -> [Song] {
        await gather("search", query).flatMap(\.songs)
    }

    private func gather(_ fn: String, _ arg: Any?) async -> [Shelf] {
        let mods = modules
        let results = await withTaskGroup(of: (Int, [Shelf]).self) { group -> [(Int, [Shelf])] in
            for (i, m) in mods.enumerated() {
                group.addTask {
                    do {
                        let raw = try await m.call(fn, arg)
                        await self.setError(nil, for: m.id)
                        return (i, Self.parse(raw, module: m))
                    } catch {
                        await self.setError(error.localizedDescription, for: m.id)
                        return (i, [])
                    }
                }
            }
            var out: [(Int, [Shelf])] = []
            for await r in group { out.append(r) }
            return out
        }
        return results.sorted { $0.0 < $1.0 }.flatMap(\.1)
    }

    private func setError(_ message: String?, for id: String) {
        runErrors[id] = message
    }

    /// Accepts [{title, items:[song]}] (shelves) or [song] (one shelf named after the module).
    nonisolated private static func parse(_ raw: Any?, module m: JSModule) -> [Shelf] {
        guard let array = raw as? [[String: Any]] else { return [] }
        if array.contains(where: { $0["items"] != nil || $0["songs"] != nil }) {
            return array.compactMap { s in
                let items = (s["items"] ?? s["songs"]) as? [[String: Any]] ?? []
                let songs = items.compactMap { Song(json: $0, moduleID: m.id) }
                return songs.isEmpty ? nil : Shelf(title: (s["title"] as? String) ?? m.name, songs: songs)
            }
        }
        let songs = array.compactMap { Song(json: $0, moduleID: m.id) }
        return songs.isEmpty ? [] : [Shelf(title: m.name, songs: songs)]
    }

    /// Finds an audio URL. shortcut: custom HTTP headers from modules are not supported.
    func resolve(_ song: Song, download: Bool) async throws -> URL {
        if let m = modules.first(where: { $0.id == song.moduleID }) {
            let rawObject = song.raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }
            for fn in download ? ["download", "resolve"] : ["resolve"] {
                guard let r = try await m.call(fn, rawObject) else { continue }
                if let s = r as? String, let u = URL(string: s) { return u }
                if let d = r as? [String: Any], let s = d["url"] as? String, let u = URL(string: s) { return u }
            }
        }
        if let s = song.url, let u = URL(string: s) { return u }
        throw AppError(message: "No audio URL from module \"\(song.moduleID)\"")
    }
}
