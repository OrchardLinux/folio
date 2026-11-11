# Files

![Files showing a folder of photos in the grid, with the details pane](docs/grid.png)

Files (`folio`) is Omarchy's file manager. It's one quiet window that follows your Omarchy theme and language, works from the keyboard, and never crawls your home folder in the background: folders are read when you open them, and thumbnails are made when a tile needs one, shared with every other app through `~/.cache/thumbnails`.

- **Three views**: a grid with real previews, a list, and Finder-style columns. Ctrl+1/2/3 switches.
- **Space previews** pictures, video, audio, PDFs, text and Markdown at full size, in their own window.
- **The sidebar** holds everything in your home folder, pinned folders (shared with GTK file dialogs), Recents, Trash with restore, your drives, and the machines on your tailnet, which open over SFTP.
- **Right-click** (or Alt+Enter) to open with another app, rename, duplicate, compress, share by Dropbox link, Taildrop or LocalSend, and delete. Copy and paste work with other apps, and nothing is ever overwritten.
- **Split** the window in two with Ctrl+Alt+N to move things between folders.

| Columns | Preview |
| --- | --- |
| ![The column view, four folders deep](docs/columns.png) | ![A photo in the preview window](docs/preview.png) |

## Keys

| Key | Does |
| --- | --- |
| Arrows, ⏎ | Move, open |
| Space | Preview |
| Backspace, Alt+← / Alt+→ | Up, back, forward |
| Ctrl+L | Type a path |
| / | Search here and below |
| Ctrl+C / X / V | Copy, cut, paste |
| F2, Delete | Rename, move to the trash |
| Ctrl+Shift+N | New folder |
| Ctrl+P | Pin the folder |
| Ctrl+N, Ctrl+Alt+N | New window, split |
| Tab | Sidebar and back |
| ? | Every other shortcut |

## Touch

On a machine with a touchscreen, Files turns on touch mode: bigger targets, and on screen what a finger has no keys for. With it off, nothing changes.

- **Tap** opens a folder, or shows a file's details, with Preview and Open there. **Long-press** is the right-click menu; keep the finger down and move, and the item comes along, to drop on a folder, a place in the sidebar, a part of the path, or the trash. Held over a folder for a second, a drag opens it.
- **Back**, **Up**, search and hidden files are buttons beside the path. **Select** picks several by tapping, with Copy, Cut, Compress, Share and Delete along the bottom, and after Copy or Cut, **Paste Here** waits there while you find the folder.
- **Narrow windows** work: a tablet held upright slides the sidebar over the files, a phone starts on the list of places, and the details come up as a sheet.

`touch=on` or `touch=off` in `~/.config/folio/folio.conf` overrides what the hardware says.

## Building

Files is C++ and Qt Quick. `bin/build` compiles it into `build/folio`, `bin/test` runs the tests, and `bin/install` builds and installs the Arch package. Omarchy installs it from [omarchy-pkgs](https://github.com/omacom/omarchy-pkgs).

## License

Files is released under the [MIT License](LICENSE).
