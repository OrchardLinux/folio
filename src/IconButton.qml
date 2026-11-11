import QtQuick
import QtQuick.Controls

// A square toolbar button holding one glyph. `text` is its accessible name
// and tooltip, never drawn. A finger has no hover, so in touch mode holding
// the button shows its name instead, and letting go then leaves it be.
AbstractButton {
    id: button

    property string glyph
    property bool active: false

    property bool held: false

    implicitWidth: touch.enabled ? 44 : 36
    implicitHeight: touch.enabled ? 44 : 36
    focusPolicy: Qt.NoFocus
    // In touch mode only the mouse hovers: a finger would leave the button
    // it tapped looking hovered. Its own hover can't tell the two apart,
    // so it's off, and a handler's hover counts while the mouse is in use.
    hoverEnabled: !touch.enabled
    HoverHandler { id: pointer; enabled: touch.enabled }
    readonly property bool pointed: touch.enabled ? pointer.hovered && touch.pointing : button.hovered

    Accessible.name: text
    // Its own tooltip, so it can appear without fading in or out.
    onPressAndHold: held = touch.enabled
    onPressedChanged: if (!pressed) held = false
    ToolTip {
        visible: (button.pointed || button.held) && button.text.length > 0
        delay: button.held ? 0 : 600
        text: button.text
        enter: null
        exit: null
    }

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: button.active ? Qt.alpha(theme.accent, 0.16)
             : touch.enabled && button.down ? Qt.alpha(theme.foreground, 0.10)
             : button.pointed && button.enabled ? Qt.alpha(theme.foreground, 0.08)
             : "transparent"
    }

    contentItem: Item {
        Glyph {
            anchors.centerIn: parent
            name: button.glyph
            color: !button.enabled ? Qt.alpha(theme.foreground, 0.35)
                 : button.active ? theme.brightForeground : theme.foreground
        }
    }
}
