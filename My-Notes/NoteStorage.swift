
import Foundation
import AppKit

enum NoteStorageError: LocalizedError {
    case unsupportedFile
    case outsideNotesDirectory
    case fileAlreadyExists
    case invalidTitle
    case invalidFolderName

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Dieser Dateityp wird nicht unterstützt."
        case .outsideNotesDirectory:
            return "Die Datei liegt außerhalb des internen Notizordners."
        case .fileAlreadyExists:
            return "Eine Datei mit diesem Namen existiert bereits."
        case .invalidTitle:
            return "Der Notiztitel ist ungültig."
        case .invalidFolderName:
            return "Der Ordnername ist ungültig."
        }
    }
}

final class NoteStorage {
    static let shared = NoteStorage()

    private let fileManager = FileManager.default

    let supportedExtensions: Set<String> = [
        "txt", "py", "java", "js", "html", "css", "json", "md"
    ]

    private struct NoteMetadata: Codable {
        var isPinned: Bool = false
        var lastOpened: Date?
        var tags: [String] = []

        private enum CodingKeys: String, CodingKey {
            case isPinned
            case lastOpened
            case tags
        }

        init(
            isPinned: Bool = false,
            lastOpened: Date? = nil,
            tags: [String] = []
        ) {
            self.isPinned = isPinned
            self.lastOpened = lastOpened
            self.tags = tags
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            isPinned = try container.decodeIfPresent(
                Bool.self,
                forKey: .isPinned
            ) ?? false

            lastOpened = try container.decodeIfPresent(
                Date.self,
                forKey: .lastOpened
            )

            tags = try container.decodeIfPresent(
                [String].self,
                forKey: .tags
            ) ?? []
        }
    }

    private struct MetadataStore: Codable {
        var notes: [String: NoteMetadata] = [:]
    }

    private var metadata = MetadataStore()

    private init() {
        prepareDirectory()
        loadMetadata()
        migrateLegacyMetadataKeys()
    }

    // MARK: - Directories

    var notesDirectory: URL {
        fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(
            "MyNotes",
            isDirectory: true
        )
    }

    private var trashDirectory: URL {
        notesDirectory.appendingPathComponent(
            ".Trash",
            isDirectory: true
        )
    }

    private var metadataURL: URL {
        notesDirectory.appendingPathComponent(".note-metadata.json")
    }

    private func prepareDirectory() {
        do {
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )

            try fileManager.createDirectory(
                at: trashDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog("My Notes: %@", error.localizedDescription)
        }
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    private func isInsideNotesDirectory(_ url: URL) -> Bool {
        let root = normalizedPath(notesDirectory)
        let path = normalizedPath(url)

        return path.hasPrefix(root + "/")
    }

    /// Akzeptiert den Hauptordner selbst sowie seine Unterordner.
    /// Symlinks nach außerhalb des Notizverzeichnisses werden abgewiesen.
    private func isNotesDirectoryOrInside(_ url: URL) -> Bool {
        let root = normalizedPath(notesDirectory)
        let path = normalizedPath(url)

        return path == root || path.hasPrefix(root + "/")
    }

    private func isTrashURL(_ url: URL) -> Bool {
        let trash = normalizedPath(trashDirectory)
        let path = normalizedPath(url)

        return path == trash || path.hasPrefix(trash + "/")
    }

    private func validateNotesDirectory(_ url: URL) throws {
        guard isNotesDirectoryOrInside(url),
              !isTrashURL(url),
              (try? url.resourceValues(
                  forKeys: [.isDirectoryKey]
              ).isDirectory) == true else {
            throw NoteStorageError.outsideNotesDirectory
        }
    }

    private func validateNoteURL(_ url: URL) throws {
        guard isInsideNotesDirectory(url),
              !isTrashURL(url) else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard isSupportedFile(url) else {
            throw NoteStorageError.unsupportedFile
        }

        guard (try? url.resourceValues(
            forKeys: [.isRegularFileKey]
        ).isRegularFile) == true else {
            throw NoteStorageError.unsupportedFile
        }
    }

    private func validateTrashURL(_ url: URL) throws {
        guard isTrashURL(url) else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard isSupportedFile(url),
              (try? url.resourceValues(
                  forKeys: [.isRegularFileKey]
              ).isRegularFile) == true else {
            throw NoteStorageError.unsupportedFile
        }
    }

    private func sanitizedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != ".." else {
            throw NoteStorageError.invalidTitle
        }

        return trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    // MARK: - Metadata

    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            metadata = MetadataStore()
            return
        }

        do {
            let data = try Data(contentsOf: metadataURL)

            metadata = try JSONDecoder().decode(
                MetadataStore.self,
                from: data
            )
        } catch {
            NSLog(
                "My Notes: Metadaten konnten nicht geladen werden: %@",
                error.localizedDescription
            )

            metadata = MetadataStore()
        }
    }

    private func saveMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            try encoder.encode(metadata).write(
                to: metadataURL,
                options: .atomic
            )
        } catch {
            NSLog(
                "My Notes: Metadaten konnten nicht gespeichert werden: %@",
                error.localizedDescription
            )
        }
    }

    private func metadataKey(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func updateMetadata(
        for url: URL,
        _ update: (inout NoteMetadata) -> Void
    ) {
        let key = metadataKey(for: url)
        var value = metadata.notes[key] ?? NoteMetadata()

        update(&value)

        metadata.notes[key] = value
        saveMetadata()
    }

    private func migrateLegacyMetadataKeys() {
        var changed = false
        let existingNotes = listNotes()

        for url in existingNotes {
            let key = metadataKey(for: url)

            guard metadata.notes[key] == nil else {
                continue
            }

            let legacyKey = url.lastPathComponent

            guard let legacyValue = metadata.notes[legacyKey] else {
                continue
            }

            let matchingNotes = existingNotes.filter {
                $0.lastPathComponent == legacyKey
            }

            // Nur migrieren, wenn der Dateiname eindeutig ist.
            guard matchingNotes.count == 1 else {
                continue
            }

            metadata.notes[key] = legacyValue
            changed = true
        }

        if changed {
            saveMetadata()
        }
    }

    // MARK: - Tags

    func tags(for url: URL) -> [String] {
        metadata.notes[metadataKey(for: url)]?.tags ?? []
    }

    func setTags(_ tags: [String], for url: URL) {
        do {
            try validateNoteURL(url)
        } catch {
            NSLog(
                "My Notes: Tags konnten nicht gespeichert werden: %@",
                error.localizedDescription
            )
            return
        }

        var seen = Set<String>()

        let cleanedTags = tags.compactMap { tag -> String? in
            let cleaned = tag.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard !cleaned.isEmpty else {
                return nil
            }

            guard seen.insert(cleaned.localizedLowercase).inserted else {
                return nil
            }

            return cleaned
        }

        updateMetadata(for: url) {
            $0.tags = cleanedTags
        }
    }

    // MARK: - Folder Management

    /// Liefert die direkten Unterordner eines Ordners.
    /// nil steht für den internen Hauptordner.
    ///
    /// Diese Methode ist für eine hierarchische Sidebar gedacht:
    /// Jeder Ordner kann seine eigenen Unterordner laden.
    func listSubfolders(in parentURL: URL? = nil) -> [URL] {
        let parent = parentURL ?? notesDirectory

        guard (try? validateNotesDirectory(parent)) != nil else {
            return []
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return children
            .filter { child in
                guard child.lastPathComponent != ".Trash",
                      !isTrashURL(child) else {
                    return false
                }

                return (try? child.resourceValues(
                    forKeys: [.isDirectoryKey]
                ).isDirectory) == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare(
                    $1.lastPathComponent
                ) == .orderedAscending
            }
    }

    /// Liefert alle Ordner einschließlich sämtlicher Unterordner.
    func listFolders() -> [URL] {
        var result: [URL] = []

        func collectFolders(in directory: URL) {
            let children = listSubfolders(in: directory)

            for child in children {
                result.append(child)
                collectFolders(in: child)
            }
        }

        collectFolders(in: notesDirectory)

        return result
    }

    /// Erstellt einen Ordner im Hauptordner oder im angegebenen Elternordner.
    func createFolder(
        named name: String,
        in parentURL: URL? = nil
    ) throws -> URL {
        let safeName: String

        do {
            safeName = try sanitizedName(name)
        } catch {
            throw NoteStorageError.invalidFolderName
        }

        let parent = parentURL ?? notesDirectory

        try validateNotesDirectory(parent)

        let folderURL = parent.appendingPathComponent(
            safeName,
            isDirectory: true
        )

        guard !fileManager.fileExists(atPath: folderURL.path) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: false
        )

        return folderURL
    }

    /// Benennt einen Ordner um und aktualisiert Metadaten seiner Notizen.
    func renameFolder(at url: URL, to newName: String) throws -> URL {
        guard isInsideNotesDirectory(url),
              !isTrashURL(url),
              url.lastPathComponent != ".Trash",
              (try? url.resourceValues(
                  forKeys: [.isDirectoryKey]
              ).isDirectory) == true else {
            throw NoteStorageError.outsideNotesDirectory
        }

        let safeName: String

        do {
            safeName = try sanitizedName(newName)
        } catch {
            throw NoteStorageError.invalidFolderName
        }

        let parent = url.deletingLastPathComponent()

        try validateNotesDirectory(parent)

        let destination = parent.appendingPathComponent(
            safeName,
            isDirectory: true
        )

        if normalizedPath(destination) == normalizedPath(url) {
            return url
        }

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw NoteStorageError.fileAlreadyExists
        }

        let oldPrefix = url.standardizedFileURL.path + "/"
        let newPrefix = destination.standardizedFileURL.path + "/"

        try fileManager.moveItem(at: url, to: destination)

        var updatedMetadata: [String: NoteMetadata] = [:]

        for (key, value) in metadata.notes {
            if key.hasPrefix(oldPrefix) {
                let suffix = String(key.dropFirst(oldPrefix.count))
                updatedMetadata[newPrefix + suffix] = value
            } else {
                updatedMetadata[key] = value
            }
        }

        metadata.notes = updatedMetadata
        saveMetadata()

        return destination
    }

    /// Löscht nur leere Ordner, damit keine Notizen verloren gehen.
    func deleteFolder(at url: URL) throws {
        guard isInsideNotesDirectory(url),
              !isTrashURL(url),
              url.lastPathComponent != ".Trash",
              (try? url.resourceValues(
                  forKeys: [.isDirectoryKey]
              ).isDirectory) == true else {
            throw NoteStorageError.outsideNotesDirectory
        }

        guard fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )

        guard contents.isEmpty else {
            throw CocoaError(.fileWriteFileExists)
        }

        try fileManager.removeItem(at: url)
    }

    /// Verschiebt eine Notiz in den ausgewählten Ordner.
    /// nil bedeutet den Hauptordner.
    func moveNote(
        _ noteURL: URL,
        toFolder folderURL: URL?
    ) throws -> URL {
        try validateNoteURL(noteURL)

        let destinationDirectory = folderURL ?? notesDirectory

        try validateNotesDirectory(destinationDirectory)

        let destination = destinationDirectory.appendingPathComponent(
            noteURL.lastPathComponent
        )

        if normalizedPath(destination) == normalizedPath(noteURL) {
            return noteURL
        }

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try fileManager.moveItem(at: noteURL, to: destination)

        moveMetadata(from: noteURL, to: destination)

        return destination
    }

    private func moveMetadata(from oldURL: URL, to newURL: URL) {
        let oldKey = metadataKey(for: oldURL)
        let newKey = metadataKey(for: newURL)

        if let value = metadata.notes.removeValue(forKey: oldKey) {
            metadata.notes[newKey] = value
            saveMetadata()
        }
    }

    // MARK: - Create Notes

    func createNote(title: String, fileType: String) throws -> URL {
        try createNote(
            title: title,
            fileType: fileType,
            in: nil
        )
    }

    func createNote(
        title: String,
        fileType: String,
        in folderURL: URL?
    ) throws -> URL {
        let ext = fileType.lowercased()

        guard supportedExtensions.contains(ext) else {
            throw NoteStorageError.unsupportedFile
        }

        let safeTitle = try sanitizedName(
            title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty ? "Unbenannte Notiz" : title
        )

        let directory = folderURL ?? notesDirectory

        try validateNotesDirectory(directory)

        let destination = directory
            .appendingPathComponent(safeTitle)
            .appendingPathExtension(ext)

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try Data().write(
            to: destination,
            options: .atomic
        )

        metadata.notes[metadataKey(for: destination)] = NoteMetadata()
        saveMetadata()

        return destination
    }

    // MARK: - Save and Load

    func save(text: String, to url: URL) throws {
        try validateNoteURL(url)

        try Data(text.utf8).write(
            to: url,
            options: .atomic
        )
    }

    func load(from url: URL) throws -> String {
        try validateNoteURL(url)

        return try String(
            contentsOf: url,
            encoding: .utf8
        )
    }

    // MARK: - Rename Notes

    func renameNote(at url: URL, to newTitle: String) throws -> URL {
        try validateNoteURL(url)

        let trimmed = newTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return url
        }

        let safeTitle = try sanitizedName(trimmed)

        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(safeTitle)
            .appendingPathExtension(url.pathExtension)

        if normalizedPath(destination) == normalizedPath(url) {
            return url
        }

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw NoteStorageError.fileAlreadyExists
        }

        try fileManager.moveItem(at: url, to: destination)

        moveMetadata(from: url, to: destination)

        return destination
    }

    // MARK: - Trash

    func trashNote(at url: URL) throws {
        try validateNoteURL(url)

        guard fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        var destination = trashDirectory.appendingPathComponent(
            url.lastPathComponent
        )

        if fileManager.fileExists(atPath: destination.path) {
            destination = trashDirectory.appendingPathComponent(
                UUID().uuidString + "-" + url.lastPathComponent
            )
        }

        try fileManager.moveItem(at: url, to: destination)

        moveMetadata(from: url, to: destination)
    }

    func listTrashedNotes() -> [URL] {
        do {
            return try fileManager.contentsOfDirectory(
                at: trashDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter {
                isSupportedFile($0)
            }
            .filter {
                (try? $0.resourceValues(
                    forKeys: [.isRegularFileKey]
                ).isRegularFile) == true
            }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare(
                    $1.lastPathComponent
                ) == .orderedAscending
            }
        } catch {
            return []
        }
    }

    func restoreNote(at url: URL) throws -> URL {
        try validateTrashURL(url)

        let filename = url.lastPathComponent
        let originalName: String

        if filename.count > 37,
           UUID(uuidString: String(filename.prefix(36))) != nil,
           filename.dropFirst(36).first == "-" {
            originalName = String(filename.dropFirst(37))
        } else {
            originalName = filename
        }

        var destination = notesDirectory.appendingPathComponent(
            originalName
        )

        if fileManager.fileExists(atPath: destination.path) {
            let base = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            var counter = 1

            repeat {
                destination = notesDirectory.appendingPathComponent(
                    "\(base) (Wiederhergestellt \(counter))"
                ).appendingPathExtension(ext)

                counter += 1
            } while fileManager.fileExists(atPath: destination.path)
        }

        try fileManager.moveItem(at: url, to: destination)

        moveMetadata(from: url, to: destination)

        return destination
    }

    func permanentlyDeleteNote(at url: URL) throws {
        try validateTrashURL(url)

        guard fileManager.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.removeItem(at: url)

        metadata.notes.removeValue(
            forKey: metadataKey(for: url)
        )

        saveMetadata()
    }

    // MARK: - Pinning

    func isPinned(_ url: URL) -> Bool {
        metadata.notes[metadataKey(for: url)]?.isPinned ?? false
    }

    func setPinned(_ pinned: Bool, for url: URL) throws {
        try validateNoteURL(url)

        updateMetadata(for: url) {
            $0.isPinned = pinned
        }
    }

    func togglePinned(for url: URL) throws {
        try setPinned(!isPinned(url), for: url)
    }

    // MARK: - Recently Opened

    func markOpened(_ url: URL) throws {
        try validateNoteURL(url)

        updateMetadata(for: url) {
            $0.lastOpened = Date()
        }
    }

    func lastOpenedDate(for url: URL) -> Date? {
        metadata.notes[metadataKey(for: url)]?.lastOpened
    }

    func recentlyOpenedNotes(limit: Int = 10) -> [URL] {
        listNotes()
            .filter {
                lastOpenedDate(for: $0) != nil
            }
            .sorted {
                (lastOpenedDate(for: $0) ?? .distantPast)
                    > (lastOpenedDate(for: $1) ?? .distantPast)
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    func pinnedNotes() -> [URL] {
        listNotes().filter {
            isPinned($0)
        }
    }

    // MARK: - List and Search

    /// Listet direkte Notizen im angegebenen Ordner.
    /// nil bedeutet den Hauptordner.
    func listNotes(in folderURL: URL? = nil) -> [URL] {
        let directory = folderURL ?? notesDirectory

        guard isNotesDirectoryOrInside(directory),
              !isTrashURL(directory),
              (try? directory.resourceValues(
                  forKeys: [.isDirectoryKey]
              ).isDirectory) == true else {
            return []
        }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey
                ],
                options: [.skipsHiddenFiles]
            )

            return urls
                .filter {
                    isSupportedFile($0)
                }
                .filter {
                    (try? $0.resourceValues(
                        forKeys: [.isRegularFileKey]
                    ).isRegularFile) == true
                }
                .sorted { first, second in
                    if isPinned(first) != isPinned(second) {
                        return isPinned(first)
                    }

                    let firstDate = (try? first.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate) ?? .distantPast

                    let secondDate = (try? second.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate) ?? .distantPast

                    return firstDate > secondDate
                }
        } catch {
            return []
        }
    }

    /// Listet Notizen aus dem Hauptordner und allen Unterordnern.
    func listNotes() -> [URL] {
        let allFolders = listFolders()

        return listNotes(in: nil) + allFolders.flatMap {
            listNotes(in: $0)
        }
    }

    /// Durchsucht Notiznamen, Tags und den Inhalt aller Notizen
    /// unabhängig davon, in welchem Ordner sie gespeichert sind.
    func searchNotes(query: String) -> [URL] {
        let allNotes = listNotes()

        let normalized = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalized.isEmpty else {
            return allNotes
        }

        return allNotes.filter { url in
            let title = url.deletingPathExtension().lastPathComponent

            if title.localizedCaseInsensitiveContains(normalized) {
                return true
            }

            if tags(for: url).contains(where: {
                $0.localizedCaseInsensitiveContains(normalized)
            }) {
                return true
            }

            let content = (try? load(from: url)) ?? ""

            return content.localizedCaseInsensitiveContains(normalized)
        }
    }

    /// Prüft den Dateityp. Die Pfad- und Dateiprüfungen erfolgen
    /// zusätzlich in den jeweiligen Speicheroperationen.
    func isSupportedFile(_ url: URL) -> Bool {
        supportedExtensions.contains(
            url.pathExtension.lowercased()
        )
    }
}
