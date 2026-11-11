import QtQuick
import QtQuick.Layouts

// Touch mode's Ctrl+V: after Copy or Cut, a bar along the bottom of the
// pane says what's on the clipboard and offers to paste it into the folder
// being shown, wherever that has got to by then.
Rectangle {
    id: bar

    readonly property var clip: fileOps.clipboard
    signal pasted()
    signal cancelled()

    implicitHeight: column.implicitHeight + 24
    color: theme.background

    Rectangle { width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }

    function homeless(path) { return path === places.home || path.startsWith(places.home + "/") ? "~" + path.slice(places.home.length) : path }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        GridLayout {
            Layout.fillWidth: true
            // Beside each other where there's room, the buttons under the
            // words on a phone.
            columns: bar.width >= 560 ? 3 : 2
            columnSpacing: 10
            rowSpacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.columnSpan: bar.width >= 560 ? 1 : 2
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    text: bar.clip.cut ? qsTr("%Ln items cut", "", bar.clip.count) : qsTr("%Ln items copied", "", bar.clip.count)
                    color: theme.brightForeground
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    visible: bar.clip.from.length > 0
                    text: qsTr("from %1").arg(bar.homeless(bar.clip.from))
                    color: theme.secondaryForeground
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
            }
            PlainButton {
                Layout.fillWidth: bar.width < 560
                text: qsTr("Cancel")
                onClicked: bar.cancelled()
            }
            PlainButton {
                Layout.fillWidth: bar.width < 560
                text: qsTr("Paste Here")
                primary: true
                onClicked: bar.pasted()
            }
        }
    }
}
