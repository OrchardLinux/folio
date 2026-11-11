import QtQuick
import QtQuick.Layouts

// Select mode's bar along the bottom of the pane: what the menu offers for
// a selection, as buttons. Each acts on everything selected and ends select
// mode.
Rectangle {
    id: bar

    property bool inTrash: false
    property bool canShare: false
    readonly property int count: backend.folder.selectedCount
    signal done()
    signal deleteRequested(var paths)
    signal shareRequested(var near)

    implicitHeight: 64
    color: theme.background

    Rectangle { width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }

    function act(run) {
        const paths = backend.folder.selectedPaths()
        run(paths)
        done()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 0

        BarButton {
            Layout.fillWidth: true
            visible: bar.inTrash
            glyph: "back"
            text: qsTr("Restore")
            enabled: bar.count > 0
            onClicked: bar.act(paths => fileOps.restore(paths))
        }
        BarButton {
            Layout.fillWidth: true
            glyph: "copy"
            text: qsTr("Copy")
            enabled: bar.count > 0
            onClicked: bar.act(paths => fileOps.copy(paths))
        }
        BarButton {
            Layout.fillWidth: true
            visible: !bar.inTrash
            glyph: "cut"
            text: qsTr("Cut")
            enabled: bar.count > 0
            onClicked: bar.act(paths => fileOps.cut(paths))
        }
        // One at a time, as in the menu.
        BarButton {
            Layout.fillWidth: true
            visible: !bar.inTrash
            glyph: "duplicate"
            text: qsTr("Duplicate")
            enabled: bar.count === 1
            onClicked: bar.act(paths => fileOps.duplicate(paths[0]))
        }
        BarButton {
            Layout.fillWidth: true
            visible: !bar.inTrash
            glyph: "compress"
            text: qsTr("Compress")
            enabled: bar.count > 0
            onClicked: bar.act(paths => fileOps.compress(paths))
        }
        BarButton {
            id: share
            Layout.fillWidth: true
            visible: !bar.inTrash
            glyph: "share"
            text: qsTr("Share")
            enabled: bar.count > 0 && bar.canShare
            onClicked: bar.shareRequested(share)
        }
        BarButton {
            Layout.fillWidth: true
            glyph: "trash"
            // As in the menu: Trash moves there, and in the trash Delete…
            // deletes for good, after asking.
            text: bar.inTrash ? qsTr("Delete…") : qsTr("Trash")
            enabled: bar.count > 0
            onClicked: bar.act(paths => bar.inTrash ? bar.deleteRequested(paths) : fileOps.trash(paths))
        }
    }
}
