import QtQuick
import QtQuick.Controls

// A button for the bars and menus touch mode adds: a glyph with its name
// under it.
AbstractButton {
    id: button

    property string glyph

    implicitWidth: Math.max(64, label.implicitWidth + 16)
    implicitHeight: 56
    focusPolicy: Qt.NoFocus
    Accessible.name: text

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.down ? Qt.alpha(theme.foreground, 0.10) : "transparent"
    }
    contentItem: Item {
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            name: button.glyph
            color: button.enabled ? theme.foreground : Qt.alpha(theme.foreground, 0.35)
        }
        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: button.text
            color: button.enabled ? theme.foreground : Qt.alpha(theme.foreground, 0.35)
            font.pixelSize: 11
        }
    }
}
