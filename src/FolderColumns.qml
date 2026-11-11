import QtQuick
import QtQuick.Controls
import Folio

// Columns, as in the macOS Finder: the folders on the way here from the
// root (~, a tailnet machine, or /), the current folder, and what's inside
// the selected subfolder. → goes into the selected folder, ← back out;
// clicking anywhere to the left jumps there.
Item {
    id: view

    property alias currentIndex: here.currentIndex
    // In touch mode the columns divide the width between them, so the one
    // furthest left starts at the edge rather than partway in.
    readonly property int columnWidth: touchMode ? Math.floor(width / Math.max(2, Math.round(width / 261))) - 1 : 260

    function select(row, keep) { selecting.select(row, keep) }
    signal cursorLetGo()
    function letGo() { selecting.letGo(); cursorLetGo() }

    // Touch mode and its select mode, set by the pane. A finger's long
    // press on an item takes hold of it: the pane shows its menu, and
    // moving on from there drags it.
    property bool touchMode: false
    property bool picking: false
    signal held(var item, var from, string folder)
    signal fileTouched()
    property bool pointing: true
    readonly property var scroller: here
    // Off while a finger holds an item, so moving it doesn't scroll.
    property bool interactive: true

    Selecting { id: selecting; view: here; picking: view.picking; onFileTouched: view.fileTouched() }
    function focusView() { here.forceActiveFocus() }
    function menuAnchor() { return here.currentItem }

    // Every column has a menu: on an item there, or on the column's folder.
    signal contextMenu(var item, string folder, point at)

    readonly property var crumbs: backend.crumbs

    // The folders on the way here, kept as a list model that is only trimmed
    // and extended: moving one folder deeper or back out adds or drops one
    // column, and the rest stay as they are instead of reloading (which
    // flashed).
    ListModel { id: trail }
    function syncTrail() {
        const want = []
        for (let i = 0; i + 1 < crumbs.length; ++i)
            want.push({ path: crumbs[i].path, next: crumbs[i + 1].name })
        let same = 0
        while (same < trail.count && same < want.length && trail.get(same).path === want[same].path)
            ++same
        // Columns that stay may now point at a different next folder.
        for (let i = 0; i < same; ++i)
            if (trail.get(i).next !== want[i].next)
                trail.setProperty(i, "next", want[i].next)
        if (trail.count > same)
            trail.remove(same, trail.count - same)
        for (let i = same; i < want.length; ++i)
            trail.append(want[i])
    }
    onCrumbsChanged: syncTrail()
    Component.onCompleted: syncTrail()
    readonly property var selected: here.currentIndex >= 0 ? (backend.folder.count, backend.folder.get(here.currentIndex)) : ({})

    // Keeps the newest columns in view as the trail grows: on the left,
    // when mirrored.
    function revealEnd() { flick.contentX = view.LayoutMirroring.enabled ? 0 : Math.max(0, flick.contentWidth - flick.width) }
    LayoutMirroring.onEnabledChanged: revealEnd()
    function enter() { if (view.selected.isDir) backend.navigate(view.selected.path) }

    component Separator: Rectangle { width: 1; height: parent ? parent.height : 0; color: Qt.alpha(theme.foreground, 0.1) }

    Flickable {
        id: flick
        anchors.fill: parent
        // Touch mode: what's left of a width that doesn't divide evenly
        // stays empty at the start, rather than show a sliver of the
        // column before.
        anchors.leftMargin: view.touchMode && !view.LayoutMirroring.enabled ? view.width % (view.columnWidth + 1) : 0
        anchors.rightMargin: view.touchMode && view.LayoutMirroring.enabled ? view.width % (view.columnWidth + 1) : 0
        clip: true
        interactive: view.interactive
        acceptedButtons: Qt.NoButton
        contentWidth: Math.max(width, row.width)
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        onContentWidthChanged: view.revealEnd()
        onWidthChanged: view.revealEnd()
        ScrollBar.horizontal: FolioScrollBar { }

        Row {
            id: row
            // A Row isn't placed by its Flickable, so it's moved to the right
            // edge by hand when mirrored.
            x: LayoutMirroring.enabled ? parent.width - width : 0
            height: flick.height

            // The folders on the way here, each showing which way the trail goes.
            Repeater {
                model: trail
                Row {
                    id: ancestor
                    required property string path
                    required property string next
                    height: row.height

                    ListView {
                        id: column
                        width: view.columnWidth
                        height: parent.height
                        clip: true
                        acceptedButtons: Qt.NoButton
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: FolioScrollBar { }
                        model: FolderModel {
                            id: folder
                            path: ancestor.path
                            showHidden: backend.folder.showHidden
                            sortMode: backend.folder.sortMode
                            onLoaded: column.revealNext()
                        }
                        // Names sort by the language's alphabet.
                        Connections {
                            target: translator
                            function onChanged() { folder.reload() }
                        }
                        function revealNext() { positionViewAtIndex(Math.max(0, folder.indexOf(ancestor.next)), ListView.Contain) }
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            // A finger has no right button, though its tap would pass for one.
                            acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen
                            onTapped: (point) => {
                                const index = column.indexAt(point.position.x + column.contentX, point.position.y + column.contentY)
                                view.contextMenu(index >= 0 ? folder.get(index) : null, ancestor.path, point.scenePosition)
                            }
                        }
                        Connections {
                            target: ancestor
                            function onNextChanged() { column.revealNext() }
                        }
                        delegate: FileRow {
                            width: column.width
                            chevron: true
                            trail: name === ancestor.next
                            touchMode: view.touchMode
                            pointing: view.pointing
                            onClicked: isDir ? backend.navigate(path) : backend.showItem(path)
                            onActivated: backend.open(path)
                            onTouched: isDir ? backend.navigate(path) : backend.showItem(path)
                            onHeld: view.held(folder.get(index), this, ancestor.path)
                        }
                    }
                    Separator { }
                }
            }

            // The folder being shown: its selection is the window's.
            ListView {
                id: here
                width: view.columnWidth
                height: row.height
                clip: true
                interactive: view.interactive
                focus: true
                keyNavigationEnabled: true
                // No cursor of its own to start with: the pane puts it back
                // where the last view had it, and one on the first item would
                // select that instead.
                currentIndex: -1
                acceptedButtons: Qt.NoButton
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                model: backend.folder
                ScrollBar.vertical: FolioScrollBar { }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    // A finger has no right button, though its tap would pass for one.
                    acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen
                    onTapped: (point) => view.contextMenu(selecting.menuAt(point), backend.path, point.scenePosition)
                }

                // Touch mode: a long press on empty space is the folder's menu, and a
                // tap there lets go of the selection, as a click does. On an item, the
                // item's own handlers answer.
                TapHandler {
                    id: fingerTap
                    acceptedDevices: PointerDevice.TouchScreen
                    enabled: view.touchMode
        // On an item where the item itself says so: a tile is only its
                    // picture and its name.
                    function onItem() {
                        const item = here.itemAtIndex(here.indexAt(point.position.x + here.contentX, point.position.y + here.contentY))
                        return !!item && item.contains(item.mapFromItem(here, point.position))
                    }
                    onTapped: {
                        if (!onItem() && !view.picking) {
                            backend.folder.clearSelection()
                            view.letGo()
                        }
                    }
                    onLongPressed: if (!onItem()) view.contextMenu(null, backend.path, point.scenePosition)
                }

                onCurrentIndexChanged: selecting.cursorMoved()
                Keys.onPressed: (event) => selecting.extendBy(event, event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0)
                // Into a folder is the way the columns grow: leftward, when
                // mirrored.
                Keys.onRightPressed: view.LayoutMirroring.enabled ? backend.goUp() : view.enter()
                Keys.onLeftPressed: view.LayoutMirroring.enabled ? view.enter() : backend.goUp()

                delegate: FileRow {
                    width: here.width
                    chevron: true
                    current: selected
                    touchMode: view.touchMode
                    pointing: view.pointing
                    picking: view.picking
                    onClicked: (modifiers) => { selecting.click(index, modifiers); here.forceActiveFocus() }
                    onActivated: backend.open(path)
                    onTouched: { here.forceActiveFocus(); selecting.touch(index) }
                    onHeld: view.held(selecting.hold(index), this, backend.path)
                    onSweepStarted: selecting.sweepFrom(index)
                    onSwept: (at) => {
                        const p = here.mapFromItem(null, at.x, at.y)
                        selecting.sweepTo(here.indexAt(p.x + here.contentX, p.y + here.contentY))
                    }
                }

                // Where the first item would be, lined up with the names.
                Text {
                    x: LayoutMirroring.enabled ? here.width - width - 46 : 46
                    y: 8
                    visible: here.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
                    text: backend.folder.query ? qsTr("No matches") : qsTr("No items")
                    color: theme.secondaryForeground
                }
            }
            Separator { }

            // A look inside the selected folder; clicking in it goes there.
            ListView {
                id: inside
                width: view.columnWidth
                height: row.height
                visible: view.selected.isDir === true
                clip: true
                acceptedButtons: Qt.NoButton
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: FolioScrollBar { }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    // A finger has no right button, though its tap would pass for one.
                    acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen
                    onTapped: (point) => {
                        const index = inside.indexAt(point.position.x + inside.contentX, point.position.y + inside.contentY)
                        view.contextMenu(index >= 0 ? inside.model.get(index) : null, view.selected.path, point.scenePosition)
                    }
                }
                model: FolderModel {
                    id: insideFolder
                    path: view.selected.isDir === true ? view.selected.path : ""
                    showHidden: backend.folder.showHidden
                    sortMode: backend.folder.sortMode
                }
                Connections {
                    target: translator
                    function onChanged() { insideFolder.reload() }
                }
                delegate: FileRow {
                    width: inside.width
                    chevron: true
                    touchMode: view.touchMode
                    pointing: view.pointing
                    onClicked: backend.showItem(path)
                    onActivated: backend.open(path)
                    onTouched: backend.showItem(path)
                    onHeld: view.held(inside.model.get(index), this, view.selected.path)
                }

                Text {
                    x: LayoutMirroring.enabled ? inside.width - width - 46 : 46
                    y: 8
                    visible: inside.count === 0 && !inside.model.loading
                    text: qsTr("No items")
                    color: theme.secondaryForeground
                }
            }
            // Touch mode: every column as wide as the next with its line, so
            // the columns before end exactly at the edge.
            Separator { visible: view.touchMode && inside.visible }
        }
    }
}
