
import Foundation
import AppKit
import UniformTypeIdentifiers

enum NoteUtilities {

    // MARK: - Text Statistics

    static func wordCount(in text: String) -> Int {
        text.split {
            $0.isWhitespace || $0.isNewline
        }.count
    }

    static func characterCount(in text: String) -> Int {
        text.count
    }

    static func characterCountWithoutSpaces(in text: String) -> Int {
        text.filter {
            !$0.isWhitespace && !$0.isNewline
        }.count
    }

    static func readingTime(in text: String) -> String {
        let words = wordCount(in: text)
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))

        return "\(minutes) Min. Lesezeit"
    }

    // MARK: - Markdown Export

    static func exportMarkdown(
        text: String,
        title: String,
        suggestedFilename: String? = nil
    ) {
        let panel = NSSavePanel()

        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        panel.nameFieldStringValue =
            suggestedFilename
            ?? "\(trimmedTitle.isEmpty ? "Unbenannte Notiz" : trimmedTitle).md"

        guard panel.runModal() == .OK,
              let destinationURL = panel.url else {
            return
        }

        do {
            try Data(text.utf8).write(
                to: destinationURL,
                options: .atomic
            )
        } catch {
            showError(
                title: "Export fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Plain Text Export

    static func exportText(
        text: String,
        title: String
    ) {
        let panel = NSSavePanel()

        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        let trimmedTitle = title.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        panel.nameFieldStringValue =
            "\(trimmedTitle.isEmpty ? "Unbenannte Notiz" : trimmedTitle).txt"

        guard panel.runModal() == .OK,
              let destinationURL = panel.url else {
            return
        }

        do {
            try Data(text.utf8).write(
                to: destinationURL,
                options: .atomic
            )
        } catch {
            showError(
                title: "Export fehlgeschlagen",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Clipboard

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            text,
            forType: .string
        )
    }

    // MARK: - Error Dialog

    private static func showError(
        title: String,
        message: String
    ) {
        let alert = NSAlert()

        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning

        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
