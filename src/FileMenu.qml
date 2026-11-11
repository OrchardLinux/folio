import QtQuick

// The right-click menu. On an item: Open, Open With (each app that can),
// Preview, Rename, Duplicate, Copy, Cut, Paste Into, Copy Path, Compress,
// Extract (for archives), Burn (for disk images), plugins' own actions for
// it, Share (whatever plugins offer for it), Pin, Terminal, Trash. On empty
// space: Undo, Paste, New Folder, Copy Path, Terminal, hidden files. In the
// trash: Restore, Empty Trash and Delete…, without the entries that change
// files or plugins' actions. On a plugin's item: Open, and nothing for files. Entries show their
// keys, so the menu also teaches the shortcuts.
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
    // A disk image, and the drive (from fileOps.burnTargets) to burn it to.
    signal burnRequested(string path, var drive)
    signal detailsRequested()
    // On a phone (touch mode), Copy, Cut, Share and Delete are a row of
    // buttons along the top, so the menu fits the screen.
    property bool compact: false
    // Kept on screen when it opens beside an item near the edge.
    margins: touch.enabled ? 8 : -1
    // In the trash the menu is about getting things back, or letting go.
    readonly property bool trashView: fileOps.inTrash(folder)
    // Plugins' views list items, which only open.
    readonly property bool forFiles: !folder.startsWith("plugin:")

    // Named for…, not on…: QML treats on… names as signal handlers, and an
    // onFolder beside the folder property never updated.
    readonly property bool forItem: !!target && target.path !== undefined
    readonly property bool forFolder: forItem && target.isDir === true
    readonly property var apps: forItem && forFiles ? fileOps.appsFor(target.path) : []
    // Open With only when there's something besides what Open already does.
    readonly property bool canOpenWith: apps.length > 1
    // A file's type only: a folder's default app is the desktop's file
    // manager, not something to change from one folder's menu.
    // A selected item in the folder being shown stands for the whole
    // selection, so Copy, Compress or Delete act on all of it.
    readonly property bool forSelection: forItem && target.selected === true && backend.folder.selectedCount > 1
                                         && backend.folder.indexOf(target.name) >= 0
    readonly property var paths: !forItem ? [] : forSelection ? backend.folder.selectedPaths() : [target.path]
    // One disk image, and the drives it could be burned to, asked of udisks
    // as the menu opens rather than on every binding.
    property bool canBurn: false
    property var burnTargets: []

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
        // Not in the trash, where the menu is about getting things back.
        actions = forItem && forFiles && !trashView ? plugins.actionsFor(paths) : []
        // Empty space among a plugin's items has nothing to offer.
        if (!forItem && !forFiles)
            return
        canBurn = forItem && forFiles && !trashView && !forSelection && fileOps.canBurn(target.path)
        burnTargets = canBurn ? fileOps.burnTargets(target.path) : []
        // Submenus (Open With, Share, Burn) show only when they apply.
        // Menu makes their entries itself, so they're set here rather than
        // bound where they're declared. A plugin's own submenus are made
        // only when they apply, so they always show.
        for (let i = 0; i < count; ++i) {
            const entry = itemAt(i)
            if (entry && entry.subMenu)
                entry.shown = entry.subMenu === shareMenu ? canShare && !compact
                            : entry.subMenu === burnMenu ? canBurn
                            : entry.subMenu === openWithMenu ? canOpenWith : true
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

    // Names the change it undoes ("Undo Rename"), whichever window made it.
    FolioMenuItem {
        shown: !fileMenu.forItem && fileOps.undoName.length > 0
        text: fileOps.undoName
        keys: "Ctrl+Z"
        onTriggered: fileOps.undo()
    }
    MenuLine { shown: !fileMenu.forItem && fileOps.undoName.length > 0 }
    // Share for what's selected, from select mode's bar: the Share menu on
    // its own, above the button.
    // `count` is the selection's size, so a binding follows the selection.
    function selectionCanShare(count) {
        return count > 0 && plugins.actionsFor(backend.folder.selectedPaths()).some(action => action.menu === "share")
    }
    function showShare(where, near) {
        const paths = backend.folder.selectedPaths()
        if (paths.length === 0)
            return
        target = backend.folder.get(backend.folder.indexOfPath(paths[0]))
        folder = where
        actions = plugins.actionsFor(fileMenu.paths)
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
    // On an item too: the keyboard's menu is always on one, while there's
    // one in the trash.
    FolioMenuItem {
        shown: fileMenu.trashView
        text: qsTr("Empty Trash…")
        onTriggered: fileMenu.emptyTrashRequested()
    }
    FolioMenuItem {
        shown: fileMenu.forItem
        // Names the app it opens in: "Open with Plain".
        readonly property string app: fileMenu.forItem && !fileMenu.forFolder ? fileOps.defaultAppName(fileMenu.target.mime || "") : ""
        //: %1 is the name of the app the file opens in, like "Plain".
        text: fileMenu.forFolder ? qsTr("Open Folder") : app ? qsTr("Open With %1").arg(app) : qsTr("Open")
        keys: "⏎"
        onTriggered: backend.open(fileMenu.target.path)
    }
    // Every app that says it can open this type, the default first.
    FolioMenu {
        id: openWithMenu
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
    // Archives are extracted, not compressed again.
    readonly property bool archives: !trashView && forItem && forFiles && fileOps.canExtract(paths)
    FolioMenuItem {
        shown: !fileMenu.trashView && fileMenu.forItem && fileMenu.forFiles && !fileMenu.archives
        text: qsTr("Compress")
        onTriggered: fileOps.compress(fileMenu.paths)
    }
    FolioMenuItem {
        shown: fileMenu.archives
        text: qsTr("Extract")
        onTriggered: fileOps.extract(fileMenu.paths)
    }
    // Each USB stick or SD card the image could go on, those too small for
    // it listed but greyed out. Asked before anything's erased.
    FolioMenu {
        id: burnMenu
        title: qsTr("Burn")
        Repeater {
            model: fileMenu.burnTargets
            FolioMenuItem {
                required property var modelData
                text: modelData.text
                enabled: modelData.enabled
                onTriggered: fileMenu.burnRequested(fileMenu.target.path, modelData)
            }
        }
        Repeater {
            model: fileMenu.burnTargets.length === 0 ? 1 : 0
            FolioMenuItem {
                text: qsTr("No USB drives or SD cards")
                enabled: false
            }
        }
    }
    // What plugins offer for these, as it stands when the menu opens: their
    // own actions here, and under Share (a Dropbox link, Taildrop,
    // LocalSend). Each comes plain entries first, then submenus of a
    // plugin's items. With nothing to share, there's no Share.
    property var actions: []
    readonly property bool canShare: actions.some(action => action.menu === "share")
    // Menu's entries are numbered; plugins' actions go after Burn's.
    function afterBurn() {
        for (let i = 0; i < count; ++i)
            if (itemAt(i) && itemAt(i).subMenu === burnMenu)
                return i + 1
        return count
    }
    Instantiator {
        id: mainActions
        model: fileMenu.actions.filter(action => action.menu === "main" && !action.targets)
        delegate: FolioMenuItem {
            required property var modelData
            text: modelData.label
            onTriggered: backend.perform(modelData.plugin, modelData.id, fileMenu.paths)
        }
        onObjectAdded: (index, object) => fileMenu.insertItem(fileMenu.afterBurn() + index, object)
        onObjectRemoved: (index, object) => fileMenu.removeItem(object)
    }
    Instantiator {
        model: fileMenu.actions.filter(action => action.menu === "main" && !!action.targets)
        delegate: FolioMenu {
            id: mainTargets
            required property var modelData
            title: modelData.label
            Repeater {
                model: mainTargets.modelData.targets
                FolioMenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: backend.perform(mainTargets.modelData.plugin, mainTargets.modelData.id, fileMenu.paths, modelData.id)
                }
            }
        }
        // Submenus go after the plain entries, whichever are made first.
        onObjectAdded: (index, object) => fileMenu.insertMenu(fileMenu.afterBurn() + mainActions.count + index, object)
        onObjectRemoved: (index, object) => fileMenu.removeMenu(object)
    }

    // The entries are made only while they apply, rather than hidden:
    // opening Share from the keyboard highlights its first entry, even a
    // hidden one, and Return would run it.
    FolioMenu {
        id: shareMenu
        title: qsTr("Share")
        Repeater {
            model: fileMenu.actions.filter(action => action.menu === "share" && !action.targets)
            FolioMenuItem {
                required property var modelData
                text: modelData.label
                onTriggered: backend.perform(modelData.plugin, modelData.id, fileMenu.paths)
            }
        }
    }
    Instantiator {
        model: fileMenu.actions.filter(action => action.menu === "share" && !!action.targets)
        delegate: FolioMenu {
            id: targets
            required property var modelData
            title: modelData.label
            Repeater {
                model: targets.modelData.targets
                FolioMenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: backend.perform(targets.modelData.plugin, targets.modelData.id, fileMenu.paths, modelData.id)
                }
            }
        }
        onObjectAdded: (index, object) => shareMenu.addMenu(object)
        onObjectRemoved: (index, object) => shareMenu.removeMenu(object)
    }
    // On empty space, only where the folder shown is one to work in.
    FolioMenuItem {
        shown: fileMenu.forItem ? fileMenu.forFolder && fileMenu.forFiles
                                : fileMenu.folder.startsWith("/") && !fileMenu.trashView
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
