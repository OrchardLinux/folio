import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Format.js" as Format

// One item as a row, for the list and column views: a small picture or
// glyph, the name, and in the list the size and date beside it.
Item {
    id: row

    required property int index
    required property string name
    required property string path
    required property bool isDir
    required property string kind
    required property string mime
    required property string extension
    required property var size
    required property var modified
    required property int itemCount
    required property bool selected

    property bool current: false
    // In a column to the left: the folder the next column is showing.
    property bool trail: false
    property bool detailed: false
    property bool chevron: false
    // Touch mode: rows a finger can hit, its tap and long press told apart
    // from the mouse's click, and in select mode a check box on each row.
    property bool touchMode: false
    property bool picking: false
    // Whether the pointer is a mouse's just now, rather than a finger's,
    // which has no hover to show though Qt reports one.
    property bool pointing: true
    readonly property bool hovering: hover.hovered && pointing

    signal clicked(int modifiers)
    signal activated()
    signal touched()
    signal held()
    signal sweepStarted()
    signal swept(point at)
    // Search results on a phone: the name, and the folder it's in under it.
    property bool stacked: false
    readonly property int cut: stacked ? name.lastIndexOf("/") : -1

    implicitHeight: touchMode ? (detailed ? 48 : 44) : 32

    // The name always gets room: in a narrow window the date goes first,
    // then the size. (The icon says what kind a file is; there's no column
    // for it.)
    readonly property bool showDate: detailed && width >= 480
    readonly property bool showSize: detailed && width >= 380

    readonly property string glyph: row.isDir ? "folder"
                                  : row.kind === "peer" ? "peer"
                                  : row.kind === "image" ? "pictures"
                                  : row.kind === "video" ? "videos"
                                  : row.kind === "audio" ? "music"
                                  : row.kind === "pdf" || row.kind === "text" ? "documents"
                                  : "file"

    // A folder row takes files dropped on it, lighting up while they hover.
    FileDrop {
        id: folderDrop
        anchors.fill: parent
        enabled: row.isDir
        folder: row.path
        name: row.name
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: Math.min(4, theme.radius)
        border.width: folderDrop.containsDrag ? 2 : 0
        border.color: theme.accent
        color: row.current || folderDrop.containsDrag ? Qt.alpha(theme.accent, 0.18)
             : row.trail ? Qt.alpha(theme.foreground, 0.08)
             : row.touchMode && tap.pressed ? Qt.alpha(theme.foreground, 0.10)
             : row.hovering ? Qt.alpha(theme.foreground, 0.05)
             : "transparent"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        Rectangle {
            visible: row.picking
            implicitWidth: 22
            implicitHeight: 22
            radius: Math.min(4, theme.radius)
            color: row.selected ? theme.accent : "transparent"
            border.width: 1.5
            border.color: row.selected ? theme.accent : Qt.alpha(theme.foreground, 0.5)
            Glyph { anchors.centerIn: parent; visible: row.selected; name: "check"; size: 14; stroke: 2; color: theme.accentForeground }
            // Dragged from here across other items, a finger selects them all.
            DragHandler {
                target: null
                margin: 14
                acceptedDevices: PointerDevice.TouchScreen
                onActiveChanged: if (active) row.sweepStarted()
                onCentroidChanged: if (active) row.swept(centroid.scenePosition)
            }
        }
        Item {
            implicitWidth: 20
            implicitHeight: 20
            Image {
                id: thumb
                anchors.fill: parent
                layer.enabled: theme.radius > 0 && status === Image.Ready
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: rowMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: row.kind === "image" || row.kind === "video" ? Format.thumb(row.path, row.mime, 128, row.modified) : ""
                visible: status === Image.Ready
            }
            Rectangle {
                id: rowMask
                width: 20
                height: 20
                radius: Math.min(4, theme.radius)
                visible: false
                layer.enabled: true
            }
            Glyph {
                anchors.centerIn: parent
                visible: !thumb.visible
                name: row.glyph
                size: 16
                color: row.isDir ? theme.accent : theme.secondaryForeground
            }
        }
        // The name and the date are aligned explicitly, so that they're
        // mirrored: left as they are, they'd follow their own script, and a
        // Latin name would sit at the far end of a right-to-left row.
        Text {
            visible: row.cut < 0
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            horizontalAlignment: Text.AlignLeft
            text: row.name
            color: row.current ? theme.accent : theme.foreground
            elide: Text.ElideMiddle
        }
        ColumnLayout {
            visible: row.cut >= 0
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 1
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: row.name.slice(row.cut + 1)
                color: row.current ? theme.accent : theme.foreground
                elide: Text.ElideMiddle
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                text: row.name.slice(0, Math.max(0, row.cut))
                color: theme.secondaryForeground
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
        }
        Text {
            visible: row.showSize
            Layout.preferredWidth: 96
            horizontalAlignment: Text.AlignRight
            text: row.kind === "peer" ? row.extension : row.isDir ? Format.count(row.itemCount) : Format.size(row.size)
            color: theme.secondaryForeground
            font.pixelSize: 12
        }
        Text {
            visible: row.showDate
            Layout.preferredWidth: 96
            Layout.leftMargin: 12
            horizontalAlignment: Text.AlignLeft
            text: {
                translator.language // Re-read when the language (and so the default locale) changes.
                return Format.when(row.modified)
            }
            color: theme.secondaryForeground
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        // Points to where the next column opens.
        Glyph {
            visible: row.chevron && row.isDir
            name: row.LayoutMirroring.enabled ? "back" : "forward"
            size: 12
            color: theme.secondaryForeground
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) row.grabToImage(result => row.Drag.imageSource = result.url)
    }
    TapHandler {
        id: tap
        function byFinger() { return row.touchMode && !!tap.point.device && tap.point.device.type === PointerDevice.TouchScreen }
        onTapped: byFinger() ? row.touched() : row.clicked(tap.point.modifiers)
        onDoubleTapped: if (!byFinger()) row.activated()
        onLongPressed: if (byFinger()) row.held()
    }

    // Like the tiles: dragged, a row is a file for the sidebar or another app.
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
    // The pointer holds the picture by its icon and name, which are at its
    // right end when mirrored.
    Drag.hotSpot.x: LayoutMirroring.enabled ? row.width : 0
    DragHandler {
        target: null
        enabled: row.kind !== "peer"
        // A finger's drag scrolls the folder; it picks an item up by
        // holding it first, which the window follows from there.
        acceptedDevices: row.touchMode ? PointerDevice.AllDevices & ~PointerDevice.TouchScreen : PointerDevice.AllDevices
        // Dragging a selected item takes the whole selection along. The list
        // is built as the drag starts, not again on every change of selection.
        onActiveChanged: {
            if (active)
                row.Drag.mimeData = { "text/uri-list": fileOps.uriList(row.selected && backend.folder.selectedCount > 1 ? backend.folder.selectedPaths() : [row.path]) }
            row.Drag.active = active
        }
    }
}
