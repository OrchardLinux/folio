import QtQuick

// Where the window is too narrow for the details beside the files (touch
// mode's medium and narrow layouts), they come over them instead, the files
// dimming behind: from the side on a tablet held upright, as the pane the
// wide layout has there, and on a phone, which has no width for that, up
// from the bottom with a handle to grab. A swipe back the way it came or a
// tap outside closes it.
Item {
    id: sheet

    property alias folderPane: details.folderPane
    property bool open: false
    // From the side rather than from the bottom.
    property bool side: false
    signal dismissed()

    // How far in it is, from 0 to 1: it slides in and out, the files
    // dimming with it, and follows a finger pulling it.
    property real shown: open ? 1 : 0
    Behavior on shown {
        enabled: !pull.active
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    visible: shown > 0
    // On its way out it's already out of the way of the next touch.
    enabled: open

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: sheet.shown
        MouseArea { anchors.fill: parent; onClicked: sheet.dismissed() }
    }

    Rectangle {
        id: card
        width: sheet.side ? 320 : parent.width
        height: sheet.side ? parent.height : Math.min(sheet.height - 60, 560)
        // The side the details are on when they're beside the files: the
        // right, or the left when mirrored.
        x: !sheet.side ? 0 : LayoutMirroring.enabled ? -width * (1 - sheet.shown) : sheet.width - width * sheet.shown
        y: sheet.side ? 0 : sheet.height - height * sheet.shown
        color: theme.darkBackground

        Rectangle { visible: !sheet.side; width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
        // Taps on the card stay on the card.
        MouseArea { anchors.fill: parent }
        DragHandler {
            id: pull
            target: null
            xAxis.enabled: sheet.side
            yAxis.enabled: !sheet.side
            onActiveTranslationChanged: {
                if (!active)
                    return
                const away = sheet.side ? (card.LayoutMirroring.enabled ? -1 : 1) * activeTranslation.x / card.width
                                        : activeTranslation.y / card.height
                sheet.shown = Math.max(0, Math.min(1, 1 - away))
            }
            onActiveChanged: {
                if (active)
                    return
                const away = sheet.shown < 0.8
                sheet.shown = Qt.binding(() => sheet.open ? 1 : 0)
                if (away)
                    sheet.dismissed()
            }
        }

        Rectangle {
            visible: !sheet.side
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 44
            height: 4
            radius: Math.min(2, theme.radius)
            color: Qt.alpha(theme.foreground, 0.3)
        }

        // The pane as it is beside the files, or at a phone's width.
        PreviewPane {
            id: details
            anchors.top: parent.top
            anchors.topMargin: sheet.side ? 0 : 16
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: sheet.side ? parent.width : Math.min(parent.width, 420)
            edged: sheet.side
        }
    }
}
