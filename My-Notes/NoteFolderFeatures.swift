
import SwiftUI
import AppKit

extension ContentView {
    // MARK: - Folder Actions

    func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = "Neuen Ordner erstellen"
        alert.informativeText = selectedFolderPath == nil
            ? "Gib einen Namen für den Ordner ein."
            : "Gib einen Namen für den Unterordner ein."

        alert.addButton(withTitle: "Erstellen")
        alert.addButton(withTitle: "Abbrechen")

        let input = NSTextField(
            frame: NSRect(x: 0, y: 0, width: 240, height: 24)
        )
        input.placeholderString = "Ordnername"
        input.stringValue = ""

        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let folderName = input.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !folderName.isEmpty else {
            saveError = "Bitte gib einen Ordnernamen ein."
            return
        }

        do {
            let parentFolder: URL?

            if let selectedFolderPath {
                let url = URL(
                    fileURLWithPath: selectedFolderPath,
                    isDirectory: true
                )

                var isDirectory: ObjCBool = false

                guard FileManager.default.fileExists(
                    atPath: url.path,
                    isDirectory: &isDirectory
                ), isDirectory.boolValue else {
                    saveError = "Der ausgewählte übergeordnete Ordner existiert nicht mehr."
                    return
                }

                parentFolder = url
            } else {
                parentFolder = nil
            }

            let folder = try storage.createFolder(
                named: folderName,
                in: parentFolder
            )

            refreshAll()

            selectedFolderPath = folder.standardizedFileURL.path
            showingOnlyUnfiled = false

            // Den neu erstellten Ordner und seine Eltern aufklappen.
            var parent = folder.deletingLastPathComponent()

            while parent.standardizedFileURL.path
                != storage.notesDirectory.standardizedFileURL.path {
                expandedFolderPaths.insert(
                    parent.standardizedFileURL.path
                )
                parent = parent.deletingLastPathComponent()
            }

            saveExpandedFolders()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func renameFolder(_ folder: URL) {
        let alert = NSAlert()
        alert.messageText = "Ordner umbenennen"
        alert.addButton(withTitle: "Umbenennen")
        alert.addButton(withTitle: "Abbrechen")

        let input = NSTextField(
            frame: NSRect(x: 0, y: 0, width: 240, height: 24)
        )
        input.stringValue = folder.lastPathComponent
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            let renamed = try storage.renameFolder(
                at: folder,
                to: input.stringValue
            )

            let oldPath = folder.standardizedFileURL.path
            let newPath = renamed.standardizedFileURL.path

            if let selectedFolderPath {
                if selectedFolderPath == oldPath {
                    self.selectedFolderPath = newPath
                } else if selectedFolderPath.hasPrefix(oldPath + "/") {
                    self.selectedFolderPath = newPath
                        + selectedFolderPath.dropFirst(oldPath.count)
                }
            }

            if let currentFileURL,
               currentFileURL.standardizedFileURL.path.hasPrefix(oldPath + "/") {
                // Der Pfad der geöffneten Notiz wird nach dem Umbenennen
                // anhand des relativen Pfads im Ordner aktualisiert.
                let relativePath = String(
                    currentFileURL.standardizedFileURL.path
                        .dropFirst(oldPath.count + 1)
                )
                self.currentFileURL = renamed.appendingPathComponent(relativePath)
            }

            refreshAll()
        } catch {
            saveError = error.localizedDescription
        }
    }

    func deleteFolder(_ folder: URL) {
        do {
            try storage.deleteFolder(at: folder)

            let deletedPath = folder.standardizedFileURL.path

            if let selectedFolderPath,
               selectedFolderPath == deletedPath
                || selectedFolderPath.hasPrefix(deletedPath + "/") {
                self.selectedFolderPath = nil
            }

            refreshAll()
        } catch {
            saveError = """
            Der Ordner konnte nicht gelöscht werden. Stelle sicher, dass er leer ist.
            \(error.localizedDescription)
            """
        }
    }

    func moveDroppedNotes(_ paths: [String], to folder: URL?) -> Bool {
        var movedAtLeastOne = false

        for path in paths {
            let noteURL = URL(fileURLWithPath: path)

            guard storage.isSupportedFile(noteURL) else {
                continue
            }

            do {
                let movedURL = try storage.moveNote(
                    noteURL,
                    toFolder: folder
                )

                if currentFileURL?.standardizedFileURL == noteURL.standardizedFileURL {
                    currentFileURL = movedURL
                }

                movedAtLeastOne = true
            } catch {
                saveError = error.localizedDescription
            }
        }

        if movedAtLeastOne {
            refreshAll()
        }

        return movedAtLeastOne
    }
}
