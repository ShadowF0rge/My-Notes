
import Foundation

enum NoteStorageError: LocalizedError {
    case unsupportedFile
    case outsideNotesDirectory

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Dieser Dateityp wird nicht unterstützt."
        case .outsideNotesDirectory:
            return "Die Datei liegt außerhalb des internen Notizordners."
        }
    }
}

final class NoteStorage {
    static let shared = NoteStorage()

    private let fileManager = FileManager.default

    let supportedExtensions: Set<String> = [
        "txt", "py", "java", "js", "html", "css", "json", "md"
    ]

    private init() {
        prepareDirectory()
    }

    var notesDirectory: URL {
        fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("MyNotes", isDirectory: true)
    }

    private func prepareDirectory() {
        do {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog(
                "MyNotes: Notizordner konnte nicht erstellt werden: %@",
                error.localizedDescription
            )
        }
    }
    func renameNote(at url: URL, to newTitle: String) throws -> URL {
        let safeTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeTitle.isEmpty else {
            return url
        }

        let newURL = url
            .deletingLastPathComponent()
            .appendingPathComponent(safeTitle)
            .appendingPathExtension(url.pathExtension)

        guard newURL != url else {
            return url
        }

        guard !FileManager.default.fileExists(atPath: newURL.path) else {
            throw NSError(
                domain: "NoteStorage",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Eine Notiz mit diesem Titel existiert bereits."
                ]
            )
        }

        try FileManager.default.moveItem(at: url, to: newURL)
        return newURL
    }

    private func isInternalURL(_ url: URL) -> Bool {
        let directory = notesDirectory.standardizedFileURL
        let file = url.standardizedFileURL

        return file.deletingLastPathComponent().path == directory.path
    }

    func isSupportedFile(_ url: URL) -> Bool {
        supportedExtensions.contains(
            url.pathExtension.lowercased()
        )
    }

    // MARK: - Create

    func createNote(title: String, fileType: String) throws -> URL {
        let ext = fileType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")

        guard supportedExtensions.contains(ext) else {
            throw NoteStorageError.unsupportedFile
        }

        try fileManager.createDirectory(
            at: notesDirectory,
            withIntermediateDirectories: true
        )

        let invalidCharacters = CharacterSet(
            charactersIn: "/:\\?%*|\"<>"
        )

        let cleanedTitle = title
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let baseName = cleanedTitle.isEmpty
            ? "Neue Notiz"
            : cleanedTitle

        var candidate = notesDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension(ext)

        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = notesDirectory
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension(ext)

            suffix += 1
        }

        guard fileManager.createFile(
            atPath: candidate.path,
            contents: Data()
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return candidate
    }

    // MARK: - Save

    func save(text: String, to url: URL) throws {
        guard isInternalURL(url) else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard isSupportedFile(url) else {
            throw NoteStorageError.unsupportedFile
        }

        try fileManager.createDirectory(
            at: notesDirectory,
            withIntermediateDirectories: true
        )

        try Data(text.utf8).write(
            to: url,
            options: .atomic
        )
    }

    // MARK: - Load

    func load(from url: URL) throws -> String {
        guard isInternalURL(url) else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard isSupportedFile(url) else {
            throw NoteStorageError.unsupportedFile
        }

        return try String(
            contentsOf: url,
            encoding: .utf8
        )
    }

    // MARK: - List notes

    func listNotes() -> [URL] {
        do {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )

            let urls = try fileManager.contentsOfDirectory(
                at: notesDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            return urls
                .filter { url in
                    guard isSupportedFile(url),
                          let values = try? url.resourceValues(
                              forKeys: [.isRegularFileKey]
                          ) else {
                        return false
                    }

                    return values.isRegularFile == true
                }
                .sorted {
                    $0.lastPathComponent.localizedCaseInsensitiveCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }
        } catch {
            NSLog(
                "MyNotes: Notizen konnten nicht geladen werden: %@",
                error.localizedDescription
            )

            return []
        }
    }

    // MARK: - Search

    func searchNotes(query: String) -> [URL] {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let notes = listNotes()

        guard !trimmedQuery.isEmpty else {
            return notes
        }

        return notes.filter {
            $0.deletingPathExtension()
                .lastPathComponent
                .localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}
