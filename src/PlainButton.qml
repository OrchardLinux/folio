import QtQuick
import QtQuick.Controls

// A dialog button: the accent when it's the main choice, red when it
// erases something, quiet otherwise. No ripple, no animation.
AbstractButton {
    id: button
    property bool primary: false
    property bool destructive: false
    readonly property bool filled: primary || destructive
    readonly property color fill: destructive ? theme.red : theme.accent

    implicitWidth: Math.max(88, label.implicitWidth + 32)
    implicitHeight: touch.enabled ? 44 : 36
    // In touch mode only the mouse hovers: a finger would leave the button
    // it tapped looking hovered. Its own hover can't tell the two apart,
    // so it's off, and a handler's hover counts while the mouse is in use.
    hoverEnabled: !touch.enabled
    HoverHandler { id: pointer; enabled: touch.enabled }
    readonly property bool pointed: touch.enabled ? pointer.hovered && touch.pointing : button.hovered
    Accessible.name: text
    // Tab reaches it, a click doesn't take the keyboard: clicking acts, and
    // leaves the keyboard where it was.
    focusPolicy: Qt.TabFocus
    // Return and Enter press it as Space does, and a button that has the
    // keyboard keeps these keys from the window's shortcuts (Space previews).
    Keys.onShortcutOverride: (event) => event.accepted = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
                                                         && [Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter].includes(event.key)
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.filled ? (button.pointed ? Qt.lighter(button.fill, 1.08) : button.fill)
             : touch.enabled && button.down ? Qt.alpha(theme.foreground, 0.15)
             : button.pointed ? Qt.alpha(theme.foreground, 0.10)
             : Qt.alpha(theme.foreground, 0.05)

        // A ring around the button that has the keyboard, however it got
        // there (Tab, or a dialog opening on it). It sits clear of the
        // button, so it shows on a fill of the accent too.
        Rectangle {
            visible: button.activeFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: button.destructive ? theme.red : theme.accent
        }
    }
    contentItem: Text {
        id: label
        text: button.text
        color: button.destructive ? theme.background : button.primary ? theme.accentForeground : theme.foreground
        font.weight: button.filled ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
