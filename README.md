# My Notes

A lightweight, native macOS notes application built with Swift and SwiftUI.

My Notes provides a compact, Raycast-inspired interface for creating, organizing, searching, and editing notes and source-code files. It features a searchable sidebar, folder organization, keyboard shortcuts, and local file-based storage.

## Features

- Create, open, edit, and search notes.
- Automatically save changes.
- Organize notes into folders and nested subfolders.
- Expand and collapse folder trees.
- Use a command palette for quick access to actions.
- Edit plain-text documents and source-code files.
- Customize editor fonts and font sizes.
- Access additional note-management features, depending on the current implementation.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘K` | Open the command palette |
| `⌘O` | Intended to open or focus search; verify in the current build |

## Supported File Types

The application is designed to support text-based files, including:

- Plain text (`.txt`)
- Markdown (`.md`)
- Python (`.py`)
- Java (`.java`)
- JavaScript (`.js`)
- HTML (`.html`)
- CSS (`.css`)
- JSON (`.json`)

Supported formats depend on the application's current file-type configuration. Syntax highlighting and advanced code-editing features are not guaranteed.

## Note Storage

Notes are stored as files on the local filesystem using native macOS file-management APIs.

The application is designed to use a directory inside:

`~/Library/Application Support/`

The exact storage location depends on the implementation in `NoteStorage.swift`.

Back up important notes before modifying storage-related code or moving stored files manually.

## Installation

### Requirements

- A Mac running a supported version of macOS.
- Xcode compatible with the project.
- The My Notes source code.

### Run from Xcode

1. Open the `.xcodeproj` file in Xcode.
2. Select the `My-Notes` scheme.
3. Choose `My Mac` as the run destination.
4. Press `⌘B` to build the application.
5. Press `⌘R` to run it.

### Install the application

1. Build the project in Xcode using `Product → Build`.
2. Locate `My-Notes.app` in the build products.
3. Copy the application into `/Applications`.
4. Open My Notes from the Applications folder.

To add the application to the Dock, right-click its Dock icon and select `Options → Keep in Dock`.

## Building from Source

Open the project in Xcode and use the following shortcuts:

| Shortcut | Action |
|---|---|
| `⌘B` | Build the application |
| `⌘R` | Run the application |
| `⇧⌘K` | Clean the build folder |

These are Xcode shortcuts, not application shortcuts.

## Project Structure

| File | Responsibility |
|---|---|
| `MyApp.swift` | Application entry point and configuration |
| `ContentView.swift` | Main interface and editor |
| `NoteStorage.swift` | Note storage and filesystem operations |
| `NoteFolderFeatures.swift` | Folder-related functionality |
| `NoteFeatures.swift` | Additional note functionality |
| `NoteUtilities.swift` | Shared utility functions |
| `CommandPalette.swift` | Command palette implementation |
| `Assets.xcassets` | Application assets and icons |

Exact responsibilities may change as the project evolves.

## Technology Stack

- **Swift** — primary programming language.
- **SwiftUI** — user interface and reactive view updates.
- **AppKit** — native macOS integration.
- **Foundation** — core application functionality and file operations.
- **FileManager** — filesystem access and management.
- **Xcode** — development, building, and debugging.

## Troubleshooting

### The application builds but does not appear in Applications

Locate `My-Notes.app` in Xcode's build products and copy it into `/Applications`.

### The application displays an old icon

Make sure you are opening the latest build. Replace the existing application and verify the target's icon configuration and asset catalog.

### Build errors occur

Use `Product → Clean Build Folder` (`⇧⌘K`) and build again. If the problem persists, inspect the compiler errors and asset catalog configuration.

## License

My Notes is licensed under the MIT License.

Copyright (c) 2026 My Notes contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Status
My Notes is a native macOS application that is no longer under active development. Development may resume in the future. 

The current source code and the latest successfully built application are the authoritative references for implemented functionality.
