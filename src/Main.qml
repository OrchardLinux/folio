import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCore

// The window: one bar across the top, under it the sidebar, one folder pane
// or two side by side (Ctrl+Alt+N splits, Ctrl+W closes the right one),
// and the details pane. Each pane's path sits in the bar above its files;
// the sidebar and the details follow the pane used last.
//
// In touch mode the window also works narrow, laid out by its width: wide
// as ever; medium (a tablet held upright) with the sidebar sliding over
// the files and the details as a sheet from the bottom; narrow (a phone)
// starting on the list of places, each opening its folder.
ApplicationWindow {
    id: win
    width: 1280
    height: 800
    minimumWidth: touch.enabled ? 320 : 720
    minimumHeight: touch.enabled ? 320 : 460
    visible: true
    // The backend's title (Home, Trash) is translated in C++, which
    // retranslating QML doesn't redo, so the language is read here too.
    title: {
        translator.language
        return activePane && activePane.paneBackend.title.length > 0 ? activePane.paneBackend.title : qsTr("Files")
    }
    color: theme.background

    Material.theme: theme.light ? Material.Light : Material.Dark
    Material.accent: theme.accent
    Material.foreground: theme.foreground
    Material.background: theme.background
    Material.roundedScale: theme.radius

    // Right-to-left languages mirror the window, its menus and tooltips
    // included: they live in the window's overlay, outside its other items.
    // The Translator sets the application's layout direction.
    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property bool helpVisible: false
    property bool previewVisible: true
    // Columns on a first launch (the grid in touch mode, whose tiles are
    // the easier to hit); after that, whichever view was used last.
    property string viewMode: touch.enabled ? "grid" : "columns"
    property real zoom: 1

    // The pane keys, the sidebar and the details go to.
    property var activePane: leftPane
    // The right pane while the window is split.
    property var rightPane: null
    readonly property bool split: rightPane !== null
    // Whether keys are going into a text field. The right pane can go before
    // the window does when it closes, leaving activePane null.
    readonly property bool typing: !!activePane && activePane.typing
    // The rightmost pane's path bar reaches over the details column.
    readonly property int detailsWidth: details.visible ? details.width : 0
    // Whether the window is wide enough for the details column at all.
    readonly property bool detailsFit: width >= (split ? 1400 : 960) && form === "wide"

    // Touch mode, wide, showing the grid: the details come and go at a tap,
    // so they take whole columns of it, and the columns left keep their
    // width and their place. This is that width: what the grid's room
    // without the details divides into.
    readonly property int gridRoom: width - (sidebar.visible ? sidebar.width + 1 : 0) - 48
    readonly property int steadyCell: {
        if (!touch.enabled || form !== "wide" || split || !activePane || activePane.shownView !== "grid")
            return 0
        // As FolderGrid counts its columns in touch mode.
        const columns = Math.max(1, Math.floor(gridRoom / (22 + 128 * zoom)))
        const cell = Math.floor(gridRoom / columns)
        // Only where that leaves a column for the files.
        return columns > Math.ceil(300 / cell) ? cell : 0
    }
    // Whole columns, and the few pixels the columns don't divide.
    readonly property int steadyDetails: steadyCell > 0 ? Math.ceil(300 / steadyCell) * steadyCell + gridRoom % steadyCell : 300
    readonly property string form: !touch.enabled || width >= 1000 ? "wide" : width >= 600 ? "medium" : "narrow"
    // Medium: the sidebar is showing, over the files.
    property bool sidebarOpen: false
    // Narrow: the list of places is showing, and the folder last opened
    // from it, which Back leaves for the list again.
    property bool atPlaces: false
    property string placedAt: ""
    // Medium and narrow: the details sheet is up.
    property bool detailsOpen: false
    // What picks items up for a finger (TouchLift), in touch mode.
    readonly property var lift: liftLoader.item
    onFormChanged: {
        sidebarOpen = false
        detailsOpen = false
        if (form !== "wide")
            closeSplit()
        // A phone starts on its places, unless it's already somewhere.
        atPlaces = form === "narrow" && !!activePane && !activePane.paneBackend.canBack
                   && activePane.paneBackend.path === places.home
    }
    function showDetails() {
        if (detailsFit)
            previewVisible = true
        else
            detailsOpen = true
    }
    function goBack(pane) {
        const from = pane.paneBackend
        if (form === "narrow" && (!from.canBack || from.path === placedAt))
            atPlaces = true
        else
            from.back()
    }

    // Remembers the view between launches (~/.config/folio/folio.conf).
    Settings {
        property alias viewMode: win.viewMode
        property alias zoom: win.zoom
    }

    // Ctrl+Alt+N: a second pane on the right, starting where the active
    // one is. Pressed again, it moves the keyboard there.
    function openSplit() {
        if (form !== "wide")
            return
        if (!rightPane) {
            rightPane = windows.openSplit(win, activePane.paneBackend.path)
            if (!rightPane)
                return
            rightPane.parent = splitHost
            rightPane.anchors.fill = splitHost
            rightPane.closable = true
            rightPane.viewMode = activePane.viewMode
            rightPane.zoom = activePane.zoom
            rightPane.barExtension = Qt.binding(() => win.detailsWidth)
            rightPane.closeRequested.connect(closeSplit)
        }
        rightPane.focusView()
    }
    function closeSplit() {
        if (!rightPane)
            return
        activePane = leftPane
        rightPane = null
        windows.closeSplit(win)
        leftPane.focusView()
    }

    Shortcut { sequence: "?"; enabled: !win.typing || win.helpVisible; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; enabled: !win.typing; onActivated: win.close() }
    Shortcut { sequence: "Ctrl+Alt+N"; enabled: !win.typing; onActivated: win.openSplit() }
    Shortcut { sequence: "Ctrl+W"; enabled: win.split; onActivated: win.closeSplit() }
    Shortcut { sequence: "Ctrl+I"; onActivated: win.previewVisible = !win.previewVisible }
    // Tab moves the keyboard: sidebar, left pane, right pane, and around.
    Shortcut {
        sequences: ["Tab", "Backtab"]
        enabled: !win.typing
        onActivated: {
            if (sidebar.activeFocus)
                leftPane.focusView()
            else if (win.split && win.activePane === leftPane)
                win.rightPane.focusView()
            else
                sidebar.focusSidebar()
        }
    }

    Item {
        anchors.fill: parent

        // The bar across the top; the panes' path bars draw over it.
        readonly property int barHeight: 60
        Rectangle {
            width: parent.width
            height: parent.barHeight
            color: theme.background
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                target: win.activePane ? win.activePane.paneBackend : backend
                onFinished: win.activePane.focusView()
                onHelpRequested: win.helpVisible = !win.helpVisible
                visible: win.form === "wide"
                Layout.topMargin: parent.parent.barHeight
                Layout.preferredWidth: 190
                Layout.fillHeight: true
            }
            Rectangle { visible: sidebar.visible; Layout.topMargin: parent.parent.barHeight; Layout.fillHeight: true; implicitWidth: 1; color: Qt.alpha(theme.foreground, 0.12) }

            FolderPane {
                id: leftPane
                barExtension: win.split ? 0 : win.detailsWidth
                barLeft: sidebar.visible ? sidebar.width + 1 : 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: true
            }

            // openSplit() puts the right pane of a split here. Between the
            // panes the divider runs up through the top bar, so each path
            // reads as belonging to the files below it.
            Rectangle { visible: win.split; Layout.fillHeight: true; implicitWidth: 1; color: Qt.alpha(theme.foreground, 0.12) }
            Item {
                id: splitHost
                visible: win.split
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            PreviewPane {
                id: details
                visible: win.previewVisible && win.detailsFit
                Layout.topMargin: parent.parent.barHeight
                Layout.preferredWidth: win.steadyDetails
                Layout.fillHeight: true
                folderPane: win.activePane
            }
        }

        // Medium: the sidebar over the files, under the bar. A tap on a
        // place or beside it, or a swipe back out, closes it.
        Loader {
            id: drawer
            anchors.fill: parent
            anchors.topMargin: parent.barHeight
            active: win.form === "medium"
            sourceComponent: Item {
                id: slide
                property alias flick: slid.flick
                // How far in it is, from 0 to 1: it slides in and out, the
                // files dimming with it, and follows a finger pulling it
                // in from the edge or pushing it back out.
                property real shown: win.sidebarOpen ? 1 : 0
                readonly property bool showing: shown > 0
                Behavior on shown {
                    enabled: !pull.active && !edge.active
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                // A swipe in from the edge the sidebar lives at brings it.
                Item {
                    x: LayoutMirroring.enabled ? parent.width - width : 0
                    width: 24
                    height: parent.height
                    visible: !win.sidebarOpen
                    DragHandler {
                        id: edge
                        target: null
                        acceptedDevices: PointerDevice.TouchScreen
                        yAxis.enabled: false
                        onActiveTranslationChanged: {
                            if (active)
                                slide.shown = Math.max(0, Math.min(1, (slid.LayoutMirroring.enabled ? -1 : 1) * activeTranslation.x / slid.width))
                        }
                        onActiveChanged: {
                            if (active)
                                return
                            const stays = slide.shown > 0.3
                            slide.shown = Qt.binding(() => win.sidebarOpen ? 1 : 0)
                            if (stays)
                                win.sidebarOpen = true
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: slide.showing
                    // On its way out it's already out of the way of the next touch.
                    enabled: win.sidebarOpen
                    color: Qt.rgba(0, 0, 0, 0.55)
                    opacity: slide.shown
                    MouseArea { anchors.fill: parent; onClicked: win.sidebarOpen = false }
                }
                Sidebar {
                    id: slid
                    visible: slide.showing
                    enabled: win.sidebarOpen
                    x: LayoutMirroring.enabled ? parent.width - width * slide.shown : -width * (1 - slide.shown)
                    width: 260
                    height: parent.height
                    target: win.activePane ? win.activePane.paneBackend : backend
                    onPicked: win.sidebarOpen = false
                    onFinished: win.sidebarOpen = false
                    onHelpRequested: win.helpVisible = !win.helpVisible
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.alpha(theme.foreground, 0.12) }
                    DragHandler {
                        id: pull
                        target: null
                        yAxis.enabled: false
                        onActiveTranslationChanged: {
                            if (active)
                                slide.shown = Math.max(0, Math.min(1, 1 + (slid.LayoutMirroring.enabled ? -1 : 1) * activeTranslation.x / slid.width))
                        }
                        onActiveChanged: {
                            if (active)
                                return
                            const away = slide.shown < 0.7
                            slide.shown = Qt.binding(() => win.sidebarOpen ? 1 : 0)
                            if (away)
                                win.sidebarOpen = false
                        }
                    }
                }
            }
        }

        // Narrow: the places as the first screen, the whole window.
        Loader {
            anchors.fill: parent
            active: win.form === "narrow" && win.atPlaces
            sourceComponent: Rectangle {
                color: theme.background
                // Nothing underneath is reached through it.
                MouseArea { anchors.fill: parent }
                Text {
                    x: 24
                    width: parent.width - 48
                    height: 60
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    text: qsTr("Files")
                    color: theme.brightForeground
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Rectangle { y: 59; width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
                Sidebar {
                    y: 60
                    width: parent.width
                    height: parent.height - 60
                    full: true
                    target: win.activePane ? win.activePane.paneBackend : backend
                    onPicked: {
                        win.placedAt = target.path
                        win.atPlaces = false
                    }
                }
            }
        }

        // Medium and narrow: the details over the files, from the side
        // under the bar on a tablet held upright, from the bottom on a phone.
        Loader {
            anchors.fill: parent
            anchors.topMargin: win.form === "medium" ? parent.barHeight : 0
            active: touch.enabled && win.form !== "wide"
            sourceComponent: DetailsSheet {
                folderPane: win.activePane
                side: win.form === "medium"
                open: win.detailsOpen
                onDismissed: win.detailsOpen = false
            }
        }

        Loader {
            id: liftLoader
            anchors.fill: parent
            active: touch.enabled
            sourceComponent: TouchLift {
                onTouched: (at) => { if (win.activePane) win.activePane.touchedAt(at) }
                scrollers: [sidebar.flick].concat(drawer.item && drawer.item.showing ? [drawer.item.flick] : [])
            }
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
