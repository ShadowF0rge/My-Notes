
import SwiftUI
import AppKit

enum NoteFileType: String, CaseIterable, Identifiable {
    case txt, py, java, js, html, css, json, md

    var id: String { rawValue }

    var label: String {
        switch self {
        case .txt: "Text"
        case .py: "Python"
        case .java: "Java"
        case .js: "JavaScript"
        case .html: "HTML"
        case .css: "CSS"
        case .json: "JSON"
        case .md: "Markdown"
        }
    }

    var symbol: String {
        switch self {
        case .txt: "doc.text"
        case .py, .html: "chevron.left.forwardslash.chevron.right"
        case .java: "cup.and.saucer"
        case .js, .json: "curlybraces"
        case .css: "paintbrush"
        case .md: "text.alignleft"
        }
    }
}

enum NoteTheme {
    static let background = Color(red: 0.075, green: 0.07, blue: 0.08)
    static let sidebar = Color(red: 0.09, green: 0.085, blue: 0.095)
    static let surface = Color(red: 0.12, green: 0.11, blue: 0.12)
    static let accent = Color(red: 0.78, green: 0.38, blue: 0.42)
    static let selection = Color(red: 0.22, green: 0.105, blue: 0.12)
    static let primaryText = Color(red: 0.91, green: 0.89, blue: 0.91)
}

struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let shortcut: String
}

struct ContentView: View {
    let storage = NoteStorage.shared

    @State var title = ""
    @State var noteText = ""
    @State var fileType: NoteFileType = .txt
    @State var currentFileURL: URL?

    @State var saveStatus = "Bereit"
    @State var saveError: String?

    @State var fontSize: Double = 14
    @State var fontName = "Helvetica Neue"
    @State var isFontSizePopoverPresented = false

    @State var searchQuery = ""
    @State var notes: [URL] = []
    @State var folders: [URL] = []
    @State var autosaveTask: Task<Void, Never>?

    @State var isDirty = false
    @State var isLoadingNote = false

    // @FocusState ermöglicht das tatsächliche Fokussieren des Suchfeldes.
    @FocusState var searchFocused: Bool

    @State var tagText = ""
    @State var newTagText = ""
    @State var isTagEditorPresented = false

    @State var showingTrash = false
    @State var trashedNotes: [URL] = []
    @State var showingPermanentDeleteConfirmation = false
    @State var noteToDeletePermanently: URL?
    @State var showingRestoreError: String?

    @State var isSidebarVisible = true
    @State var selectedFolderPath: String?
    @State var showingOnlyUnfiled = false

    // Die aufgeklappten Ordner werden als Pfade gespeichert.
    @State var expandedFolderPaths: Set<String> = []

    private let expandedFoldersDefaultsKey =
        "MyNotes.expandedFolderPaths"

    let standardFonts = [
        "Helvetica Neue", "Arial", "Avenir Next",
        "Georgia", "Times New Roman"
    ]

    let codeFonts = [
        "SF Mono", "Menlo", "Monaco", "Courier New"
    ]

    var availableFonts: [String] {
        fileType == .txt || fileType == .md
            ? standardFonts
            : codeFonts
    }

    var displayedTags: [String] {
        tagText
            .split(separator: ",")
            .map {
                String($0).trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }

    var paletteCommands: [PaletteCommand] {
        [
            PaletteCommand(
                id: "new",
                title: "Neue Notiz",
                symbol: "plus",
                shortcut: "⌘ N"
            ),
            PaletteCommand(
                id: "newFolder",
                title: "Neuen Ordner erstellen",
                symbol: "folder.badge.plus",
                shortcut: ""
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
                shortcut: ""
            ),
            PaletteCommand(
                id: "pin",
                title: "Notiz anheften / lösen",
                symbol: "pin",
                shortcut: ""
            ),
            PaletteCommand(
                id: "exportMarkdown",
                title: "Als Markdown exportieren",
                symbol: "doc.text",
                shortcut: ""
            ),
            PaletteCommand(
                id: "exportText",
                title: "Als Text exportieren",
                symbol: "doc.plaintext",
                shortcut: ""
            ),
            PaletteCommand(
                id: "copy",
                title: "Text kopieren",
                symbol: "doc.on.doc",
                shortcut: ""
            ),
            PaletteCommand(
                id: "trash",
                title: "Papierkorb öffnen",
                symbol: "trash",
                shortcut: ""
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

    var wordCount: Int {
        NoteUtilities.wordCount(in: noteText)
    }

    var characterCount: Int {
        NoteUtilities.characterCount(in: noteText)
    }

    var currentNoteIsPinned: Bool {
        guard let currentFileURL else { return false }
        return storage.isPinned(currentFileURL)
    }

    var visibleNotes: [URL] {
        if !searchQuery.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            return notes
        }

        if showingOnlyUnfiled {
            return storage.listNotes(in: nil)
        }

        if let selectedFolderPath {
            return storage.listNotes(
                in: URL(fileURLWithPath: selectedFolderPath)
            )
        }

        return notes
    }

    // MARK: - Visible Folder Tree

    /// Liefert nur Ordner, deren Elternordner aufgeklappt sind.
    /// Die Reihenfolge bleibt hierarchisch und wird für die Einrückung
    /// der Sidebar verwendet.
    private var visibleFolders: [URL] {
        var result: [URL] = []

        func appendChildren(of parent: URL) {
            let parentPath = parent.standardizedFileURL.path

            let children = folders
                .filter {
                    $0.deletingLastPathComponent()
                        .standardizedFileURL.path == parentPath
                }
                .sorted {
                    $0.lastPathComponent.localizedStandardCompare(
                        $1.lastPathComponent
                    ) == .orderedAscending
                }

            for folder in children {
                result.append(folder)

                if expandedFolderPaths.contains(
                    folder.standardizedFileURL.path
                ) {
                    appendChildren(of: folder)
                }
            }
        }

        appendChildren(of: storage.notesDirectory)

        return result
    }

    private func folderDepth(_ folder: URL) -> Int {
        let rootPath = storage.notesDirectory.standardizedFileURL.path
        let folderPath = folder.standardizedFileURL.path

        let relativePath = String(
            folderPath.dropFirst(rootPath.count)
        )

        return max(
            0,
            relativePath.split(separator: "/").count - 1
        )
    }

    private func folderHasChildren(_ folder: URL) -> Bool {
        folders.contains {
            $0.deletingLastPathComponent()
                .standardizedFileURL.path
                == folder.standardizedFileURL.path
        }
    }

    private func toggleFolderExpansion(_ folder: URL) {
        let path = folder.standardizedFileURL.path

        if expandedFolderPaths.contains(path) {
            expandedFolderPaths.remove(path)
        } else {
            expandedFolderPaths.insert(path)
        }

        saveExpandedFolders()
    }

    private func loadExpandedFolders() {
        let savedPaths = UserDefaults.standard.stringArray(
            forKey: expandedFoldersDefaultsKey
        ) ?? []

        expandedFolderPaths = Set(savedPaths)
    }

    func saveExpandedFolders() {
        UserDefaults.standard.set(
            Array(expandedFolderPaths),
            forKey: expandedFoldersDefaultsKey
        )
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .transition(
                        .move(edge: .leading).combined(with: .opacity)
                    )
            }

            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 420)
        .background(NoteTheme.background)
        .preferredColorScheme(.dark)
        .animation(
            .easeInOut(duration: 0.18),
            value: isSidebarVisible
        )
        .onAppear {
            loadExpandedFolders()
            refreshAll()
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
        .onChange(of: tagText) {
            saveTags()
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
            isSidebarVisible = true

            // ⌘O öffnet die Sidebar und fokussiert die Suche.
            DispatchQueue.main.async {
                searchFocused = true
            }
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: .deleteSelectedItemRequested
            )
        ) { _ in
            if let selectedFolderPath {
                deleteFolder(
                    URL(fileURLWithPath: selectedFolderPath)
                )
            } else {
                deleteCurrentNote()
            }
        }
        .sheet(isPresented: $showingTrash) {
            trashSheet
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
            Text(
                saveError
                    ?? "Ein unbekannter Fehler ist aufgetreten."
            )
        }
        .alert(
            "Notiz endgültig löschen?",
            isPresented: $showingPermanentDeleteConfirmation
        ) {
            Button("Abbrechen", role: .cancel) {
                noteToDeletePermanently = nil
            }

            Button("Endgültig löschen", role: .destructive) {
                permanentlyDeleteSelectedNote()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .alert(
            "Aktion fehlgeschlagen",
            isPresented: Binding(
                get: { showingRestoreError != nil },
                set: { if !$0 { showingRestoreError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                showingRestoreError = nil
            }
        } message: {
            Text(showingRestoreError ?? "")
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

                Button(action: createNewFolder) {
                    Image(systemName: "folder.badge.plus")
                        .frame(width: 27, height: 27)
                }
                .buttonStyle(.plain)
                .help("Neuen Ordner erstellen")

                Button(action: createNewNote) {
                    Image(systemName: "plus")
                        .frame(width: 27, height: 27)
                        .background(NoteTheme.surface)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .help("Neue Notiz")
            }
            .padding(.horizontal, 13)
            .padding(.top, 15)
            .padding(.bottom, 13)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Notizen suchen", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
                    .onSubmit {
                        if let first = visibleNotes.first {
                            openNote(at: first)
                        }
                    }
            }
            .padding(9)
            .background(NoteTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    sectionLabel("BIBLIOTHEK")

                    navigationRow(
                        title: "Alle Notizen",
                        symbol: "tray.full",
                        selected: selectedFolderPath == nil
                            && !showingOnlyUnfiled
                    ) {
                        selectedFolderPath = nil
                        showingOnlyUnfiled = false
                    }
                    .dropDestination(for: String.self) { items, _ in
                        return moveDroppedNotes(items, to: nil)
                    }

                    navigationRow(
                        title: "Ohne Ordner",
                        symbol: "tray",
                        selected: showingOnlyUnfiled
                    ) {
                        showingOnlyUnfiled = true
                        selectedFolderPath = nil
                    }
                    .dropDestination(for: String.self) { items, _ in
                        return moveDroppedNotes(items, to: nil)
                    }

                    sectionLabel("ORDNER")
                        .padding(.top, 12)

                    ForEach(visibleFolders, id: \.path) { folder in
                        folderRow(folder)
                    }

                    sectionLabel(
                        searchQuery.isEmpty
                            ? "NOTIZEN"
                            : "SUCHERGEBNISSE"
                    )
                    .padding(.top, 12)

                    if visibleNotes.isEmpty {
                        Text(
                            searchQuery.isEmpty
                                ? "Keine Notizen"
                                : "Keine Ergebnisse"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(visibleNotes, id: \.path) { url in
                            noteRow(url)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            HStack {
                Text("\(notes.count) Notizen")

                Spacer()

                Button {
                    refreshTrash()
                    showingTrash = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Papierkorb öffnen")

                Text("⌘ K")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
        }
        .frame(width: 235)
        .background(NoteTheme.sidebar)
    }

    private func sectionLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 9)
            .padding(.top, 5)
            .padding(.bottom, 4)
    }

    private func navigationRow(
        title: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .frame(width: 17)
                    .foregroundStyle(
                        selected ? NoteTheme.accent : .secondary
                    )

                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(NoteTheme.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                selected ? NoteTheme.selection : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hierarchical Folder Row

    private func folderRow(_ folder: URL) -> some View {
        let path = folder.standardizedFileURL.path
        let selected = selectedFolderPath == path
        let hasChildren = folderHasChildren(folder)
        let isExpanded = expandedFolderPaths.contains(path)
        let indentation = CGFloat(folderDepth(folder)) * 14

        return HStack(spacing: 2) {
            // Der Pfeil ändert ausschließlich den Aufklappzustand.
            Button {
                toggleFolderExpansion(folder)
            } label: {
                Image(
                    systemName: hasChildren
                        ? (isExpanded ? "chevron.down" : "chevron.right")
                        : "chevron.right"
                )
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    hasChildren ? Color.secondary : Color.clear
                )
                .frame(width: 18, height: 29)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)
            .help(
                hasChildren
                    ? (isExpanded ? "Ordner zuklappen" : "Ordner aufklappen")
                    : "Keine Unterordner"
            )

            // Der Ordnername wählt den Ordner aus.
            Button {
                selectedFolderPath = path
                showingOnlyUnfiled = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            selected ? NoteTheme.accent : .secondary
                        )
                        .frame(width: 15)

                    Text(folder.lastPathComponent)
                        .font(.system(size: 12))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(NoteTheme.primaryText)
                .padding(.vertical, 7)
                .padding(.trailing, 7)
                .background(
                    selected ? NoteTheme.selection : .clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, indentation)
        .background(
            selected ? NoteTheme.selection : .clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .draggable(folder.path)
        .dropDestination(for: String.self) { items, _ in
            return moveDroppedNotes(items, to: folder)
        }
        .contextMenu {
            Button("Ordner öffnen") {
                selectedFolderPath = path
                showingOnlyUnfiled = false
            }

            Button(
                isExpanded
                    ? "Ordner zuklappen"
                    : "Ordner aufklappen"
            ) {
                toggleFolderExpansion(folder)
            }
            .disabled(!hasChildren)

            Button("Neuen Unterordner erstellen") {
                selectedFolderPath = path
                showingOnlyUnfiled = false
                createNewFolder()
            }

            Button("Umbenennen") {
                renameFolder(folder)
            }

            Button(role: .destructive) {
                deleteFolder(folder)
            } label: {
                Label("Ordner löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Note Row

    private func noteRow(_ url: URL) -> some View {
        let selected =
            currentFileURL?.standardizedFileURL
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
                    HStack(spacing: 4) {
                        if storage.isPinned(url) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(NoteTheme.accent)
                        }

                        Text(
                            url.deletingPathExtension().lastPathComponent
                        )
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundStyle(NoteTheme.primaryText)
                    }

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
                selected ? NoteTheme.selection : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(url.path)
        .contextMenu {
            Button {
                openNote(at: url)
            } label: {
                Label("Öffnen", systemImage: "doc.text")
            }

            Button {
                togglePin(url)
            } label: {
                Label(
                    storage.isPinned(url)
                        ? "Anheftung lösen"
                        : "Anheften",
                    systemImage: "pin"
                )
            }

            Menu("Exportieren") {
                Button("Als Markdown exportieren") {
                    NoteUtilities.exportMarkdown(
                        text: (try? storage.load(from: url)) ?? "",
                        title: url.deletingPathExtension().lastPathComponent
                    )
                }

                Button("Als Text exportieren") {
                    NoteUtilities.exportText(
                        text: (try? storage.load(from: url)) ?? "",
                        title: url.deletingPathExtension().lastPathComponent
                    )
                }
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
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(NoteTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help(
                    isSidebarVisible
                        ? "Sidebar ausblenden"
                        : "Sidebar einblenden"
                )

                TextField("Titel der Notiz", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NoteTheme.primaryText)

                Spacer()

                Button(action: toggleCurrentPin) {
                    Image(
                        systemName: currentNoteIsPinned
                            ? "pin.fill"
                            : "pin"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(
                        currentNoteIsPinned
                            ? NoteTheme.accent
                            : .secondary
                    )
                    .frame(width: 30, height: 30)
                    .background(NoteTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .disabled(currentFileURL == nil)
                .help("Notiz anheften")

                Menu {
                    Section("Schriftart") {
                        ForEach(availableFonts, id: \.self) { font in
                            Button {
                                fontName = font
                            } label: {
                                if fontName == font {
                                    Label(
                                        font,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(font)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 30, height: 30)
                        .background(NoteTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)

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
                    isPresented: $isFontSizePopoverPresented
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schriftgröße")
                            .font(.system(size: 13, weight: .semibold))

                        Slider(value: $fontSize, in: 10...32, step: 1)

                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(width: 220)
                }

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
                        Text(typeLabel)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(NoteTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    ForEach(displayedTags, id: \.self) { tag in
                        HStack(spacing: 5) {
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(NoteTheme.accent)

                            Button {
                                removeTag(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(
                                        .system(size: 8, weight: .bold)
                                    )
                                    .foregroundStyle(
                                        NoteTheme.accent.opacity(0.8)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("Tag entfernen")
                            .disabled(currentFileURL == nil)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(NoteTheme.selection)
                        .clipShape(Capsule())
                    }

                    tagAddButton

                    Spacer(minLength: 0)
                }

                if let currentFileURL {
                    Text(
                        "Zuletzt geöffnet: \(NoteFeatures.formattedDate(storage.lastOpenedDate(for: currentFileURL)))"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 9)

            TextEditor(text: $noteText)
                .font(.custom(fontName, size: fontSize))
                .scrollContentBackground(.hidden)
                .foregroundStyle(NoteTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                Circle()
                    .fill(
                        isDirty
                            ? NoteTheme.accent
                            : Color.green.opacity(0.7)
                    )
                    .frame(width: 6, height: 6)

                Text(saveStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(wordCount) Wörter · \(characterCount) Zeichen")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help(NoteUtilities.readingTime(in: noteText))

                Button(action: togglePalette) {
                    HStack(spacing: 5) {
                        Image(systemName: "command")
                        Text("Aktionen")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Aktionsliste öffnen (⌘ K)")

                Button(action: saveImmediately) {
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

    private var typeLabel: String {
        fileType.rawValue.uppercased()
    }

    // MARK: - Tag Add Button

    private var tagAddButton: some View {
        Button {
            newTagText = ""
            isTagEditorPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(NoteTheme.surface)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(currentFileURL == nil)
        .help("Tag hinzufügen")
        .popover(
            isPresented: $isTagEditorPresented,
            arrowEdge: .bottom
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tag hinzufügen")
                    .font(.system(size: 12, weight: .semibold))

                TextField("Name des Tags", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit {
                        addTag()
                    }

                HStack {
                    Spacer()

                    Button("Abbrechen") {
                        isTagEditorPresented = false
                    }
                    .buttonStyle(.plain)

                    Button("Hinzufügen") {
                        addTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NoteTheme.accent)
                    .disabled(
                        newTagText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
                .font(.system(size: 11))
            }
            .padding(14)
            .frame(width: 250)
        }
    }
}

#Preview {
    ContentView()
}
