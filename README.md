# My Notes

A lightweight, native macOS notes application built with Swift and SwiftUI.

My Notes is a minimal note-taking application designed for macOS. It combines a compact, Raycast-inspired interface with file-based note storage, a searchable sidebar, folder organization, and a built-in editor for text and source code.

The goal is to provide a fast, distraction-free environment for capturing ideas, organizing notes, and editing code without the overhead of a large productivity application.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Design and User Interface](#design-and-user-interface)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Supported File Types](#supported-file-types)
- [Note Storage](#note-storage)
- [Folder Management](#folder-management)
- [Installation](#installation)
- [Building from Source](#building-from-source)
- [Project Structure](#project-structure)
- [Technology Stack](#technology-stack)
- [Configuration and App Icon](#configuration-and-app-icon)
- [Troubleshooting](#troubleshooting)
- [Development Guidelines](#development-guidelines)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

**My Notes** is a native macOS application for managing notes and lightweight code documents.

The application is built with Apple's SwiftUI framework and uses AppKit where native macOS functionality is needed.

### Main goals

- Keep the interface compact and visually unobtrusive.
- Make notes accessible through search and keyboard shortcuts.
- Organize notes in folders.
- Save changes automatically.
- Support multiple text-based file formats.
- Provide a simple editing experience for notes and code.
- Integrate naturally with macOS.

### Project information

| Property | Value |
|---|---|
| Application name | My Notes |
| Platform | macOS |
| Programming language | Swift |
| User interface | SwiftUI |
| Native macOS integration | AppKit |
| File operations | Foundation and FileManager |
| Development environment | Xcode |
| Project type | Native macOS application |

---

## Features

### 1. Note Management

My Notes provides basic note management functionality.

- Create new notes.
- Open existing notes.
- Search for notes.
- Edit note contents.
- Save changes automatically.
- Work with different text-based file formats.
- Use a dedicated editor for the selected note.

The editor is designed to keep the selected note at the center of the workflow.

### 2. Search

The sidebar includes a search field for finding notes.

Search is intended to make it possible to locate notes without navigating through every folder manually.

The application also uses keyboard focus management so that the search field can receive focus programmatically.

**Keyboard-first workflow:** The intended `⌘O` behavior is to open or focus the search field. Verify that this shortcut is connected in the current build.

### 3. Command Palette

My Notes includes a command palette designed around the `⌘K` keyboard shortcut.

The palette provides access to application actions without requiring navigation through menus.

Known command categories include:

- Creating notes.
- Saving notes.
- Changing the file type.

The command palette is intended to make common actions accessible through the keyboard.

### 4. Folder Organization

Notes can be organized into folders and nested subfolders.

Folder functionality includes:

- Creating folders.
- Creating subfolders.
- Selecting folders.
- Expanding and collapsing folder trees.
- Renaming folders.
- Deleting folders.
- Accessing folder actions through a context menu.

Expanded folder states can be stored in application preferences so the sidebar can preserve its organization between launches.

### 5. Editing and Appearance

The editor supports configurable typography.

Known editor options include:

- Font selection.
- Adjustable font size.
- Editing text and source code.
- Selecting a file type for the current document.

The interface follows a compact, dark, Raycast-inspired visual direction.

### 6. Note Organization and Additional Actions

The project also contains functionality for note organization and related workflows, including tags, pinning, exporting, and trash or restore operations.

The availability and exact behavior of each action should be verified against the current build before treating it as a guaranteed feature.

---

## Design and User Interface

My Notes follows a minimal macOS design philosophy.

### Design principles

- **Compact:** Avoid unnecessary screen space and visual clutter.
- **Keyboard-first:** Make frequent operations accessible through shortcuts.
- **Native:** Use SwiftUI and AppKit rather than building a web-based interface.
- **Distraction-free:** Keep the focus on the current note.
- **Consistent:** Use a restrained dark appearance with subtle red accents.

### Interface components

The main interface is organized around:

1. **Sidebar** — search, folder navigation, and note selection.
2. **Note list** — access to notes in the current view.
3. **Editor** — view and modify the selected note.
4. **Status area** — contextual information about the current editing state.

The exact layout and visible controls depend on the current implementation.

---

## Keyboard Shortcuts

The following table documents the intended and known keyboard workflow. Shortcuts should be checked in the current build because availability depends on the command and menu configuration.

| Shortcut | Action |
|---|---|
| `⌘K` | Open the command palette |
| `⌘O` | Intended: open or focus the search field |
| `⌘B` | Build the application in Xcode |
| `⌘R` | Run the application in Xcode |
| `⇧⌘K` | Clean the build folder in Xcode |

The last three shortcuts are Xcode shortcuts, not application shortcuts.

Additional application shortcuts can be documented here when they are implemented and tested.

---

## Supported File Types

My Notes is designed to handle plain-text notes and source-code documents.

The known file types include:

| Type | Typical extension |
|---|---|
| Plain text | `.txt` |
| Python | `.py` |
| Java | `.java` |
| JavaScript | `.js` |
| HTML | `.html` |
| CSS | `.css` |
| JSON | `.json` |
| Markdown | `.md` |

The exact extension mapping is determined by the application's file-type configuration.

These formats are text-based. Support for opening a file does not automatically imply syntax highlighting, code completion, or other advanced editor features.

---

## Note Storage

Notes are stored as files on the local filesystem rather than exclusively inside a database.

The application uses native file-management APIs to read and write notes.

### Storage location

The application is designed to store its notes in the user's macOS Application Support directory.

A typical location for an app-specific directory is:

`~/Library/Application Support/`

The precise subdirectory is determined by the storage implementation in `NoteStorage.swift`.

### Why file-based storage?

File-based storage provides several advantages:

- Notes remain ordinary files.
- Text documents can be accessed using other applications.
- The storage implementation can use native macOS filesystem operations.
- Different file extensions can represent different document types.

### Important considerations

- Do not manually move or rename stored notes while the application is editing them.
- Back up important notes before making changes to the storage implementation.
- The exact behavior when a note is externally modified depends on the current implementation.
- The persistence of folders, tags, pinned notes, and trash contents depends on how each feature is implemented.

---

## Folder Management

The folder system uses folder URLs and filesystem paths to identify folders.

The interface maintains a collection of folders and determines which folders are visible based on the expanded state of their parent folders.

### Expanded folder persistence

The application uses a preference key named:

`MyNotes.expandedFolderPaths`

This key is associated with remembering expanded folder paths.

### Folder hierarchy

The sidebar can represent nested folders. Expanding a parent folder makes its children visible; collapsing it hides its descendants in the sidebar.

Folder selection and folder expansion are separate actions so that selecting a folder does not necessarily change its expanded state.

---

## Installation

There are two primary ways to use My Notes: run it from Xcode or copy the built application into the macOS Applications folder.

### Requirements

- A Mac running a macOS version supported by the project's deployment target.
- Xcode compatible with the Swift and SwiftUI APIs used by the project.
- The My Notes source code.

### Option 1: Run from Xcode

1. Open the project in Xcode.
2. Select the `My-Notes` project scheme.
3. Select **My Mac** as the run destination.
4. Press `⌘B` to build.
5. Press `⌘R` to run the application.

This is the recommended workflow during development.

### Option 2: Install the built application

1. Open the project in Xcode.
2. Select the appropriate scheme and **My Mac** as the destination.
3. Choose **Product → Build** or press `⌘B`.
4. In Xcode, locate the `My-Notes.app` product under **Products**.
5. Right-click the application and choose **Show in Finder** if that option is available.
6. Copy the resulting `.app` bundle into `/Applications`.
7. Open the app from the Applications folder.

For a standard Debug build, the resulting app is commonly located inside the project's DerivedData build directory, under a path similar to:

`Build/Products/Debug/My-Notes.app`

The actual location depends on the Xcode build configuration.

### Add the app to the Dock

1. Open My Notes from the Applications folder.
2. Right-click its Dock icon.
3. Choose **Options → Keep in Dock**.

### Updating the installed app

When installing a newer build, replace the old application with the newly built `.app` bundle.

Keep your notes backed up before changing application versions, especially if the storage implementation changes.

---

## Building from Source

### Open the project

Open the `.xcodeproj` file or the project's `.xcworkspace` file if the project uses a workspace.

### Build

Press:

`⌘B`

Xcode compiles the Swift files, processes the asset catalog, and creates the application bundle.

### Run

Press:

`⌘R`

Xcode builds the application if necessary and launches it using the selected run configuration.

### Clean the build folder

If Xcode reports stale build products or asset-processing errors, use:

**Product → Clean Build Folder**

Shortcut:

`⇧⌘K`

Then build again.

Cleaning the build folder does not fix an invalid asset catalog or an incorrect icon configuration. Those problems must be corrected separately.

---

## Project Structure

The following files are known to exist in the project. Their exact responsibilities should be confirmed against the current source code before major refactoring.

| File | Responsibility |
|---|---|
| `MyApp.swift` | Application entry point and main app configuration |
| `ContentView.swift` | Main interface, view state, sidebar, note list, and editor |
| `NoteStorage.swift` | Note storage and filesystem-related operations |
| `NoteFolderFeatures.swift` | Folder creation and folder-related functionality |
| `NoteFeatures.swift` | Additional note functionality |
| `NoteUtilities.swift` | Shared utility functions and supporting logic |
| `CommandPalette.swift` | Command palette implementation |

### Assets

The asset catalog is located at:

`Assets.xcassets`

The application icon should be configured through an icon set in this catalog, typically named `AppIcon`.

Other assets may be added to the catalog as the interface develops.

### Recommended separation of responsibilities

- Keep application entry-point configuration in `MyApp.swift`.
- Keep view composition and UI state in the main view and its related extensions.
- Keep filesystem operations in the storage layer.
- Keep folder-specific behavior in the folder-related implementation.
- Keep reusable utility logic separate from the UI.
- Keep command-palette behavior separate from the main editor where practical.

This separation helps make the project easier to maintain and debug.

---

## Technology Stack

### Swift

Swift is the primary programming language. It provides type safety and access to Apple's native frameworks.

### SwiftUI

SwiftUI is used to construct the application's interface and manage reactive view updates.

### AppKit

AppKit provides macOS-specific functionality that may not be directly available through SwiftUI, including native dialogs and window-related operations.

### Foundation

Foundation provides essential APIs for strings, URLs, file management, and other application logic.

### FileManager

FileManager is used for filesystem operations such as accessing directories and managing files.

### Xcode

Xcode is the primary development environment for editing, building, running, and debugging the application.

---

## Configuration and App Icon

### Configure the app icon

1. Open `Assets.xcassets` in Xcode.
2. Select the `AppIcon` icon set.
3. Add the image using the icon layout supported by the project's Xcode version.
4. Open the `My-Notes` target.
5. Go to **General → App Icons and Launch Screen**.
6. Verify that the target references the correct icon set.

A square PNG image with dimensions of `512 × 512` pixels can be useful for an icon workflow, but image dimensions alone do not guarantee that Xcode will accept the asset catalog.

Depending on the Xcode version and icon configuration, the application may require a particular icon-set layout or additional image representations.

### If the app icon does not appear

Check the following:

- The icon set exists in `Assets.xcassets`.
- The icon image is present in the correct location.
- The icon set contains valid metadata.
- The target references the intended icon set.
- Xcode does not report asset-catalog processing errors.

After correcting the configuration, clean and rebuild the project.

---

## Troubleshooting

### `zsh: command not found: magick`

This means the ImageMagick command-line tool is not available in the current shell environment.

If Homebrew is installed, ImageMagick can be installed with:

```bash
brew install imagemagick
```

Then resize a PNG image using:

```bash
magick "input.png" -resize 512x512 "My-logo.png"
```

To inspect the resulting dimensions:

```bash
sips -g pixelWidth -g pixelHeight "My-logo.png"
```

macOS Preview can also resize images without installing additional software.

### `magick: no decode delegate for this image format '512x512'`

This error can occur when the resize dimensions are supplied without the `-resize` option.

Correct command:

```bash
magick "Sleek dark note and pencil icon.png" -resize 512x512 "My-logo.png"
```

### `Assets.xcassets: Distill failed for unknown reasons`

This error indicates that Xcode failed while processing the asset catalog.

Possible causes include:

- Invalid asset-catalog metadata.
- An incorrect icon-set structure.
- A missing or incorrectly named image file.
- An invalid image or unsupported asset configuration.
- A problem in the build cache.

Recommended troubleshooting:

1. Open the Issue Navigator with `⌘5`.
2. Expand the asset-catalog error to inspect the detailed message.
3. Inspect the `AppIcon` asset set.
4. Verify its image files and `Contents.json`.
5. Verify the app-icon configuration in the target.
6. Clean the build folder using `⇧⌘K`.
7. Build again using `⌘B`.

Do not delete the entire asset catalog as a first troubleshooting step.

### The app builds but does not appear

A successful build creates the application bundle but does not necessarily place it in the Applications folder.

Use Xcode's **Products** group or the build-products directory to locate `My-Notes.app`. Then copy it into `/Applications` if you want a standalone installed copy.

### The installed app shows an old icon

Make sure you are opening the newly built application rather than an older copy.

Replace the existing application in `/Applications` with the latest build and relaunch it. If the problem persists, inspect the target's icon configuration and asset-catalog build output.

---

## Development Guidelines

### Preserve complete source files

When modifying an existing source file, review the complete file and its related extensions before making changes.

Keep shared state and methods accessible wherever other extensions need them. For example, a `private` declaration can prevent a property or method from being accessed by code in a separate extension file.

### Test after changes

After modifying the application:

1. Build the project.
2. Resolve all compiler errors.
3. Run the application.
4. Test the modified feature.
5. Verify that existing note data remains accessible.

### Test important workflows

- Create and edit a note.
- Confirm that edits are saved.
- Close and reopen a note.
- Search for an existing note.
- Create and navigate nested folders.
- Expand and collapse folder trees.
- Verify keyboard shortcuts.
- Test supported file types.
- Verify the application icon in the built bundle.
- Check error handling for invalid file operations.

### Protect user data

Changes to storage, deletion, trash, and folder operations should be tested carefully.

Do not assume that deleting a note from the interface permanently removes it or moves it to the macOS Trash unless that behavior is verified in the current implementation.

---

## Roadmap

The following are potential development directions, not a guarantee that they are already implemented.

- Improve keyboard-first navigation.
- Ensure `⌘O` focuses the search field consistently.
- Refine the command palette.
- Improve folder-tree interaction.
- Improve editor behavior for different file types.
- Make the app icon and distribution workflow reliable.
- Add automated tests for storage and folder operations.
- Improve error reporting for file operations.
- Review accessibility and keyboard navigation.
- Document all application shortcuts and configuration options.

Features should be marked as complete only after they have been implemented and tested.

---

## License

No license has been specified in this README.

Add a license before distributing the project publicly. Without an explicit license, other people do not automatically receive permission to redistribute or modify the source code.

---

## Status

My Notes is a native macOS application under development.

This README documents the known architecture, design goals, supported file types, storage approach, and development workflow. The exact status of individual features may change as the implementation evolves.

For current behavior, the source code and the latest successfully built application are the authoritative references.

