
import SwiftUI
import AppKit

final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PaletteKeyView: NSView {
    var onEscape: (() -> Void)?
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onEnter: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            onEscape?()
        case 126:
            onUp?()
        case 125:
            onDown?()
        case 36, 76:
            onEnter?()
        default:
            super.keyDown(with: event)
        }
    }
}

struct PaletteKeyHandler: NSViewRepresentable {
    let onEscape: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void

    func makeNSView(context: Context) -> PaletteKeyView {
        let view = PaletteKeyView()
        view.onEscape = onEscape
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(
        _ view: PaletteKeyView,
        context: Context
    ) {
        view.onEscape = onEscape
        view.onUp = onUp
        view.onDown = onDown
        view.onEnter = onEnter
    }
}

@MainActor
final class CommandPaletteController {
    static let shared = CommandPaletteController()

    private var panel: PalettePanel?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(
        relativeTo mainWindow: NSWindow?,
        commands: [PaletteCommand],
        onAction: @escaping (String) -> Void
    ) {
        let newPanel = panel ?? makePanel()
        panel = newPanel

        newPanel.contentView = NSHostingView(
            rootView: CommandPaletteView(
                commands: commands,
                onAction: onAction,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )

        if let mainWindow {
            let frame = mainWindow.frame
            let paletteFrame = newPanel.frame

            newPanel.setFrameOrigin(
                NSPoint(
                    x: frame.midX - paletteFrame.width / 2,
                    y: frame.midY - paletteFrame.height / 2
                )
            )
        } else {
            newPanel.center()
        }

        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> PalettePanel {
        let panel = PalettePanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 430,
                height: 390
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Aktionen"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = NSColor(
            calibratedRed: 0.09,
            green: 0.08,
            blue: 0.09,
            alpha: 1
        )
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        return panel
    }
}

struct CommandPaletteView: View {
    @State private var query = ""
    @State private var selectedIndex = 0

    let commands: [PaletteCommand]
    let onAction: (String) -> Void
    let onClose: () -> Void

    private var filteredCommands: [PaletteCommand] {
        guard !query.isEmpty else {
            return commands
        }

        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Aktion suchen …", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit(runSelected)
            }
            .font(.system(size: 13))
            .padding(14)

            Divider()
                .overlay(Color.white.opacity(0.04))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(
                            Array(filteredCommands.enumerated()),
                            id: \.element.id
                        ) { index, command in
                            Button {
                                onAction(command.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: command.symbol)
                                        .frame(width: 18)
                                        .foregroundStyle(
                                            index == selectedIndex
                                            ? Color(
                                                red: 0.82,
                                                green: 0.43,
                                                blue: 0.46
                                            )
                                            : Color.secondary
                                        )

                                    Text(command.title)
                                        .lineLimit(1)

                                    Spacer()

                                    if !command.shortcut.isEmpty {
                                        Text(command.shortcut)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .font(.system(size: 12))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .background(
                                    index == selectedIndex
                                    ? Color(
                                        red: 0.25,
                                        green: 0.105,
                                        blue: 0.12
                                    )
                                    : Color.clear
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 6)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedIndex) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
                .onChange(of: query) {
                    selectedIndex = 0
                    proxy.scrollTo(0, anchor: .top)
                }
                .onChange(of: filteredCommands.count) {
                    selectedIndex = 0
                    proxy.scrollTo(0, anchor: .top)
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.04))

            HStack {
                Text("↑↓ Auswahl")
                Spacer()
                Text("↵ Ausführen")
                Spacer()
                Text("esc Schließen")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(12)
        }
        .background(
            Color(red: 0.09, green: 0.08, blue: 0.09)
        )
        .foregroundStyle(
            Color(red: 0.9, green: 0.88, blue: 0.9)
        )
        .background {
            PaletteKeyHandler(
                onEscape: onClose,
                onUp: moveUp,
                onDown: moveDown,
                onEnter: runSelected
            )
            .frame(width: 0, height: 0)
        }
    }

    private func moveUp() {
        guard !filteredCommands.isEmpty else {
            return
        }

        selectedIndex = max(selectedIndex - 1, 0)
    }

    private func moveDown() {
        guard !filteredCommands.isEmpty else {
            return
        }

        selectedIndex = min(
            selectedIndex + 1,
            filteredCommands.count - 1
        )
    }

    private func runSelected() {
        guard filteredCommands.indices.contains(selectedIndex) else {
            return
        }

        onAction(filteredCommands[selectedIndex].id)
    }
}
