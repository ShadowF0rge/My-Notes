
import Foundation
import AppKit

enum NoteStorageError: LocalizedError {
    case unsupportedFile
    case outsideNotesDirectory
    case fileAlreadyExists

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Dieser Dateityp wird nicht unterstützt."

        case .outsideNotesDirectory:
            return "Die Datei liegt außerhalb des internen Notizordners."

        case .fileAlreadyExists:
            return "Eine Datei mit diesem Namen existiert bereits."
        }
    }
}

final class NoteStorage {
    static let shared = NoteStorage()

    private let fileManager = FileManager.default

    let supportedExtensions: Set<String> = [
        "txt",
        "py",
        "java",
        "js",
        "html",
        "css",
        "json",
        "md"
    ]

    private init() {
        prepareDirectory()
    }

    var notesDirectory: URL {
        fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent(
            "MyNotes",
            isDirectory: true
        )
    }

    private func prepareDirectory() {
        do {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog(
                "My Notes: Notizordner konnte nicht erstellt werden: %@",
                error.localizedDescription
            )
        }
    }

    // MARK: - Validation

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

    private func validateNoteURL(_ url: URL) throws {
        guard isInternalURL(url) else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard isSupportedFile(url) else {
            throw NoteStorageError.unsupportedFile
        }
    }

    // MARK: - Create

    func createNote(
        title: String,
        fileType: String
    ) throws -> URL {
        let normalizedExtension = fileType.lowercased()

        guard supportedExtensions.contains(normalizedExtension) else {
            throw NoteStorageError.unsupportedFile
        }

        let safeTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let finalTitle = safeTitle.isEmpty
            ? "Unbenannte Notiz"
            : safeTitle

        let destinationURL = notesDirectory
            .appendingPathComponent(finalTitle)
            .appendingPathExtension(normalizedExtension)

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try Data().write(
            to: destinationURL,
            options: .atomic
        )

        return destinationURL
    }

    // MARK: - Save

    func save(
        text: String,
        to url: URL
    ) throws {
        try validateNoteURL(url)

        try Data(text.utf8).write(
            to: url,
            options: .atomic
        )
    }

    // MARK: - Load

    func load(from url: URL) throws -> String {
        try validateNoteURL(url)

        return try String(
            contentsOf: url,
            encoding: .utf8
        )
    }

    // MARK: - Rename

    func renameNote(
        at url: URL,
        to newTitle: String
    ) throws -> URL {
        try validateNoteURL(url)

        let safeTitle = newTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !safeTitle.isEmpty else {
            return url
        }

        let destinationURL = notesDirectory
            .appendingPathComponent(safeTitle)
            .appendingPathExtension(url.pathExtension)

        if url.standardizedFileURL == destinationURL.standardizedFileURL {
            return url
        }

        guard !fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try fileManager.moveItem(
            at: url,
            to: destinationURL
        )

        return destinationURL
    }

    // MARK: - Trash

    func trashNote(at url: URL) throws {
        try validateNoteURL(url)

        guard fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.trashItem(
            at: url,
            resultingItemURL: nil
        )
    }

    // MARK: - List notes

    func listNotes() -> [URL] {
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: notesDirectory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            )

            return urls
                .filter { isSupportedFile($0) }
                .filter { url in
                    (try? url.resourceValues(
                        forKeys: [.isRegularFileKey]
                    ).isRegularFile) == true
                }
                .sorted {
                    let firstDate = (
                        try? $0.resourceValues(
                            forKeys: [.contentModificationDateKey]
                        ).contentModificationDate
                    ) ?? .distantPast

                    let secondDate = (
                        try? $1.resourceValues(
                            forKeys: [.contentModificationDateKey]
                        ).contentModificationDate
                    ) ?? .distantPast

                    return firstDate > secondDate
                }
        } catch {
            NSLog(
                "My Notes: Notizen konnten nicht geladen werden: %@",
                error.localizedDescription
            )

            return []
        }
    }

    // MARK: - Search

    func searchNotes(query: String) -> [URL] {
        let allNotes = listNotes()

        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedQuery.isEmpty else {
            return allNotes
        }

        return allNotes.filter { url in
            url.deletingPathExtension()
                .lastPathComponent
                .localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}
