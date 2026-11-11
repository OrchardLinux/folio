import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "Format.js" as Format

// One item in the grid: a preview on top, its name below. Folders are a
// quiet card; files show a real thumbnail when one
// can be made, and a drawn stand-in for their kind when not; tailnet
// machines are a computer.
Item {
    id: tile

    required property int index
    property real zoom: 1
    required property string name
    required property string path
    required property bool isDir
    required property string kind
    required property string mime
    required property string extension
    required property int itemCount
    required property var size
    required property var modified
    required property bool selected

    property bool current: false
    // Touch mode: a finger's tap and long press are told apart from the
    // mouse's click, and select mode puts a check box on the tile.
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
    // In touch mode the tile is its picture and its name, not the whole
    // cell it's laid out in: the space between two tiles belongs to the
    // folder, for every press, tap, hover and drag.
    containmentMask: touchMode ? shape : null
    QtObject {
        id: shape
        function contains(point: point): bool { return tile.drawn(point) }
    }
    function drawn(at) {
        const pad = 8
        if (at.x >= artBox.x - pad && at.x <= artBox.x + artBox.width + pad
                && at.y >= artBox.y - pad && at.y <= artBox.y + artBox.height + pad)
            return true
        const wide = Math.max(label.contentWidth, details.contentWidth) + 2 * pad
        return Math.abs(at.x - width / 2) <= wide / 2 && at.y >= label.y - pad && at.y <= details.y + details.height + pad
    }

    // Pictures and drawings round their corners with the theme: square on
    // Omarchy's default, softly rounded on themes that round windows.
    readonly property real iconRadius: Math.min(10, theme.radius)

    // The badge and stand-in color for each kind, from the theme's palette.
    readonly property color kindColor: kind === "pdf" ? theme.red
                                     : kind === "text" ? theme.blue
                                     : kind === "audio" ? theme.magenta
                                     : kind === "video" ? theme.orange
                                     : kind === "archive" ? theme.yellow
                                     : kind === "image" ? theme.cyan
                                     : theme.secondaryForeground

    // The art is drawn at 128×92 and scaled, so a zoom keeps its shapes;
    // the box around it takes the scaled size for the layout.
    Item {
        id: artBox
        width: 128 * tile.zoom
        height: 92 * tile.zoom
        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter

        Item {
            id: art
            width: 128
            height: 92
            scale: tile.zoom
            transformOrigin: Item.TopLeft

            Loader {
                anchors.fill: parent
                sourceComponent: tile.isDir ? folderArt : tile.kind === "peer" ? peerArt : fileArt
            }

            // A folder takes files dropped on it, lighting up while they hover.
            FileDrop {
                id: folderDrop
                anchors.fill: parent
                enabled: tile.isDir
                folder: tile.path
                name: tile.name
            }
        }

        // Select mode's check box, on the corner the name starts from.
        Rectangle {
            visible: tile.picking
            x: -6
            y: -6
            width: 22
            height: 22
            radius: Math.min(4, theme.radius)
            color: tile.selected ? theme.accent : theme.background
            border.width: 1.5
            border.color: tile.selected ? theme.accent : Qt.alpha(theme.foreground, 0.5)
            Glyph { anchors.centerIn: parent; visible: tile.selected; name: "check"; size: 14; stroke: 2; color: theme.accentForeground }
            // Dragged from here across other items, a finger selects them all.
            DragHandler {
                target: null
                margin: 14
                acceptedDevices: PointerDevice.TouchScreen
                onActiveChanged: if (active) tile.sweepStarted()
                onCentroidChanged: if (active) tile.swept(centroid.scenePosition)
            }
        }
    }

    Text {
        id: label
        anchors.top: artBox.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        text: tile.name
        color: tile.current ? theme.accent : theme.foreground
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 1.15
    }

    // Size and when, quietly, under the name: "28.0 KB · 2:14 PM" today,
    // "28.0 KB · 11/9/26" before; just the item count for a folder, the system
    // for a machine.
    Text {
        id: details
        anchors.top: label.bottom
        anchors.topMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28
        text: {
            translator.language // Re-read when the language (and so the default locale) changes.
            if (tile.kind === "peer")
                return tile.extension
            const size = tile.isDir ? Format.count(tile.itemCount) : Format.size(tile.size)
            // A folder's own date says little (it changes when anything in
            // it is added or removed), so only files show one.
            const date = tile.isDir ? "" : Format.when(tile.modified)
            return size && date ? qsTr("%1 · %2").arg(size).arg(date) : size || date
        }
        color: theme.secondaryForeground
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        // The picture that follows the pointer while dragging; taken ahead
        // of time because a drag can't wait for it.
        onHoveredChanged: if (hovered) art.grabToImage(result => tile.Drag.imageSource = result.url)
    }

    // Dragging hands the file to whatever it lands on as a URI list: the
    // sidebar pins a folder, other apps get the file.
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
    Drag.hotSpot.x: tile.width / 2
    Drag.hotSpot.y: 40
    // A machine isn't a file to hand anywhere.
    DragHandler {
        target: null
        enabled: tile.kind !== "peer"
        // A finger's drag scrolls the folder; it picks an item up by
        // holding it first, which the window follows from there.
        acceptedDevices: tile.touchMode ? PointerDevice.AllDevices & ~PointerDevice.TouchScreen : PointerDevice.AllDevices
        // Dragging a selected item takes the whole selection along. The list
        // is built as the drag starts, not again on every change of selection.
        onActiveChanged: {
            if (active)
                tile.Drag.mimeData = { "text/uri-list": fileOps.uriList(tile.selected && backend.folder.selectedCount > 1 ? backend.folder.selectedPaths() : [tile.path]) }
            tile.Drag.active = active
        }
    }

    TapHandler {
        id: tap
        function byFinger() { return tile.touchMode && !!tap.point.device && tap.point.device.type === PointerDevice.TouchScreen }
        onTapped: byFinger() ? tile.touched() : tile.clicked(tap.point.modifiers)
        onDoubleTapped: if (!byFinger()) tile.activated()
        onLongPressed: if (byFinger()) tile.held()
    }
    // A finger shows where it is by pressing, as the pointer does by hovering.
    readonly property bool pressing: touchMode && tap.pressed

    // A folder's outline: a card with a tab on its top left edge, drawn as
    // one silhouette, its corners rounded by `r`.
    function folderPath(r) {
        if (r <= 0)
            return "M4.5 88.5V0.5H46L50 6.5H123.5V88.5Z"
        // Corners as quadratic curves: the curve renderer draws those
        // natively (filled arcs went missing on the GPU).
        const t = Math.min(r, 3)
        return "M4.5 " + (88.5 - r) + "V" + (0.5 + r) + "Q4.5 0.5 " + (4.5 + r) + " 0.5"
             + "H" + (46 - t) + "Q46 0.5 " + (46 + t * 0.6) + " " + (0.5 + t * 0.9) + "L" + (50 - t * 0.6) + " " + (6.5 - t * 0.9)
             + "Q50 6.5 " + (50 + t) + " 6.5H" + (123.5 - r) + "Q123.5 6.5 123.5 " + (6.5 + r)
             + "V" + (88.5 - r) + "Q123.5 88.5 " + (123.5 - r) + " 88.5H" + (4.5 + r)
             + "Q4.5 88.5 4.5 " + (88.5 - r) + "Z"
    }

    // Folders are a plain card, nothing on it; the name below says the rest.
    Component {
        id: folderArt

        Item {
            id: card
            width: 128
            height: 92
            readonly property color fill: tile.current || folderDrop.containsDrag ? Qt.tint(theme.lighterBackground, Qt.alpha(theme.accent, 0.3))
                : tile.hovering || tile.pressing ? Qt.tint(theme.lighterBackground, Qt.alpha(theme.foreground, 0.06))
                : theme.lighterBackground
            readonly property color line: tile.current || folderDrop.containsDrag ? theme.accent : "transparent"
            readonly property real lineWidth: folderDrop.containsDrag ? 2.5 : 1.5
            // As in Glyph: Qt's software renderer wouldn't clip the shape
            // to the grid it scrolls in, so there it's a picture.
            readonly property bool pictured: GraphicsInfo.api === GraphicsInfo.Software
            Image {
                anchors.fill: parent
                visible: card.pictured
                sourceSize: Qt.size(Math.ceil(width * tile.zoom * Screen.devicePixelRatio), Math.ceil(height * tile.zoom * Screen.devicePixelRatio))
                source: !card.pictured ? ""
                      : "image://shape/128/92/" + card.lineWidth + "/" + (tile.iconRadius > 0 ? 1 : 0) + "/" + String(card.fill).slice(1)
                        + "/" + String(card.line).slice(1) + "/" + encodeURIComponent(tile.folderPath(tile.iconRadius))
            }
            Shape {
                anchors.fill: parent
                visible: !card.pictured
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: card.fill
                    strokeColor: card.line
                    strokeWidth: card.lineWidth
                    joinStyle: tile.iconRadius > 0 ? ShapePath.RoundJoin : ShapePath.MiterJoin
                    PathSvg { path: card.pictured ? "" : tile.folderPath(tile.iconRadius) }
                }
            }
        }
    }

    Component {
        id: fileArt

        Item {
            // The picture is laid out at its own shape (cropped to fill for
            // photos and video, fitted for pages), so its corners can round.
            readonly property bool crop: tile.kind === "image" || tile.kind === "video"
            readonly property size natural: thumb.implicitWidth > 0 ? Qt.size(thumb.implicitWidth, thumb.implicitHeight) : Qt.size(1, 1)
            readonly property real fit: Math.min(width / natural.width, height / natural.height)
            Image {
                id: thumb
                width: parent.crop ? parent.width : parent.natural.width * parent.fit
                height: parent.crop ? parent.height : parent.natural.height * parent.fit
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                asynchronous: true
                fillMode: parent.crop ? Image.PreserveAspectCrop : Image.Stretch
                source: tile.kind === "text" ? Format.page(tile.path, tile.zoom > 1 ? 512 : 256, tile.modified, theme.lighterBackground, theme.foreground)
                                              : Format.thumb(tile.path, tile.mime, tile.zoom > 1 ? 512 : 256, tile.modified)
                visible: status === Image.Ready
                layer.enabled: tile.iconRadius > 0 && status === Image.Ready
                // The layer is drawn before the zoom scales it, so it's made
                // at the zoomed size to keep the bigger thumbnail's detail.
                layer.textureSize: Qt.size(Math.ceil(width * tile.zoom * Screen.devicePixelRatio),
                                           Math.ceil(height * tile.zoom * Screen.devicePixelRatio))
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: thumbMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
            }
            Rectangle {
                id: thumbMask
                width: thumb.width
                height: thumb.height
                radius: tile.iconRadius
                visible: false
                layer.enabled: true
                layer.textureSize: thumb.layer.textureSize
            }

            // Videos get a play mark over their frame.
            Rectangle {
                visible: thumb.status === Image.Ready && tile.kind === "video"
                anchors.centerIn: parent
                width: 30; height: 30
                radius: Math.min(4, theme.radius)
                color: Qt.alpha(theme.darkBackground, 0.75)
                Glyph { anchors.centerIn: parent; name: "play"; size: 16; color: theme.brightForeground }
            }

            // Stand-ins while a thumbnail loads, or when none can be made.
            Loader {
                anchors.fill: parent
                active: thumb.status !== Image.Ready
                sourceComponent: tile.kind === "audio" ? waveArt : tile.kind === "video" ? reelArt : pageArt
            }

            // Selection is a border on what's drawn, hugging it: the
            // thumbnail at its painted size, the page stand-in, or the box
            // of the others.
            readonly property rect shown: {
                const w = width, h = height
                if (thumb.status === Image.Ready)
                    return Qt.rect(thumb.x, thumb.y, thumb.width, thumb.height)
                if (tile.kind === "audio" || tile.kind === "video")
                    return Qt.rect(0, 0, w, h)
                return Qt.rect((w - 66) / 2, 0, 66, h)
            }
            Rectangle {
                visible: tile.current || tile.hovering || tile.pressing
                x: parent.shown.x - 3
                y: parent.shown.y - 3
                width: parent.shown.width + 6
                height: parent.shown.height + 6
                color: "transparent"
                border.width: tile.current ? 2 : 1
                border.color: tile.current ? theme.accent : Qt.alpha(theme.foreground, 0.2)
                radius: tile.iconRadius > 0 ? tile.iconRadius + 3 : 0
            }
        }
    }

    Component {
        id: peerArt

        Item {
            Glyph {
                id: computer
                anchors.centerIn: parent
                name: "peer"
                size: 76
                stroke: 1.2
                color: tile.current ? theme.accent : theme.foreground
            }
            Rectangle {
                visible: tile.current || tile.hovering
                anchors.fill: computer
                anchors.margins: -3
                color: "transparent"
                border.width: tile.current ? 2 : 1
                border.color: tile.current ? theme.accent : Qt.alpha(theme.foreground, 0.2)
                radius: tile.iconRadius > 0 ? tile.iconRadius + 3 : 0
            }
        }
    }

    Component {
        id: pageArt

        Item {
            Rectangle {
                id: page
                anchors.horizontalCenter: parent.horizontalCenter
                width: 66; height: 92
                color: theme.lighterBackground
                border.width: 1
                border.color: Qt.alpha(theme.foreground, 0.16)
                radius: tile.iconRadius
                Column {
                    x: 9; y: 11
                    spacing: 6
                    Rectangle { width: 34; height: 4; color: tile.kindColor }
                    Repeater {
                        model: [48, 48, 40, 48, 30]
                        Rectangle { required property int modelData; width: modelData; height: 2; color: Qt.alpha(theme.foreground, 0.3) }
                    }
                }
            }
            Rectangle {
                visible: tile.extension.length > 0
                anchors.left: page.left
                anchors.bottom: page.bottom
                anchors.bottomMargin: 6
                width: badge.implicitWidth + 8
                height: badge.implicitHeight + 2
                color: tile.kindColor
                Text { id: badge; anchors.centerIn: parent; text: tile.extension.slice(0, 4); font.pixelSize: 9; font.bold: true; color: theme.background }
            }
        }
    }

    Component {
        id: waveArt

        // Decorative, not the real waveform: bars seeded from the name so each
        // file keeps its own shape. Album art replaces it when the file has some.
        Rectangle {
            color: theme.lighterBackground
            radius: tile.iconRadius
            Row {
                anchors.centerIn: parent
                spacing: 3
                Repeater {
                    model: 18
                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: {
                            let h = 0
                            for (let i = 0; i < tile.name.length; ++i) h = (h * 31 + tile.name.charCodeAt(i) + index * 7) % 997
                            return 10 + (h % 40)
                        }
                        color: tile.kindColor
                    }
                }
            }
            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5; text: tile.extension; font.pixelSize: 9; color: theme.secondaryForeground }
        }
    }

    Component {
        id: reelArt

        Rectangle {
            color: theme.darkBackground
            radius: tile.iconRadius
            Glyph { anchors.centerIn: parent; name: "play"; size: 22; color: tile.kindColor }
        }
    }
}
