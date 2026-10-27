
import SwiftUI
import AppKit

private enum NoteFileType: String, CaseIterable, Identifiable {
    case txt
    case py
    case java
    case js
    case html
    case css
    case json
    case md

    var id: String { rawValue }

    var label: String {
        switch self {
        case .txt: return "Text"
        case .py: return "Python"
        case .java: return "Java"
        case .js: return "JavaScript"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .md: return "Markdown"
        }
    }

    var isCode: Bool {
        self != .txt && self != .md
    }

    var symbol: String {
        switch self {
        case .txt: return "doc.text"
        case .py: return "chevron.left.forwardslash.chevron.right"
        case .java: return "cup.and.saucer"
        case .js: return "curlybraces"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .css: return "paintbrush"
        case .json: return "curlybraces"
        case .md: return "text.alignleft"
        }
    }
}

private enum NoteTheme {
    static let background = Color(
        red: 0.075,
        green: 0.07,
        blue: 0.08
    )

    static let sidebar = Color(
        red: 0.09,
        green: 0.085,
        blue: 0.095
    )

    static let surface = Color(
        red: 0.12,
        green: 0.11,
        blue: 0.12
    )

    static let accent = Color(
        red: 0.78,
        green: 0.38,
        blue: 0.42
    )

    static let selection = Color(
        red: 0.22,
        green: 0.105,
        blue: 0.12
    )

    static let primaryText = Color(
        red: 0.91,
        green: 0.89,
        blue: 0.91
    )

    static let secondaryText = Color.secondary
}

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let shortcut: String
}

struct ContentView: View {
    private let storage = NoteStorage.shared

    @State private var title = ""
    @State private var noteText = ""
    @State private var fileType: NoteFileType = .txt
    @State private var currentFileURL: URL?

    @State private var saveStatus = "Bereit"
    @State private var saveError: String?

    @State private var fontSize: Double = 14
    @State private var fontName = "Helvetica Neue"
    @State private var isFontSizePopoverPresented = false

    @State private var searchQuery = ""
    @State private var notes: [URL] = []
    @State private var autosaveTask: Task<Void, Never>?

    @State private var isDirty = false
    @State private var isLoadingNote = false
    @State private var searchFocused = false

    private let standardFonts = [
        "Helvetica Neue",
        "Arial",
        "Avenir Next",
        "Georgia",
        "Times New Roman"
    ]

    private let codeFonts = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New"
    ]

    private var availableFonts: [String] {
        fileType.isCode ? codeFonts : standardFonts
    }

    private var paletteCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "new",
                title: "Neue Notiz",
                symbol: "plus",
                shortcut: "⌘ N"
            ),
            PaletteCommand(
                id: "search",
                title: "Notizen suchen",
                symbol: "magnifyingglass",
                shortcut: "⌘ O"
            ),
            PaletteCommand(
                id: "save",
                title: "Speichern",
                symbol: "square.and.arrow.down",
                shortcut: "⌘ S"
            ),
            PaletteCommand(
                id: "delete",
                title: "In den Papierkorb verschieben",
                symbol: "trash",
                shortcut: "⌘ D"
            ),
            PaletteCommand(
                id: "font",
                title: "Schriftart ändern",
                symbol: "textformat",
                shortcut: ""
            ),
            PaletteCommand(
                id: "filetype",
                title: "Dateityp ändern",
                symbol: "doc.badge.gearshape",
                shortcut: ""
            )
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 1)

            editor
        }
        .frame(minWidth: 680, minHeight: 440)
        .background(NoteTheme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshNotes()
        }
        .onChange(of: noteText) {
            markAsChanged()
        }
        .onChange(of: title) {
            markAsChanged()
        }
        .onChange(of: searchQuery) {
            refreshNotes()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .newNoteRequested
            )
        ) { _ in
            createNewNote()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .openNoteRequested
            )
        ) { _ in
            searchFocused = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .saveNoteRequested
            )
        ) { _ in
            saveImmediately()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .deleteNoteRequested
            )
        ) { _ in
            deleteCurrentNote()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .togglePaletteRequested
            )
        ) { _ in
            togglePalette()
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(saveError ?? "Ein unbekannter Fehler ist aufgetreten.")
        }
        .onDisappear {
            autosaveTask?.cancel()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My Notes")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NoteTheme.primaryText)

                Spacer()

                Button {
                    createNewNote()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(NoteTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Neue Notiz")
            }
            .padding(.horizontal, 14)
            .padding(.top, 15)
            .padding(.bottom, 13)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Notizen suchen", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        if let firstNote = notes.first {
                            openNote(at: firstNote)
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(NoteTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(notes, id: \.path) { url in
                        noteRow(url)
                    }
                }
                .padding(.horizontal, 7)
            }

            Divider()
                .overlay(Color.white.opacity(0.04))

            HStack {
                Text("\(notes.count) Notizen")
                Spacer()
                Text("⌘ K")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
        }
        .frame(width: 220)
        .background(NoteTheme.sidebar)
    }

    private func noteRow(_ url: URL) -> some View {
        let selected = currentFileURL?.standardizedFileURL
            == url.standardizedFileURL

        let type = NoteFileType(
            rawValue: url.pathExtension.lowercased()
        ) ?? .txt

        return Button {
            openNote(at: url)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: type.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        selected ? NoteTheme.accent : .secondary
                    )
                    .frame(width: 17)

                VStack(alignment: .leading, spacing: 3) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(NoteTheme.primaryText)

                    Text(type.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? NoteTheme.selection : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                openNote(at: url)
            } label: {
                Label("Öffnen", systemImage: "doc.text")
            }

            Button(role: .destructive) {
                moveNoteToTrash(at: url)
            } label: {
                Label(
                    "In den Papierkorb verschieben",
                    systemImage: "trash"
                )
            }
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Titel der Notiz", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NoteTheme.primaryText)

                Spacer()

                Menu {
                    Section("Schriftart") {
                        ForEach(availableFonts, id: \.self) { font in
                            Button {
                                fontName = font
                            } label: {
                                if fontName == font {
                                    Label(font, systemImage: "checkmark")
                                } else {
                                    Text(font)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .background(NoteTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .help("Schriftart ändern")

                Button {
                    isFontSizePopoverPresented.toggle()
                } label: {
                    Text("\(Int(fontSize))")
                        .font(.system(size: 12))
                        .frame(width: 34, height: 30)
                        .background(NoteTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .popover(
                    isPresented: $isFontSizePopoverPresented,
                    arrowEdge: .bottom
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schriftgröße")
                            .font(.system(size: 13, weight: .semibold))

                        Slider(
                            value: $fontSize,
                            in: 10...32,
                            step: 1
                        )

                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(width: 220)
                }
                .help("Schriftgröße ändern")

                Menu {
                    ForEach(NoteFileType.allCases) { type in
                        Button {
                            changeFileType(to: type)
                        } label: {
                            if fileType == type {
                                Label(
                                    type.label,
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(type.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: fileType.symbol)
                        Text(fileType.rawValue.uppercased())
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(NoteTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .help("Dateityp ändern")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)

            Divider()
                .overlay(Color.white.opacity(0.04))

            TextEditor(text: $noteText)
                .font(
                    .custom(
                        fontName,
                        size: fontSize
                    )
                )
                .scrollContentBackground(.hidden)
                .foregroundStyle(NoteTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.04))

            HStack(spacing: 10) {
                Circle()
                    .fill(isDirty ? NoteTheme.accent : Color.green.opacity(0.7))
                    .frame(width: 6, height: 6)

                Text(saveStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    togglePalette()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "command")
                        Text("Aktionen")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Aktionsliste öffnen (⌘ K)")

                Button {
                    saveImmediately()
                } label: {
                    Text("Speichern")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NoteTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(NoteTheme.selection)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("Notiz speichern (⌘ S)")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
        }
        .background(NoteTheme.background)
    }

    // MARK: - Autosave

    private func markAsChanged() {
        guard !isLoadingNote else {
            return
        }

        isDirty = true
        saveStatus = "Ungespeicherte Änderungen"
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        autosaveTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            saveImmediately()
        }
    }

    // MARK: - Saving

    private func saveImmediately() {
        autosaveTask?.cancel()

        do {
            let trimmedTitle = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            let finalTitle = trimmedTitle.isEmpty
                ? "Unbenannte Notiz"
                : trimmedTitle

            var destinationURL: URL

            if let existingURL = currentFileURL {
                let expectedURL = existingURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(finalTitle)
                    .appendingPathExtension(fileType.rawValue)

                if existingURL.standardizedFileURL
                    != expectedURL.standardizedFileURL {
                    destinationURL = try storage.renameNote(
                        at: existingURL,
                        to: finalTitle
                    )

                    if destinationURL.pathExtension.lowercased()
                        != fileType.rawValue {
                        let correctedURL = destinationURL
                            .deletingPathExtension()
                            .appendingPathExtension(fileType.rawValue)

                        try FileManager.default.moveItem(
                            at: destinationURL,
                            to: correctedURL
                        )

                        destinationURL = correctedURL
                    }
                } else {
                    destinationURL = existingURL
                }
            } else {
                destinationURL = try storage.createNote(
                    title: finalTitle,
                    fileType: fileType.rawValue
                )
            }

            try storage.save(
                text: noteText,
                to: destinationURL
            )

            isLoadingNote = true
            currentFileURL = destinationURL
            title = finalTitle
            isDirty = false
            saveStatus = "Gespeichert"

            refreshNotes()

            Task { @MainActor in
                await Task.yield()
                isLoadingNote = false
            }
        } catch {
            saveStatus = "Speichern fehlgeschlagen"
            saveError = error.localizedDescription
        }
    }

    // MARK: - Opening notes

    private func openNote(at url: URL) {
        if currentFileURL?.standardizedFileURL == url.standardizedFileURL {
            return
        }

        if isDirty || currentFileURL == nil && !noteText.isEmpty {
            saveImmediately()
        }

        autosaveTask?.cancel()

        do {
            let loadedText = try storage.load(from: url)

            isLoadingNote = true

            currentFileURL = url
            title = url.deletingPathExtension().lastPathComponent
            noteText = loadedText
            fileType = NoteFileType(
                rawValue: url.pathExtension.lowercased()
            ) ?? .txt

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

    private func createNewNote() {
        if isDirty {
            saveImmediately()
        }

        autosaveTask?.cancel()

        isLoadingNote = true
        currentFileURL = nil
        title = ""
        noteText = ""
        fileType = .txt
        isDirty = false
        saveStatus = "Neue Notiz"

        Task { @MainActor in
            await Task.yield()
            isLoadingNote = false
        }
    }

    // MARK: - Trash

    private func deleteCurrentNote() {
        guard let url = currentFileURL else {
            saveError = "Es ist keine gespeicherte Notiz geöffnet."
            return
        }

        moveNoteToTrash(at: url)
    }

    private func moveNoteToTrash(at url: URL) {
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
                fileType = .txt
                isDirty = false
                saveStatus = "Notiz im Papierkorb"

                Task { @MainActor in
                    await Task.yield()
                    isLoadingNote = false
                }
            }

            refreshNotes()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - File type

    private func changeFileType(to newType: NoteFileType) {
        guard newType != fileType else {
            return
        }

        autosaveTask?.cancel()

        do {
            if let existingURL = currentFileURL {
                let newURL = existingURL
                    .deletingPathExtension()
                    .appendingPathExtension(newType.rawValue)

                if FileManager.default.fileExists(atPath: newURL.path) {
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

            refreshNotes()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Search

    private func refreshNotes() {
        notes = storage.searchNotes(query: searchQuery)
    }

    // MARK: - Command palette

    private func togglePalette() {
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

    private func handlePaletteCommand(_ commandID: String) {
        CommandPaletteController.shared.close()

        switch commandID {
        case "new":
            createNewNote()

        case "search":
            searchFocused = true

        case "save":
            saveImmediately()

        case "delete":
            deleteCurrentNote()

        case "font":
            isFontSizePopoverPresented = false
            saveStatus = "Schriftart über das Menü ändern"

        case "filetype":
            saveStatus = "Dateityp über das Menü ändern"

        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
