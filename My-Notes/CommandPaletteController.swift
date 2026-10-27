
import SwiftUI
import AppKit

final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
            let mainFrame = mainWindow.frame
            let panelFrame = newPanel.frame

            newPanel.setFrameOrigin(
                NSPoint(
                    x: mainFrame.midX - panelFrame.width / 2,
                    y: mainFrame.midY - panelFrame.height / 2
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
                x: 0, y: 0, width: 430, height: 390
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
    @FocusState private var searchIsFocused: Bool
    
    let commands: [PaletteCommand]
    let onAction: (String) -> Void
    let onClose: () -> Void

    private var filteredCommands: [PaletteCommand] {
        guard !query.isEmpty else { return commands }

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
                    .focused($searchIsFocused)
                    .onSubmit(runSelected)
            }
            .font(.system(size: 13))
            .padding(14)

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    index == selectedIndex
                                        ? Color(
                                            red: 0.25,
                                            green: 0.105,
                                            blue: 0.12
                                        )
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                }
                .onMoveCommand { direction in
                    guard !filteredCommands.isEmpty else { return }

                    switch direction {
                    case .down:
                        selectedIndex = min(
                            selectedIndex + 1,
                            filteredCommands.count - 1
                        )
                    case .up:
                        selectedIndex = max(selectedIndex - 1, 0)
                    default:
                        break
                    }

                    withAnimation(.easeOut(duration: 0.08)) {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
                .onChange(of: query) {
                    selectedIndex = 0
                }
            }

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
            Color(
                red: 0.09,
                green: 0.08,
                blue: 0.09
            )
        )
        .foregroundStyle(
            Color(red: 0.9, green: 0.88, blue: 0.9)
        )
        .onAppear {
            searchIsFocused = true
        }
        .onExitCommand {
            onClose()
        }
    }

    private func runSelected() {
        guard filteredCommands.indices.contains(selectedIndex) else {
            return
        }

        onAction(filteredCommands[selectedIndex].id)
    }
}
