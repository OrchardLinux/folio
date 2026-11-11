import QtQuick

// The right-click menu. On an item: Open, Open With (each app that can),
// Preview, Rename, Duplicate, Copy, Cut, Paste Into, Copy Path, Compress,
// Share (Dropbox link, Taildrop, LocalSend: whichever are available), Pin,
// Terminal, Delete. On empty space: Paste, New Folder, Copy Path, Terminal,
// hidden files. In the trash: Restore, Empty Trash and Delete…,
// without the entries that change files. On a tailnet machine: Open, and
// nothing for files. Entries show their keys, so the menu also teaches the
// shortcuts.
FolioMenu {
    id: fileMenu

    // What was clicked ({path, name, isDir}), or null for empty space.
    property var target: null
    // The folder the click happened in.
    property string folder

    signal renameRequested(var target)
    signal deleteRequested(var paths)
    signal emptyTrashRequested()
    signal pinRequested(string path)
    signal detailsRequested()
    // On a phone (touch mode), Copy, Cut, Share and Delete are a row of
    // buttons along the top, so the menu fits the screen.
    property bool compact: false
    // Kept on screen when it opens beside an item near the edge.
    margins: touch.enabled ? 8 : -1
    // In the trash the menu is about getting things back, or letting go.
    readonly property bool trashView: fileOps.inTrash(folder)
    // The tailnet view lists machines, which only open.
    readonly property bool forFiles: folder !== "tailnet:"

    // Named for…, not on…: QML treats on… names as signal handlers, and an
    // onFolder beside the folder property never updated.
    readonly property bool forItem: !!target && target.path !== undefined
    readonly property bool forFolder: forItem && target.isDir === true
    readonly property var apps: forItem && forFiles ? fileOps.appsFor(target.path) : []
    // Open With only when there's something besides what Open already does.
    readonly property bool canOpenWith: apps.length > 1
    // A selected item in the folder being shown stands for the whole
    // selection, so Copy, Compress or Delete act on all of it.
    readonly property bool forSelection: forItem && target.selected === true && backend.folder.selectedCount > 1
                                         && backend.folder.indexOf(target.name) >= 0
    readonly property var paths: !forItem ? [] : forSelection ? backend.folder.selectedPaths() : [target.path]

    // Opens at the pointer (`at`, in the window), or (from the keyboard,
    // Alt+Return) beside the item it's about. Mirrored, it opens leftward,
    // and beside the item's icon and name at its right end; Menu mirrors
    // neither by itself.
    // `beside` (touch mode) puts it next to `near` rather than over it: to
    // the side of a tile, under a row.
    // Opening beside an item makes that item the menu's parent, and the
    // item may be gone by the next time; a click's menu opens in the pane.
    property Item home: null
    Component.onCompleted: home = parent
    function show(clicked, where, near, at, beside) {
        target = clicked
        folder = where
        shifted = fileOps.shiftHeld()
        // Empty space among machines has nothing to offer.
        if (!forItem && !forFiles)
            return
        // Submenus (Open With, Share) show only when they have entries.
        // Menu makes their entries itself, so they're set here rather than
        // bound where they're declared.
        for (let i = 0; i < count; ++i) {
            const entry = itemAt(i)
            if (entry && entry.subMenu)
                entry.shown = entry.subMenu === shareMenu ? canShare && !compact : canOpenWith
        }
        // The menu's own `mirrored` is only set once it's open.
        const rtl = Qt.application.layoutDirection === Qt.RightToLeft
        if (near && beside) {
            const row = near.width > 320
            popup(near, row ? (rtl ? near.width - width - 14 : 14) : (rtl ? -width - 8 : near.width + 8), row ? near.height + 6 : 0)
        } else if (near) {
            const x = Math.min(near.width / 2, 120)
            popup(near, rtl ? near.width - x - width : x, near.height / 2)
        } else if (at) {
            const p = home.mapFromItem(null, at.x, at.y)
            popup(home, rtl ? p.x - width : p.x, p.y)
        } else {
            popup()
        }
    }

    // Share for what's selected, from select mode's bar: the Share menu on
    // its own, above the button.
    function selectionCanShare() {
        return fileOps.hasLocalSend() || places.peers.length > 0
    }
    function showShare(where, near) {
        const paths = backend.folder.selectedPaths()
        if (paths.length === 0)
            return
        target = backend.folder.get(backend.folder.indexOfPath(paths[0]))
        folder = where
        shareMenu.popup(near, 0, -shareMenu.height - 6)
    }

    Item {
        id: quick
        readonly property bool shown: fileMenu.compact && fileMenu.forItem && fileMenu.forFiles
        visible: shown
        width: parent ? parent.width : 0
        height: shown ? 64 : 0
        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            readonly property real each: width / 4
            BarButton {
                width: parent.each
                glyph: "copy"
                text: qsTr("Copy")
                onClicked: { fileOps.copy(fileMenu.paths); fileMenu.close() }
            }
            BarButton {
                width: parent.each
                glyph: "cut"
                text: qsTr("Cut")
                enabled: !fileMenu.trashView
                onClicked: { fileOps.cut(fileMenu.paths); fileMenu.close() }
            }
            BarButton {
                id: quickShare
                width: parent.each
                glyph: "share"
                text: qsTr("Share")
                enabled: fileMenu.canShare
                onClicked: shareMenu.popup(quickShare, 0, quickShare.height)
            }
            BarButton {
                width: parent.each
                glyph: "trash"
                text: fileMenu.trashView ? qsTr("Delete…") : qsTr("Trash")
                onClicked: {
                    const paths = fileMenu.paths
                    const forGood = fileMenu.trashView
                    fileMenu.close()
                    forGood ? fileMenu.deleteRequested(paths) : fileOps.trash(paths)
                }
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
    }
    FolioMenuItem {
        shown: fileMenu.forItem && fileMenu.trashView
        text: fileMenu.forSelection ? qsTr("Restore %Ln Items", "", fileMenu.paths.length) : qsTr("Restore")
        onTriggered: fileOps.restore(fileMenu.paths)
    }
    FolioMenuItem {
        shown: !fileMenu.forItem && fileMenu.trashView
        text: qsTr("Empty Trash…")
        onTriggered: fileMenu.emptyTrashRequested()
    }
    FolioMenuItem {
        shown: fileMenu.forItem
        text: fileMenu.forFolder ? qsTr("Open Folder") : qsTr("Open")
        keys: "⏎"
        onTriggered: backend.open(fileMenu.target.path)
    }
    // Every app that says it can open this type, the default first.
    FolioMenu {
        title: qsTr("Open With")
        Repeater {
            model: fileMenu.apps
            FolioMenuItem {
                required property var modelData
                text: modelData.isDefault ? qsTr("%1 (default)").arg(modelData.name) : modelData.name
                onTriggered: fileOps.openWith(fileMenu.target.path, modelData.id)
            }
        }
    }
    FolioMenuItem {
        shown: fileMenu.forItem && fileMenu.forFiles
        text: qsTr("Preview")
        keys: "Space"
        onTriggered: backend.togglePreview(fileMenu.target.path)
    }
    // Touch mode has no Ctrl+I.
    FolioMenuItem {
        shown: touch.enabled && fileMenu.forItem && fileMenu.forFiles
        text: qsTr("Details")
        onTriggered: fileMenu.detailsRequested()
    }
    FolioMenuItem {
        shown: fileMenu.forFolder
        text: fileMenu.forFolder && places.isPinned(fileMenu.target.path) ? qsTr("Unpin") : qsTr("Pin")
        keys: "Ctrl+P"
        onTriggered: fileMenu.pinRequested(fileMenu.target.path)
    }
    MenuLine { shown: fileMenu.forItem && fileMenu.forFiles }
    FolioMenuItem {
        shown: !fileMenu.trashView && fileMenu.forItem && fileMenu.forFiles
        text: qsTr("Rename…")
        keys: "F2"
        onTriggered: fileMenu.renameRequested(fileMenu.target)
    }
    FolioMenuItem {
        shown: !fileMenu.trashView && fileMenu.forItem && fileMenu.forFiles
        text: qsTr("Duplicate")
        keys: "Ctrl+Shift+D"
        onTriggered: fileOps.duplicate(fileMenu.target.path)
    }
    FolioMenuItem {
        shown: fileMenu.forItem && fileMenu.forFiles && !fileMenu.compact
        text: qsTr("Copy")
        keys: "Ctrl+C"
        onTriggered: fileOps.copy(fileMenu.paths)
    }
    FolioMenuItem {
        shown: !fileMenu.trashView && fileMenu.forItem && fileMenu.forFiles && !fileMenu.compact
        text: qsTr("Cut")
        keys: "Ctrl+X"
        onTriggered: fileOps.cut(fileMenu.paths)
    }
    FolioMenuItem {
        shown: !fileMenu.trashView && (!fileMenu.forItem || fileMenu.forFolder)
        text: fileMenu.forFolder ? qsTr("Paste Into Folder") : qsTr("Paste")
        keys: fileMenu.forItem ? "" : "Ctrl+V"
        enabled: fileOps.canPaste
        onTriggered: fileOps.paste(fileMenu.forItem ? fileMenu.target.path : fileMenu.folder)
    }
    FolioMenuItem {
        shown: fileMenu.forFiles
        text: qsTr("Copy Path")
        keys: "Ctrl+Shift+C"
        onTriggered: fileOps.yank(fileMenu.forItem ? fileMenu.paths : [fileMenu.folder])
    }
    FolioMenuItem {
        shown: !fileMenu.forItem && !fileMenu.trashView
        text: qsTr("New Folder")
        keys: "Ctrl+Shift+N"
        onTriggered: fileOps.newFolder(fileMenu.folder)
    }
    MenuLine { shown: fileMenu.forFiles }
    FolioMenuItem {
        shown: !fileMenu.trashView && fileMenu.forItem && fileMenu.forFiles
        text: qsTr("Compress")
        onTriggered: fileOps.compress(fileMenu.paths)
    }
    // Share offers only what this machine has: a Dropbox link for things in
    // the Dropbox folder (while Dropbox runs), Taildrop to the online
    // tailnet machines, and LocalSend when it's installed. With none of
    // them, there's no Share at all.
    readonly property bool canDropbox: forItem && target.path.startsWith(places.home + "/Dropbox/")
                                       && places.dropboxStatus !== "" && places.dropboxStatus !== "stopped"
    readonly property bool canTaildrop: forItem && forFiles && places.peers.length > 0
    readonly property bool canLocalSend: forItem && forFiles && fileOps.hasLocalSend()
    readonly property bool canShare: canDropbox || canTaildrop || canLocalSend

    // The entries are made only while they apply, rather than hidden:
    // opening Share from the keyboard highlights its first entry, even a
    // hidden one, and Return would run it.
    FolioMenu {
        id: shareMenu
        title: qsTr("Share")
        Repeater {
            model: fileMenu.canDropbox ? 1 : 0
            FolioMenuItem {
                text: qsTr("Dropbox Link")
                onTriggered: fileOps.dropboxLink(fileMenu.target.path)
            }
        }
        Repeater {
            model: fileMenu.canLocalSend ? 1 : 0
            FolioMenuItem {
                text: qsTr("LocalSend…")
                onTriggered: fileOps.shareLocalSend(fileMenu.paths)
            }
        }
    }
    // Taildrop is its own menu inside Share, one entry per machine; it's
    // added, after the other entries, only while there are machines to
    // send to.
    Instantiator {
        model: fileMenu.canTaildrop ? 1 : 0
        delegate: FolioMenu {
            title: qsTr("Taildrop")
            Repeater {
                model: places.peers
                FolioMenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: fileOps.shareTaildrop(fileMenu.paths, modelData.host)
                }
            }
        }
        onObjectAdded: (index, object) => shareMenu.addMenu(object)
        onObjectRemoved: (index, object) => shareMenu.removeMenu(object)
    }
    FolioMenuItem {
        shown: fileMenu.forFiles && (!fileMenu.forItem || fileMenu.forFolder)
        text: qsTr("Open Terminal Here")
        onTriggered: fileOps.openTerminal(fileMenu.forItem ? fileMenu.target.path : fileMenu.folder)
    }
    FolioMenuItem {
        shown: !fileMenu.forItem
        text: backend.folder.showHidden ? qsTr("Hide Hidden Files") : qsTr("Show Hidden Files")
        keys: "Ctrl+H"
        onTriggered: backend.folder.showHidden = !backend.folder.showHidden
    }
    MenuLine { shown: fileMenu.forItem && fileMenu.forFiles && !fileMenu.compact }
    // Moving to the trash and deleting for good are two things: Trash
    // (Delete) moves it there, where Restore in any file manager brings it
    // back, and with Shift held it becomes Delete… (Shift+Delete), which
    // deletes for good after asking. In the trash there's only the second.
    property bool shifted: false
    // Shift can go down or up anywhere while the menu's open, so it's
    // checked a few times a second rather than through key events.
    Timer {
        interval: 50
        repeat: true
        running: fileMenu.visible
        onTriggered: fileMenu.shifted = fileOps.shiftHeld()
    }
    FolioMenuItem {
        readonly property bool forGood: fileMenu.shifted || fileMenu.trashView
        shown: fileMenu.forItem && fileMenu.forFiles && !fileMenu.compact
        text: forGood ? qsTr("Delete…") : qsTr("Trash")
        keys: fileMenu.trashView ? "Delete" : forGood ? "Shift+Delete" : "Delete"
        onTriggered: forGood ? fileMenu.deleteRequested(fileMenu.paths) : fileOps.trash(fileMenu.paths)
    }
}
