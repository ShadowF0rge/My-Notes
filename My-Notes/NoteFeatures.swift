
import Foundation

struct NoteTag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
}

enum NoteFeatures {
    private static let legacyTagsKey = "MyNotes.noteTags"

    // MARK: - Tags

    static func tags(for url: URL) -> [String] {
        let storage = NoteStorage.shared
        let existingTags = storage.tags(for: url)

        if !existingTags.isEmpty {
            return existingTags
        }

        // Alte Tags aus UserDefaults übernehmen, falls vorhanden.
        let legacyTags = UserDefaults.standard.dictionary(
            forKey: legacyTagsKey
        ) as? [String: [String]] ?? [:]

        let filename = url.lastPathComponent

        guard let oldTags = legacyTags[filename],
              !oldTags.isEmpty else {
            return []
        }

        // Tags in den neuen Speicher übernehmen.
        storage.setTags(oldTags, for: url)

        return storage.tags(for: url)
    }

    static func setTags(
        _ tags: [String],
        for url: URL
    ) {
        NoteStorage.shared.setTags(tags, for: url)
    }

    static func removeTags(for url: URL) {
        NoteStorage.shared.setTags([], for: url)
    }

    // MARK: - Dates

    static func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Noch nie geöffnet"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .short

        return formatter.localizedString(
            for: date,
            relativeTo: Date()
        )
    }

    static func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(
            forKeys: [.contentModificationDateKey]
        ).contentModificationDate
    }

    static func fileTypeName(for url: URL) -> String {
        url.pathExtension.uppercased()
    }

    // MARK: - Text Statistics

    static func wordCount(in text: String) -> Int {
        text.split {
            $0.isWhitespace || $0.isNewline
        }.count
    }

    static func characterCount(in text: String) -> Int {
        text.count
    }

    static func readingTime(in text: String) -> String {
        let words = wordCount(in: text)
        let minutes = max(
            1,
            Int(ceil(Double(words) / 200.0))
        )

        return "\(minutes) Min. Lesezeit"
    }
}
