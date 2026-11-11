import QtQuick
import QtQuick.Controls

// A dialog button: the accent when it's the main choice, quiet otherwise.
// No ripple, no animation.
AbstractButton {
    id: button
    property bool primary: false

    implicitWidth: Math.max(88, label.implicitWidth + 32)
    implicitHeight: touch.enabled ? 44 : 36
    // In touch mode only the mouse hovers: a finger would leave the button
    // it tapped looking hovered. Its own hover can't tell the two apart,
    // so it's off, and a handler's hover counts while the mouse is in use.
    hoverEnabled: !touch.enabled
    HoverHandler { id: pointer; enabled: touch.enabled }
    readonly property bool pointed: touch.enabled ? pointer.hovered && touch.pointing : button.hovered
    Accessible.name: text

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.primary ? (button.pointed ? Qt.lighter(theme.accent, 1.08) : theme.accent)
             : touch.enabled && button.down ? Qt.alpha(theme.foreground, 0.15)
             : button.pointed ? Qt.alpha(theme.foreground, 0.10)
             : Qt.alpha(theme.foreground, 0.05)
        border.width: button.visualFocus ? 1 : 0
        border.color: theme.accent
    }
    contentItem: Text {
        id: label
        text: button.text
        color: button.primary ? theme.accentForeground : theme.foreground
        font.weight: button.primary ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
