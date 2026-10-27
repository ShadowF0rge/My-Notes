
import SwiftUI
import AppKit

extension ContentView {

    // MARK: - Autosave

    func markAsChanged() {
        guard !isLoadingNote else { return }

        isDirty = true
        saveStatus = "Ungespeicherte Änderungen"
        scheduleAutosave()
    }

    func scheduleAutosave() {
        autosaveTask?.cancel()

        autosaveTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            saveImmediately()
        }
    }

    // MARK: - Saving

    func saveImmediately() {
        autosaveTask?.cancel()

        do {
            let trimmedTitle = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let finalTitle = trimmedTitle.isEmpty
                ? "Unbenannte Notiz"
                : trimmedTitle

            let destinationURL: URL

            if let existingURL = currentFileURL {
                let expectedURL = existingURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(finalTitle)
                    .appendingPathExtension(fileType.rawValue)

                if existingURL.standardizedFileURL
                    != expectedURL.standardizedFileURL {
                    var renamedURL = try storage.renameNote(
                        at: existingURL,
                        to: finalTitle
                    )

                    if renamedURL.pathExtension.lowercased()
                        != fileType.rawValue {
                        let correctedURL = renamedURL
                            .deletingPathExtension()
                            .appendingPathExtension(fileType.rawValue)

                        guard !FileManager.default.fileExists(
                            atPath: correctedURL.path
                        ) else {
                            throw NoteStorageError.fileAlreadyExists
                        }

                        try FileManager.default.moveItem(
                            at: renamedURL,
                            to: correctedURL
                        )
                        renamedURL = correctedURL
                    }

                    destinationURL = renamedURL
                } else {
                    destinationURL = existingURL
                }
            } else {
                let folderURL: URL? = selectedFolderPath.map {
                    URL(fileURLWithPath: $0, isDirectory: true)
                }

                destinationURL = try storage.createNote(
                    title: finalTitle,
                    fileType: fileType.rawValue,
                    in: folderURL
                )
            }

            try storage.save(text: noteText, to: destinationURL)

            isLoadingNote = true
            currentFileURL = destinationURL
            title = finalTitle
            isDirty = false
            saveStatus = "Gespeichert"

            saveTags()
            refreshAll()

            Task { @MainActor in
                await Task.yield()
                isLoadingNote = false
            }
        } catch {
            saveStatus = "Speichern fehlgeschlagen"
            saveError = error.localizedDescription
        }
    }

    // MARK: - Tags

    func saveTags() {
        guard let currentFileURL else { return }

        let tags = tagText
            .split(separator: ",")
            .map {
                String($0).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        NoteFeatures.setTags(tags, for: currentFileURL)
    }

    func addTag() {
        let newTag = newTagText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !newTag.isEmpty else { return }

        var tags = tagText
            .split(separator: ",")
            .map {
                String($0).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        guard !tags.contains(where: {
            $0.localizedCaseInsensitiveCompare(newTag) == .orderedSame
        }) else {
            isTagEditorPresented = false
            newTagText = ""
            return
        }

        tags.append(newTag)
        tagText = tags.joined(separator: ", ")

        saveTags()

        isTagEditorPresented = false
        newTagText = ""
    }

    func removeTag(_ tag: String) {
        let tags = tagText
            .split(separator: ",")
            .map {
                String($0).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty && $0 != tag }

        tagText = tags.joined(separator: ", ")
        saveTags()
    }

    // MARK: - Opening Notes

    func openNote(at url: URL) {
        guard currentFileURL?.standardizedFileURL
            != url.standardizedFileURL else {
            return
        }

        if isDirty {
            saveImmediately()
        }

        autosaveTask?.cancel()

        do {
            let loadedText = try storage.load(from: url)
            try storage.markOpened(url)

            isLoadingNote = true
            currentFileURL = url
            title = url.deletingPathExtension().lastPathComponent
            noteText = loadedText
            fileType = NoteFileType(
                rawValue: url.pathExtension.lowercased()
            ) ?? .txt
            tagText = NoteFeatures.tags(for: url).joined(separator: ", ")

            if !availableFonts.contains(fontName) {
                fontName = availableFonts.first ?? "Helvetica Neue"
            }

            isDirty = false
            saveStatus = "Gespeichert"
            searchFocused = false

            Task { @MainActor in
                await Task.yield()
                isLoadingNote = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    func createNewNote() {
        if isDirty {
            saveImmediately()
        }

        autosaveTask?.cancel()
        isLoadingNote = true
        currentFileURL = nil
        title = ""
        noteText = ""
        tagText = ""
        newTagText = ""
        fileType = .txt
        isDirty = false
        saveStatus = "Neue Notiz"

        Task { @MainActor in
            await Task.yield()
            isLoadingNote = false
        }
    }

    // MARK: - Pinning

    func togglePin(_ url: URL) {
        do {
            try storage.togglePinned(for: url)
            refreshNotes()

            if currentFileURL?.standardizedFileURL
                == url.standardizedFileURL {
                saveStatus = storage.isPinned(url)
                    ? "Notiz angeheftet"
                    : "Anheftung gelöst"
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    func toggleCurrentPin() {
        guard let currentFileURL else { return }
        togglePin(currentFileURL)
    }

    // MARK: - Export

    func exportMarkdown() {
        if isDirty { saveImmediately() }

        NoteUtilities.exportMarkdown(
            text: noteText,
            title: title
        )
    }

    func exportText() {
        if isDirty { saveImmediately() }

        NoteUtilities.exportText(
            text: noteText,
            title: title
        )
    }

    // MARK: - Trash

    var trashSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Papierkorb")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button("Fertig") {
                    showingTrash = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            if trashedNotes.isEmpty {
                Spacer()

                Image(systemName: "trash")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)

                Text("Der Papierkorb ist leer")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Spacer()
            } else {
                List {
                    ForEach(trashedNotes, id: \.path) { url in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(
                                    url.deletingPathExtension().lastPathComponent
                                )
                                .font(.system(size: 12))

                                Text(url.pathExtension.uppercased())
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Wiederherstellen") {
                                restoreNote(url)
                            }
                            .font(.system(size: 11))

                            Button {
                                noteToDeletePermanently = url
                                showingPermanentDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash.slash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 540, height: 390)
        .background(NoteTheme.background)
    }

    func deleteCurrentNote() {
        guard let url = currentFileURL else {
            saveError = "Es ist keine gespeicherte Notiz geöffnet."
            return
        }

        moveNoteToTrash(at: url)
    }

    func moveNoteToTrash(at url: URL) {
        autosaveTask?.cancel()

        let isCurrentNote = currentFileURL?.standardizedFileURL
            == url.standardizedFileURL

        do {
            try storage.trashNote(at: url)

            if isCurrentNote {
                isLoadingNote = true
                currentFileURL = nil
                title = ""
                noteText = ""
                tagText = ""
                newTagText = ""
                fileType = .txt
                isDirty = false
                saveStatus = "Notiz im Papierkorb"

                Task { @MainActor in
                    await Task.yield()
                    isLoadingNote = false
                }
            }

            refreshAll()
            refreshTrash()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func refreshTrash() {
        trashedNotes = storage.listTrashedNotes()
    }

    func restoreNote(_ url: URL) {
        do {
            _ = try storage.restoreNote(at: url)
            refreshTrash()
            refreshAll()
        } catch {
            showingRestoreError = error.localizedDescription
        }
    }

    func permanentlyDeleteSelectedNote() {
        guard let url = noteToDeletePermanently else { return }

        do {
            try storage.permanentlyDeleteNote(at: url)
            noteToDeletePermanently = nil
            refreshTrash()
        } catch {
            noteToDeletePermanently = nil
            showingRestoreError = error.localizedDescription
        }
    }

    // MARK: - File Type

    func changeFileType(to newType: NoteFileType) {
        guard newType != fileType else { return }

        autosaveTask?.cancel()

        do {
            if let existingURL = currentFileURL {
                let newURL = existingURL
                    .deletingPathExtension()
                    .appendingPathExtension(newType.rawValue)

                guard !FileManager.default.fileExists(
                    atPath: newURL.path
                ) else {
                    saveError = "Eine Datei mit diesem Namen existiert bereits."
                    return
                }

                try FileManager.default.moveItem(
                    at: existingURL,
                    to: newURL
                )
                currentFileURL = newURL
            }

            fileType = newType

            if !availableFonts.contains(fontName) {
                fontName = availableFonts.first ?? "Helvetica Neue"
            }

            if currentFileURL != nil {
                saveImmediately()
            } else {
                isDirty = true
                saveStatus = "Dateityp geändert"
            }

            refreshAll()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Refresh

    func refreshAll() {
        folders = storage.listFolders()
        refreshNotes()
    }

    func refreshNotes() {
        notes = storage.searchNotes(query: searchQuery)
    }

    // MARK: - Command Palette

    func togglePalette() {
        if CommandPaletteController.shared.isVisible {
            CommandPaletteController.shared.close()
        } else {
            CommandPaletteController.shared.show(
                relativeTo: NSApp.keyWindow,
                commands: paletteCommands,
                onAction: handlePaletteCommand
            )
        }
    }

    func handlePaletteCommand(_ commandID: String) {
        CommandPaletteController.shared.close()

        switch commandID {
        case "new":
            createNewNote()
        case "newFolder":
            createNewFolder()
        case "search":
            isSidebarVisible = true
            searchFocused = true
        case "save":
            saveImmediately()
        case "delete":
            deleteCurrentNote()
        case "pin":
            toggleCurrentPin()
        case "exportMarkdown":
            exportMarkdown()
        case "exportText":
            exportText()
        case "copy":
            NoteUtilities.copyToClipboard(noteText)
            saveStatus = "In Zwischenablage kopiert"
        case "trash":
            refreshTrash()
            showingTrash = true
        case "font":
            saveStatus = "Schriftart über das Menü ändern"
        case "filetype":
            saveStatus = "Dateityp über das Menü ändern"
        default:
            break
        }
    }
}
