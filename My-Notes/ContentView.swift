
import SwiftUI
import AppKit

private enum NoteFileType: String, CaseIterable, Identifiable {
    case txt, py, java, js, html, css, json, md

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
}

private enum NoteTheme {
    static let background = Color(red: 0.075, green: 0.072, blue: 0.078)
    static let sidebar = Color(red: 0.095, green: 0.088, blue: 0.095)
    static let editor = Color(red: 0.085, green: 0.078, blue: 0.085)
    static let selected = Color(red: 0.25, green: 0.105, blue: 0.12)
    static let accent = Color(red: 0.72, green: 0.34, blue: 0.38)
    static let secondary = Color(red: 0.58, green: 0.56, blue: 0.59)
    static let text = Color(red: 0.89, green: 0.87, blue: 0.89)
}

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let shortcut: String
}

struct ContentView: View {
    @State private var title = ""
    @State private var noteText = ""
    @State private var fileType: NoteFileType = .txt

    @State private var currentFileURL: URL?
    @State private var saveStatus = "Bereit"
    @State private var saveError: String?

    @State private var fontSize = 14.0
    @State private var fontName = "Helvetica Neue"
    @State private var isFontSizePopoverPresented = false

    @State private var searchQuery = ""
    @State private var notes: [URL] = []
    @State private var autosaveTask: Task<Void, Never>?

    @State private var isDirty = false
    @State private var isLoadingNote = false
    @State private var searchFocused = false

    private let storage = NoteStorage.shared
    private let palette = CommandPaletteController.shared

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
                symbol: "checkmark",
                shortcut: "⌘ S"
            ),
            PaletteCommand(
                id: "font",
                title: "Schriftgröße ändern",
                symbol: "textformat.size",
                shortcut: ""
            ),
            PaletteCommand(
                id: "filetype",
                title: "Dateityp ändern",
                symbol: "doc.text",
                shortcut: ""
            )
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            editor
        }
        .frame(minWidth: 760, minHeight: 480)
        .background(NoteTheme.background)
        .foregroundStyle(NoteTheme.text)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshNotes()
        }
        .onChange(of: noteText) {
            if !isLoadingNote {
                markChanged()
            }
        }
        .onChange(of: title) {
            if !isLoadingNote {
                markChanged()
            }
        }
        .onChange(of: searchQuery) {
            refreshNotes()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .newNoteRequested)
        ) { _ in
            createNewNote()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .openNoteRequested)
        ) { _ in
            searchFocused = true
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .saveNoteRequested)
        ) { _ in
            saveImmediately()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .togglePaletteRequested)
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
            Text(saveError ?? "Unbekannter Fehler")
        }
        .onDisappear {
            autosaveTask?.cancel()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(NoteTheme.accent)

                Text("NOTIZEN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.3)

                Spacer()

                Button {
                    createNewNote()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(NoteTheme.secondary)
                .help("Neue Notiz")
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(NoteTheme.secondary)

                TextField("Notiz suchen", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(9)
            .background(NoteTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(notes, id: \.path) { url in
                        noteRow(url)
                    }
                }
                .padding(.horizontal, 7)
            }

            Spacer(minLength: 0)

            Text("\(notes.count) Notizen")
                .font(.system(size: 10))
                .foregroundStyle(NoteTheme.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(width: 205)
        .background(NoteTheme.sidebar)
    }

    private func noteRow(_ url: URL) -> some View {
        let isSelected = currentFileURL?.standardizedFileURL
            == url.standardizedFileURL

        return Button {
            openNote(at: url)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: iconFor(url))
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isSelected ? NoteTheme.accent : NoteTheme.secondary
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(NoteTheme.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? NoteTheme.selected : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconFor(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "py", "java", "js":
            return "chevron.left.forwardslash.chevron.right"
        case "html", "css", "json":
            return "curlybraces"
        case "md":
            return "text.alignleft"
        default:
            return "doc.text"
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TextField("Titel der Notiz", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NoteTheme.text)

                Spacer()

                Menu {
                    Section("Standardschriftarten") {
                        ForEach(standardFonts, id: \.self) { font in
                            fontOption(font)
                        }
                    }

                    Section("Monospace und Code") {
                        ForEach(codeFonts, id: \.self) { font in
                            fontOption(font)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "textformat")
                        Text(fontName)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(NoteTheme.secondary)
                }
                .menuStyle(.borderlessButton)

                Button {
                    isFontSizePopoverPresented.toggle()
                } label: {
                    Image(systemName: "textformat.size")
                        .foregroundStyle(NoteTheme.secondary)
                }
                .buttonStyle(.plain)
                .help("Schriftgröße ändern")
                .popover(isPresented: $isFontSizePopoverPresented) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schriftgröße")
                            .font(.system(size: 13, weight: .semibold))

                        Slider(
                            value: $fontSize,
                            in: 10...32,
                            step: 1
                        )

                        HStack {
                            Text("10 pt")
                                .foregroundStyle(NoteTheme.secondary)

                            Spacer()

                            Text("\(Int(fontSize)) pt")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NoteTheme.accent)

                            Spacer()

                            Text("32 pt")
                                .foregroundStyle(NoteTheme.secondary)
                        }
                        .font(.system(size: 10))
                    }
                    .padding(16)
                    .frame(width: 240)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            TextEditor(text: $noteText)
                .font(.custom(fontName, size: fontSize))
                .foregroundStyle(NoteTheme.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 17)
                .padding(.bottom, 8)
                .background(NoteTheme.editor)

            HStack(spacing: 12) {
                Text("\(noteText.count) Zeichen")
                    .foregroundStyle(NoteTheme.secondary)

                Text("·")
                    .foregroundStyle(NoteTheme.secondary)

                Text(saveStatus)
                    .foregroundStyle(
                        isDirty ? NoteTheme.accent : NoteTheme.secondary
                    )
                    .lineLimit(1)

                Spacer()

                Button {
                    saveImmediately()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NoteTheme.text)
                        .padding(7)
                        .background(NoteTheme.selected)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Speichern (⌘S)")

                Button {
                    togglePalette()
                } label: {
                    Image(systemName: "command")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NoteTheme.text)
                        .padding(7)
                        .background(NoteTheme.selected)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Aktionen (⌘K)")
            }
            .font(.system(size: 10))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(NoteTheme.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoteTheme.editor)
    }

    private func fontOption(_ font: String) -> some View {
        Button {
            fontName = font
        } label: {
            HStack {
                Text(font)

                if fontName == font {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // MARK: - Autosave

    private func markChanged() {
        guard !isLoadingNote else { return }

        isDirty = true
        saveStatus = "Ungespeicherte Änderungen"
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        autosaveTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            if !title.isEmpty || !noteText.isEmpty {
                saveImmediately()
            }
        }
    }

    // MARK: - Save

    private func saveImmediately() {
        autosaveTask?.cancel()

        let safeTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !safeTitle.isEmpty || !noteText.isEmpty else {
            saveStatus = "Bereit"
            isDirty = false
            return
        }

        do {
            let destination: URL

            if let currentURL = currentFileURL {
                let oldTitle = currentURL
                    .deletingPathExtension()
                    .lastPathComponent

                if !safeTitle.isEmpty && safeTitle != oldTitle {
                    let newURL = currentURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(safeTitle)
                        .appendingPathExtension(currentURL.pathExtension)

                    if newURL.standardizedFileURL
                        != currentURL.standardizedFileURL {
                        guard !FileManager.default.fileExists(
                            atPath: newURL.path
                        ) else {
                            saveError = "Eine Notiz mit diesem Titel existiert bereits."
                            return
                        }

                        try FileManager.default.moveItem(
                            at: currentURL,
                            to: newURL
                        )
                    }

                    destination = newURL
                } else {
                    destination = currentURL
                }
            } else {
                destination = try storage.createNote(
                    title: safeTitle.isEmpty
                        ? "Unbenannte Notiz"
                        : safeTitle,
                    fileType: fileType.rawValue
                )
            }

            try storage.save(text: noteText, to: destination)

            currentFileURL = destination
            title = destination.deletingPathExtension().lastPathComponent
            isDirty = false
            saveStatus = "Gespeichert"
            refreshNotes()
        } catch {
            saveStatus = "Speichern fehlgeschlagen"
            saveError = error.localizedDescription
        }
    }

    // MARK: - Internal notes

    private func refreshNotes() {
        notes = storage.searchNotes(query: searchQuery)
    }

    private func openNote(at url: URL) {
        if currentFileURL?.standardizedFileURL == url.standardizedFileURL {
            return
        }

        if isDirty || ((!title.isEmpty || !noteText.isEmpty)
            && currentFileURL == nil) {
            saveImmediately()

            if isDirty {
                return
            }
        }

        autosaveTask?.cancel()

        do {
            let loadedText = try storage.load(from: url)

            isLoadingNote = true
            currentFileURL = url
            title = url.deletingPathExtension().lastPathComponent
            noteText = loadedText

            if let matchingType = NoteFileType.allCases.first(
                where: {
                    $0.rawValue == url.pathExtension.lowercased()
                }
            ) {
                fileType = matchingType
            }

            isDirty = false
            saveStatus = "Gespeichert"
            searchFocused = false

            DispatchQueue.main.async {
                isLoadingNote = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func createNewNote() {
        if isDirty || ((!title.isEmpty || !noteText.isEmpty)
            && currentFileURL == nil) {
            saveImmediately()

            if isDirty {
                return
            }
        }

        autosaveTask?.cancel()
        isLoadingNote = true

        title = ""
        noteText = ""
        fileType = .txt
        currentFileURL = nil
        isDirty = false
        saveStatus = "Neue Notiz"

        DispatchQueue.main.async {
            isLoadingNote = false
        }
    }

    // MARK: - Command palette

    private func togglePalette() {
        if palette.isVisible {
            palette.close()
        } else {
            palette.show(
                relativeTo: NSApp.keyWindow ?? NSApp.mainWindow,
                commands: paletteCommands
            ) { command in
                handlePaletteCommand(command)
            }
        }
    }

    private func handlePaletteCommand(_ command: String) {
        palette.close()

        switch command {
        case "new":
            createNewNote()

        case "search":
            searchFocused = true

        case "save":
            saveImmediately()

        case "font":
            isFontSizePopoverPresented = true

        case "filetype":
            showFileTypePalette()

        default:
            break
        }
    }

    private func showFileTypePalette() {
        let typeCommands = NoteFileType.allCases.map { type in
            PaletteCommand(
                id: "choose_type_\(type.rawValue)",
                title: "\(type.label) (.\(type.rawValue))",
                symbol: "doc.text",
                shortcut: ""
            )
        }

        palette.show(
            relativeTo: NSApp.keyWindow ?? NSApp.mainWindow,
            commands: typeCommands
        ) { command in
            guard command.hasPrefix("choose_type_") else {
                return
            }

            let rawType = String(
                command.dropFirst("choose_type_".count)
            )

            guard let type = NoteFileType(rawValue: rawType) else {
                return
            }

            changeFileType(to: type)
        }
    }

    private func changeFileType(to type: NoteFileType) {
        guard type != fileType else {
            palette.close()
            return
        }

        autosaveTask?.cancel()

        do {
            if let currentURL = currentFileURL {
                let newURL = currentURL
                    .deletingPathExtension()
                    .appendingPathExtension(type.rawValue)

                if newURL.standardizedFileURL != currentURL.standardizedFileURL {
                    guard !FileManager.default.fileExists(
                        atPath: newURL.path
                    ) else {
                        palette.close()
                        saveError = "Eine Datei mit diesem Dateityp existiert bereits."
                        return
                    }

                    try FileManager.default.moveItem(
                        at: currentURL,
                        to: newURL
                    )
                }

                currentFileURL = newURL
                fileType = type

                try storage.save(text: noteText, to: newURL)

                isDirty = false
                saveStatus = "Gespeichert"
                refreshNotes()
            } else {
                fileType = type
                markChanged()
            }

            palette.close()
        } catch {
            palette.close()
            saveError = error.localizedDescription
            saveStatus = "Änderung fehlgeschlagen"
        }
    }
}

#Preview {
    ContentView()
}
