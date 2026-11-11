import QtQuick
import QtQuick.Shapes

// Touch mode's way of picking an item up. A long press lifts it: framed in
// the accent with the rest of the window dimmed, its menu beside it. Moving
// the finger on from there, without letting go, drags it (or the selection
// it's part of): a label by the finger says what letting go would do, a
// drag held over a folder for a second opens it, and one held at the top or
// bottom edge of a list scrolls it. Lies over the whole window, and follows
// the finger without taking anything from what's underneath.
Item {
    id: lift

    // "" at rest, "lifted" while the menu shows, "dragging" once moved.
    property string phase: ""
    readonly property bool busy: phase !== ""
    readonly property bool dragging: phase === "dragging"
    // The pane the item was lifted in.
    property var pane: null
    property var urls: []
    property point origin
    property rect frame
    // The lists a drag scrolls at their edges, besides the pane's own.
    property var scrollers: []

    // The place under the finger that would take the drop, and what the
    // label says about it. Nothing for somewhere that only opens.
    readonly property var target: dragging ? probe.Drag.target : null
    readonly property string says: !target || target.opensOnly ? ""
        : target.label !== undefined ? target.label
        : target.trashes ? qsTr("Move to Trash")
        : fileOps.dropMoves(urls, target.folder) ? qsTr("Move to %1").arg(target.name)
        : qsTr("Copy to %1").arg(target.name)

    // A finger came down, at this point of the window.
    signal touched(point at)

    function begin(from, item, paths) {
        end()
        pane = from.pane
        urls = item.kind === "peer" ? [] : fileOps.urls(paths)
        const at = from.delegate.mapToItem(lift, 0, 0)
        frame = Qt.rect(at.x, at.y, from.delegate.width, from.delegate.height)
        origin = finger.point.scenePosition
        shot.source = ""
        from.delegate.grabToImage(result => { if (lift.busy) shot.source = result.url })
        phase = "lifted"
    }
    function end() {
        if (dragging)
            probe.Drag.cancel()
        phase = ""
        pane = null
        urls = []
        shot.source = ""
    }

    function moved() {
        // Lifting the finger clears its point, which is no move.
        if (!finger.active)
            return
        const at = finger.point.scenePosition
        if (phase === "lifted" && urls.length > 0 && Math.abs(at.x - origin.x) + Math.abs(at.y - origin.y) > 16) {
            phase = "dragging"
            // The menu goes; what it was about is on its way somewhere.
            pane.closeMenu()
            probe.x = at.x
            probe.y = at.y
            probe.Drag.active = true
        }
        if (dragging) {
            probe.x = at.x
            probe.y = at.y
        }
    }
    function released() {
        if (!dragging)
            return
        if (probe.Drag.target)
            probe.Drag.drop()
        else
            probe.Drag.cancel()
        phase = ""
        end()
    }

    // A drag that has opened another folder asks again who'd take a drop:
    // a place that turned it down doesn't look twice by itself.
    Connections {
        target: lift.pane ? lift.pane.paneBackend : null
        function onPathChanged() { Qt.callLater(lift.ask) }
    }
    function ask() {
        if (!dragging)
            return
        probe.Drag.active = false
        probe.Drag.active = true
    }

    Item {
        anchors.fill: parent
        PointHandler {
            id: finger
            acceptedDevices: PointerDevice.TouchScreen
            onPointChanged: lift.moved()
            onActiveChanged: active ? lift.touched(point.scenePosition) : lift.released()
        }
    }

    // What the drop areas see: one point under the finger, holding the
    // files a drop would bring.
    Item {
        id: probe
        property alias urls: lift.urls
        width: 1
        height: 1
        Drag.dragType: Drag.Internal
        Drag.keys: ["text/uri-list"]
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
    }

    Rectangle {
        anchors.fill: parent
        visible: lift.phase === "lifted"
        color: Qt.rgba(0, 0, 0, 0.45)
    }

    // The lifted item where it lay, then by the finger: small enough there
    // to see where it's going.
    Rectangle {
        id: held
        // A row keeps its height and its start, the icon and the name; a
        // tile shrinks whole.
        readonly property bool row: lift.frame.width > 320
        readonly property real small: !lift.dragging || row ? 1 : Math.min(1, 200 / lift.frame.width, 120 / lift.frame.height)
        visible: lift.busy
        width: lift.dragging && row ? 240 : lift.frame.width * small
        height: lift.frame.height * small
        clip: lift.dragging && row
        x: lift.dragging ? Math.max(4, Math.min(lift.width - width - 4, probe.x - width / 2)) : lift.frame.x
        y: lift.dragging ? Math.max(4, probe.y - height - 28) : lift.frame.y
        color: theme.background
        border.width: 2
        border.color: theme.accent
        radius: Math.min(6, theme.radius)
        opacity: lift.dragging ? 0.92 : 1
        Image {
            id: shot
            x: held.LayoutMirroring.enabled && held.clip ? held.width - width - 2 : 2
            y: 2
            width: lift.frame.width * held.small - 4
            height: lift.frame.height * held.small - 4
        }
        // How many, when the selection comes along.
        Rectangle {
            visible: lift.dragging && lift.urls.length > 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -8
            width: Math.max(22, count.implicitWidth + 10)
            height: 22
            color: theme.accent
            radius: Math.min(4, theme.radius)
            Text {
                id: count
                anchors.centerIn: parent
                text: lift.urls.length.toLocaleString(Qt.locale(), "f", 0)
                color: theme.accentForeground
                font.weight: Font.DemiBold
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        visible: lift.says.length > 0
        x: Math.max(4, Math.min(lift.width - width - 4, probe.x - width / 2))
        y: held.y + held.height + 6 > probe.y - 24 ? Math.max(4, held.y - height - 6) : held.y + held.height + 6
        width: label.implicitWidth + 24
        height: 30
        color: theme.background
        border.width: 1
        border.color: theme.accent
        radius: Math.min(4, theme.radius)
        Text {
            id: label
            anchors.centerIn: parent
            text: lift.says
            color: theme.brightForeground
        }
    }

    // Spring-loading: a ring on the place fills for a second, then it opens.
    readonly property var springing: target && target.spring ? target : null
    onSpringingChanged: {
        spring.stop()
        ring.sweep = 0
        if (springing) {
            const at = springing.mapToItem(lift, 0, 0)
            ring.x = Math.max(4, Math.min(lift.width - ring.width - 4, at.x + springing.width - ring.width - 8))
            ring.y = at.y + (springing.height - ring.height) / 2
            spring.start()
        }
    }
    NumberAnimation {
        id: spring
        target: ring
        property: "sweep"
        from: 0
        to: 360
        duration: 1000
        onFinished: {
            const place = lift.springing
            if (place)
                place.spring()
        }
    }
    Shape {
        id: ring
        property real sweep: 0
        visible: !!lift.springing && sweep > 0
        width: 26
        height: 26
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: theme.accent
            strokeWidth: 3
            fillColor: Qt.alpha(theme.background, 0.85)
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: 13; centerY: 13; radiusX: 10; radiusY: 10; startAngle: -90; sweepAngle: ring.sweep }
        }
    }

    // Edge scrolling: within 48 px of a list's top or bottom, faster the
    // closer to the edge.
    Timer {
        interval: 16
        repeat: true
        running: lift.dragging
        property bool odd: false
        onTriggered: {
            const lists = lift.scrollers.concat(lift.pane && lift.pane.scroller ? [lift.pane.scroller] : [])
            for (const list of lists) {
                if (!list || !list.visible)
                    continue
                const at = list.mapFromItem(lift, probe.x, probe.y)
                if (at.x < 0 || at.x > list.width || at.y < 0 || at.y > list.height)
                    continue
                const top = list.originY
                const bottom = Math.max(top, top + list.contentHeight - list.height)
                const before = list.contentY
                if (at.y < 48)
                    list.contentY = Math.max(top, list.contentY - (4 + (48 - at.y) / 2))
                else if (at.y > list.height - 48)
                    list.contentY = Math.min(bottom, list.contentY + (4 + (at.y - (list.height - 48)) / 2))
                // The finger hasn't moved, but what's under it has.
                if (list.contentY !== before) {
                    odd = !odd
                    probe.x = finger.point.scenePosition.x + (odd ? 0.01 : 0)
                }
            }
        }
    }
}
