import QtQuick

// Takes files dropped on a view's empty space into its folder, lighting up
// while they hover. A folder item in the view takes drops on itself first;
// where it refuses one (it's the folder being dropped, or the one the drop
// is already in), this refuses too, rather than catching the drop as it
// falls through and landing it in this folder instead.
FileDrop {
    id: area

    // Held over by a finger's drag, it's a folder already shown: nothing
    // to open.
    spring: null

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        visible: area.containsDrag
        color: Qt.alpha(theme.accent, 0.05)
        border.width: 2
        border.color: theme.accent
        radius: Math.min(6, theme.radius)
    }
}
