import QtQuick
import QtQuick.Controls

// A menu in Folio's look: the theme's colors, a hairline border, entries
// tinted in the accent when highlighted, and no opening or closing
// animation. Used for the right-click menu, its submenus and the sort menu.
Menu {
    enter: null
    exit: null
    // Touch mode: a tap beside the menu only closes it. Without this the
    // tap would also land on whatever is under it, as a click does.
    modal: touch.enabled
    dim: false
    // That only holds for a menu drawn inside the window. As a window of
    // its own, which is Qt's choice where the system has them, a tap beside
    // it is the compositor's to hand on, and it hands it to what's under.
    Component.onCompleted: if (touch.enabled) popupType = Popup.Item
    topPadding: 4
    bottomPadding: 4
    // Submenu entries (Open With, Share) are made from this.
    delegate: FolioMenuItem { }
    // As wide as its widest entry shown, so a long label (in any language)
    // never runs into its keys.
    width: {
        let widest = implicitBackgroundWidth
        for (let i = 0; i < count; ++i) {
            const entry = itemAt(i)
            if (entry && entry.visible)
                widest = Math.max(widest, entry.implicitWidth + leftPadding + rightPadding)
        }
        return widest
    }

    background: Rectangle {
        implicitWidth: 240
        color: theme.background
        border.width: 1
        border.color: Qt.alpha(theme.foreground, 0.16)
        radius: Math.min(6, theme.radius)
    }
}
