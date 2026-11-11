import QtQuick
import QtQuick.Controls

// The folder as a list: name, size and date (the date, then the size, step
// aside in a narrow window). No headings: the sort menu and S sort it.
ListView {
    id: list

    function select(row, keep) { selecting.select(row, keep) }
    // A click on empty space lets go of the cursor; the pane then keeps it
    // let go of through a re-read or a switch of view.
    signal cursorLetGo()
    function letGo() { selecting.letGo(); cursorLetGo() }
    function focusView() { forceActiveFocus() }
    // Where the keyboard's menu (Alt+Return) opens: beside the cursor's item.
    function menuAnchor() { return currentItem }

    // Touch mode and its select mode, set by the pane. A finger's long
    // press on an item takes hold of it: the pane shows its menu, and
    // moving on from there drags it.
    property bool touchMode: false
    property bool picking: false
    signal held(var item, var from, string folder)
    signal fileTouched()
    property bool pointing: true
    readonly property var scroller: list
    readonly property int rowHeight: touchMode ? 48 : 32

    Selecting { id: selecting; view: list; picking: list.picking; onFileTouched: list.fileTouched() }
    onCurrentIndexChanged: selecting.cursorMoved()
    Keys.onPressed: (event) => selecting.extendBy(event, event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0)

    Band {
        view: list
        touchMode: list.touchMode
        rectOf: (i) => Qt.rect(0, i * list.rowHeight, list.width, list.rowHeight)
    }

    // → goes into the selected folder and ← back up, as in the columns;
    // mirrored, the other way round, with the reading direction.
    function enter() {
        const item = backend.folder.get(currentIndex)
        if (item.isDir)
            backend.navigate(item.path)
    }
    Keys.onRightPressed: LayoutMirroring.enabled ? backend.goUp() : enter()
    Keys.onLeftPressed: LayoutMirroring.enabled ? enter() : backend.goUp()

    // Right-click on an item (selecting it) or on empty space.
    signal contextMenu(var item, string folder, point at)
    TapHandler {
        acceptedButtons: Qt.RightButton
        // A finger has no right button, though its tap would pass for one.
        acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen
        onTapped: (point) => list.contextMenu(selecting.menuAt(point), backend.path, point.scenePosition)
    }

    // Touch mode: a long press on empty space is the folder's menu, and a
    // tap there lets go of the selection, as a click does. On an item, the
    // item's own handlers answer.
    TapHandler {
        id: fingerTap
        acceptedDevices: PointerDevice.TouchScreen
        enabled: list.touchMode
        // On an item where the item itself says so: a tile is only its
        // picture and its name.
        function onItem() {
            const item = list.itemAtIndex(list.indexAt(point.position.x + list.contentX, point.position.y + list.contentY))
            return !!item && item.contains(item.mapFromItem(list, point.position))
        }
        onTapped: {
            if (!onItem() && !list.picking) {
                backend.folder.clearSelection()
                list.letGo()
            }
        }
        onLongPressed: if (!onItem()) list.contextMenu(null, backend.path, point.scenePosition)
    }

    clip: true
    focus: true
    keyNavigationEnabled: true
    // No cursor of its own to start with: the pane puts it back where the
    // last view had it, and one on the first item would select that instead.
    currentIndex: -1
    acceptedButtons: Qt.NoButton
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    model: backend.folder
    ScrollBar.vertical: FolioScrollBar { }

    delegate: FileRow {
        width: list.width
        detailed: true
        current: selected
        touchMode: list.touchMode
        pointing: list.pointing
        picking: list.picking
        stacked: list.touchMode && list.width < 600 && backend.folder.query.length > 0
        onClicked: (modifiers) => { selecting.click(index, modifiers); list.forceActiveFocus() }
        onActivated: backend.open(path)
        onTouched: { list.forceActiveFocus(); selecting.touch(index) }
        onHeld: list.held(selecting.hold(index), this, backend.path)
        onSweepStarted: selecting.sweepFrom(index)
        onSwept: (at) => {
            const p = list.mapFromItem(null, at.x, at.y)
            selecting.sweepTo(list.indexAt(p.x + list.contentX, p.y + list.contentY))
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
        text: backend.folder.query ? qsTr("Nothing matches “%1”").arg(backend.folder.query)
            : backend.path === "tailnet:" ? qsTr("No machines are online") : qsTr("This folder is empty")
        color: theme.secondaryForeground
    }
}
