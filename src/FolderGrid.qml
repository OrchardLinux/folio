import QtQuick
import QtQuick.Controls

// The folder as a grid of tiles with real previews.
GridView {
    id: grid

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
    readonly property var scroller: grid

    Selecting { id: selecting; view: grid; picking: grid.picking; onFileTouched: grid.fileTouched() }
    onCurrentIndexChanged: selecting.cursorMoved()
    Keys.onPressed: (event) => {
        // With no cursor (after a click on empty space), Down starts at the
        // first item, not a row's width on from before it.
        if (event.key === Qt.Key_Down && currentIndex < 0 && count > 0) {
            currentIndex = 0
            event.accepted = true
            return
        }
        // Mirrored, the next item is to the left, as the plain arrows know.
        const ahead = grid.effectiveLayoutDirection === Qt.RightToLeft ? -1 : 1
        selecting.extendBy(event, event.key === Qt.Key_Left ? -ahead : event.key === Qt.Key_Right ? ahead
                                : event.key === Qt.Key_Up ? -columns : event.key === Qt.Key_Down ? columns : 0)
    }

    Band {
        view: grid
        touchMode: grid.touchMode
        // Mirrored, the first column is on the right, flush with the edge
        // (the columns may not fill the width exactly).
        rectOf: (i) => {
            const c = i % grid.columns
            const x = grid.effectiveLayoutDirection === Qt.RightToLeft ? grid.width - (c + 1) * grid.cellWidth : c * grid.cellWidth
            return Qt.rect(x + 20, Math.floor(i / grid.columns) * grid.cellHeight + 12,
                           grid.cellWidth - 40, grid.cellHeight - 24)
        }
    }

    // Right-click on an item (selecting it) or on empty space.
    signal contextMenu(var item, string folder, point at)
    TapHandler {
        acceptedButtons: Qt.RightButton
        // A finger has no right button, though its tap would pass for one.
        acceptedDevices: PointerDevice.AllDevices & ~PointerDevice.TouchScreen
        onTapped: (point) => grid.contextMenu(selecting.menuAt(point), backend.path, point.scenePosition)
    }

    // Touch mode: a long press on empty space is the folder's menu, and a
    // tap there lets go of the selection, as a click does. On an item, the
    // item's own handlers answer.
    TapHandler {
        id: fingerTap
        acceptedDevices: PointerDevice.TouchScreen
        enabled: grid.touchMode
        // On an item where the item itself says so: a tile is only its
        // picture and its name.
        function onItem() {
            const item = grid.itemAtIndex(grid.indexAt(point.position.x + grid.contentX, point.position.y + grid.contentY))
            return !!item && item.contains(item.mapFromItem(grid, point.position))
        }
        onTapped: {
            if (!onItem() && !grid.picking) {
                backend.folder.clearSelection()
                grid.letGo()
            }
        }
        onLongPressed: if (!onItem()) grid.contextMenu(null, backend.path, point.scenePosition)
    }

    clip: true
    focus: true
    keyNavigationEnabled: true
    // No cursor of its own to start with: the pane puts it back where the
    // last view had it, and one on the first item would select that instead.
    currentIndex: -1
    // Pressing and dragging picks up a file (to pin it, or drop it in another
    // app) or draws a band, rather than flicking; the wheel and touchpad
    // still scroll, which turning the view's interactive off would stop too.
    acceptedButtons: Qt.NoButton
    boundsBehavior: Flickable.StopAtBounds
    model: backend.folder
    // Tiles grow with the zoom; the name and details under them don't. A
    // narrow pane (one side of a split) caps it at a tile its width holds.
    property real zoom: 1
    // A phone's width still gets two tiles side by side.
    property int minimumColumns: 1
    // Touch mode: the view reaches the window's edge, where the scroll bar
    // then is, and keeps `edge` clear of tiles beside it.
    property int edge: 0
    readonly property int room: width - edge
    // The width a column had before the details took some of the room, when
    // the window says: the columns left then keep it, and stay put.
    property int steadyCell: 0
    // The least room between two tiles' pictures. Touch mode packs them
    // closer, so a tablet's width holds a column more.
    readonly property int gap: touchMode ? 22 : 40
    readonly property real tileZoom: Math.max(0.5, Math.min(zoom, (room / minimumColumns - gap) / 128))
    signal zoomRequested(int step)
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        acceptedModifiers: Qt.ControlModifier
        // A touchpad sends many small deltas: a step per notch's worth
        // (120), and nothing for an event that doesn't move up or down.
        property real pending: 0
        onWheel: (event) => {
            // Every whole notch is a step; the rest waits for the next event.
            pending += event.angleDelta.y
            while (Math.abs(pending) >= 120) {
                const step = pending > 0 ? 1 : -1
                grid.zoomRequested(step)
                pending -= step * 120
            }
        }
    }
    // The rows reflow, so bring the cursor's tile back into view.
    onTileZoomChanged: Qt.callLater(() => { if (currentIndex >= 0) { forceLayout(); positionViewAtIndex(currentIndex, GridView.Contain) } })
    readonly property int columns: Math.max(1, steadyCell > 0 ? Math.round(room / steadyCell) : Math.floor(room / (gap + 128 * tileZoom)))
    cellWidth: Math.floor(room / columns)
    cellHeight: 100 + Math.round(92 * tileZoom)
    highlightFollowsCurrentItem: false
    ScrollBar.vertical: FolioScrollBar { }

    delegate: FileTile {
        width: grid.cellWidth
        height: grid.cellHeight
        zoom: grid.tileZoom
        current: selected
        touchMode: grid.touchMode
        pointing: grid.pointing
        picking: grid.picking
        onClicked: (modifiers) => { selecting.click(index, modifiers); grid.forceActiveFocus() }
        onActivated: backend.open(path)
        onTouched: { grid.forceActiveFocus(); selecting.touch(index) }
        onHeld: grid.held(selecting.hold(index), this, backend.path)
        onSweepStarted: selecting.sweepFrom(index)
        onSwept: (at) => {
            const p = grid.mapFromItem(null, at.x, at.y)
            selecting.sweepTo(grid.indexAt(p.x + grid.contentX, p.y + grid.contentY))
        }
    }

    Text {
        anchors.centerIn: parent
        visible: grid.count === 0 && !backend.folder.loading && backend.folder.error.length === 0
        text: backend.folder.query ? qsTr("Nothing matches “%1”").arg(backend.folder.query)
            : backend.path === "tailnet:" ? qsTr("No machines are online") : qsTr("This folder is empty")
        color: theme.secondaryForeground
    }
}
