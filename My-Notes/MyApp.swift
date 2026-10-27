
import SwiftUI

@main
struct MyNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neue Notiz") {
                    NotificationCenter.default.post(
                        name: .newNoteRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Notizen suchen") {
                    NotificationCenter.default.post(
                        name: .openNoteRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Speichern") {
                    NotificationCenter.default.post(
                        name: .saveNoteRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Löschen") {
                    NotificationCenter.default.post(
                        name: .deleteSelectedItemRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Aktionen") {
                    NotificationCenter.default.post(
                        name: .togglePaletteRequested,
                        object: nil
                    )
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newNoteRequested =
        Notification.Name("newNoteRequested")

    static let openNoteRequested =
        Notification.Name("openNoteRequested")

    static let saveNoteRequested =
        Notification.Name("saveNoteRequested")

    static let deleteNoteRequested =
        Notification.Name("deleteNoteRequested")

    static let deleteSelectedItemRequested =
        Notification.Name("deleteSelectedItemRequested")

    static let togglePaletteRequested =
        Notification.Name("togglePaletteRequested")
}
