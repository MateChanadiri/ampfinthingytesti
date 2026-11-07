import Foundation

struct AppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// One track. Built from the plain objects a module returns.
struct Song: Identifiable, Codable, Hashable {
    var id: String          // "<module file>:<module's id>"
    var moduleID: String
    var title: String
    var artist: String
    var album: String
    var artwork: String?
    var url: String?        // direct audio URL, optional if the module has resolve()
    var duration: Double?
    var raw: String         // original JSON, handed back to the module's resolve()/download()

    init?(json: [String: Any], moduleID: String) {
        guard let title = Song.string(json["title"]) ?? Song.string(json["name"]) else { return nil }
        let rawID = Song.string(json["id"]) ?? Song.string(json["url"]) ?? title
        self.id = moduleID + ":" + rawID
        self.moduleID = moduleID
        self.title = title
        self.artist = Song.string(json["artist"]) ?? ""
        self.album = Song.string(json["album"]) ?? ""
        self.artwork = Song.string(json["artwork"]) ?? Song.string(json["cover"])
        self.url = Song.string(json["url"])
        self.duration = (json["duration"] as? NSNumber)?.doubleValue
        self.raw = (try? JSONSerialization.data(withJSONObject: json))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func string(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    var subtitle: String {
        [artist, album].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct Shelf: Identifiable {
    let id = UUID()
    var title: String
    var songs: [Song]
}
