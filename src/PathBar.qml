import QtQuick
import QtQuick.Layouts

// The breadcrumb path from the left edge; view buttons on the right. Back and
// forward are keys (Alt+← / Alt+→) and the mouse's thumb buttons.
//
// Touch mode adds what those keys do as buttons: back and up before the
// path, search, hidden files and Select after it. The path is cut to fit
// rather than scrolled, a phone's width folds the buttons into a menu, and
// select mode swaps them for its count, Select All and Done.
Rectangle {
    id: bar

    property bool previewVisible: true
    property bool previewFits: true
    property string viewMode: "grid"
    // Ctrl+L: the path as text to edit. Enter goes there, Escape cancels,
    // Tab completes a folder name.
    property bool editing: false
    // The right pane of a split has a close button (Ctrl+W).
    property bool closable: false
    signal closeRequested()
    signal togglePreview()
    signal cycleView()
    signal editDone()

    // Touch mode: the window's layout ("wide", "medium" or "narrow"), and
    // whether the pane is in select mode.
    property string form: "wide"
    property bool picking: false
    property bool sidebarShown: false
    signal sidebarRequested()
    signal backRequested()
    signal pickingRequested(bool on)
    readonly property bool narrow: touch.enabled && form === "narrow"
    // Touch mode: a path or a search being typed takes the whole bar, with
    // Cancel beside it and nothing else; on a phone a search does for as
    // long as it lasts.
    readonly property bool takenOver: touch.enabled && (editing || searchFocused || (narrow && searching))
    // The buttons that act on the folder: not in select mode, and on a
    // phone in the menu instead.
    readonly property bool tools: !picking && !narrow && !takenOver
    // Recents, the tailnet, the trash and search results have nothing above
    // them, and neither has /.
    readonly property bool canUp: backend.path !== "/" && backend.path !== "recent:" && backend.path !== "tailnet:"
                                  && !(fileOps.inTrash(backend.path) && backend.crumbs.length === 1)
                                  && backend.folder.query.length === 0
    readonly property string parentPath: backend.path.replace(/\/[^\/]*$/, "") || "/"

    // The crumbs that fit in `room`: all of them, or the first and as many
    // of the last as there's room for with … between them, or on a phone
    // just … and where you are. The … holds the ones left out.
    FontMetrics { id: crumbFont; font.pixelSize: 14 }
    FontMetrics { id: lastCrumbFont; font.pixelSize: 14; font.weight: Font.DemiBold }
    function fitted(crumbs, room) {
        if (!touch.enabled || crumbs.length < 2)
            return crumbs
        const slash = crumbFont.advanceWidth("/") + 20
        const last = crumbs.length - 1
        const wide = (i) => (i === last ? lastCrumbFont : crumbFont).advanceWidth(crumbs[i].name) + (i > 0 ? slash : 0) + 10
        let all = 0
        for (let i = 0; i <= last; ++i)
            all += wide(i)
        if (all <= room)
            return crumbs
        const dots = crumbFont.advanceWidth("…") + slash + 10
        // Without the first crumb when even it, … and the last don't fit.
        const first = wide(0) + dots + wide(last) <= room ? 1 : 0
        let used = (first ? wide(0) : 0) + dots + wide(last)
        let from = last
        while (from - 1 >= first && from - 1 > 0 && used + wide(from - 1) <= room)
            used += wide(--from)
        const left = { name: "…", path: "", hidden: crumbs.slice(first, from) }
        return crumbs.slice(0, first).concat([left], crumbs.slice(from))
    }

    function editPath() {
        pathField.text = backend.typedPath()
        editing = true
        pathField.forceActiveFocus()
        pathField.selectAll()
    }
    readonly property bool fieldFocused: pathField.activeFocus || searchField.activeFocus
    // Whether a point of the window is on what's being typed into.
    function keeps(at) {
        for (const item of [pathField, searchField, completions]) {
            if (item.visible && item.contains(item.mapFromItem(null, at.x, at.y)))
                return true
        }
        return false
    }
    // A completion tapped: its row goes as the text changes, so the bar does this.
    function complete(path) {
        pathField.text = path
        pathField.cursorPosition = path.length
    }
    function stopEditing() {
        editing = false
        editDone()
    }

    // /: search this folder and every folder below it, as you type. The
    // results replace the folder until Escape, or until going elsewhere.
    readonly property bool searching: backend.folder.query.length > 0 || searchFocused
    readonly property bool searchFocused: searchField.activeFocus
    function search() {
        searchField.forceActiveFocus()
        searchField.selectAll()
    }
    // S and Shift+S, through the sort menu's orders.
    function stepSort(by) { sortMenu.step(by) }
    function endSearch() {
        searchDelay.stop()
        searchField.text = ""
        backend.folder.query = ""
        editDone()
    }
    Timer {
        id: searchDelay
        interval: 150
        onTriggered: backend.folder.query = searchField.text.trim()
    }
    // Going to another folder ends the search there.
    Connections {
        target: backend.folder
        function onQueryChanged() { if (backend.folder.query === "" && !searchField.activeFocus) searchField.text = "" }
    }

    // Transparent: the window draws one bar across the whole top, so the
    // path bars of one or two panes read as part of it.
    color: "transparent"
    implicitHeight: 60

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: touch.enabled ? 8 : 26
        anchors.rightMargin: touch.enabled ? 8 : 20
        spacing: 4

        // Touch mode: the sidebar (where it slides over the files), back
        // and up. A drag held on one opens it; Up takes a drop too.
        IconButton {
            visible: touch.enabled && bar.form === "medium" && !bar.picking && !bar.takenOver
            glyph: "sidebar"
            text: qsTr("Sidebar")
            active: bar.sidebarShown
            onClicked: bar.sidebarRequested()
            FileDrop { anchors.fill: parent; opensOnly: true; spring: () => bar.sidebarRequested() }
        }
        IconButton {
            visible: touch.enabled && !bar.takenOver && !(bar.narrow && bar.picking)
            glyph: LayoutMirroring.enabled ? "forward" : "back"
            text: qsTr("Back")
            // On a phone, back from the first folder is the list of places.
            enabled: backend.canBack || bar.narrow
            onClicked: bar.backRequested()
            FileDrop { anchors.fill: parent; enabled: bar.narrow; opensOnly: true; spring: () => bar.backRequested() }
        }
        IconButton {
            visible: touch.enabled && !bar.takenOver && !(bar.narrow && bar.picking) && bar.canUp
            glyph: "up"
            text: qsTr("Up")
            onClicked: backend.goUp()
            FileDrop { anchors.fill: parent; folder: bar.parentPath; spring: () => backend.goUp() }
        }

        PlainField {
            id: pathField
            Layout.fillWidth: true
            visible: bar.editing
            font.pixelSize: 14
            onAccepted: {
                if (backend.goTyped(text))
                    bar.stopEditing()
            }
            Keys.onEscapePressed: bar.stopEditing()
            Keys.onTabPressed: {
                text = backend.completePath(text)
                cursorPosition = text.length
            }
            onActiveFocusChanged: if (!activeFocus && bar.editing) bar.stopEditing()
        }

        PlainField {
            id: searchField
            Layout.fillWidth: true
            visible: bar.searching && !bar.editing
            font.pixelSize: 14
            // Room at the end for where it searches; padding isn't mirrored.
            leftPadding: LayoutMirroring.enabled ? scope.implicitWidth + 24 : 12
            rightPadding: LayoutMirroring.enabled ? 12 : scope.implicitWidth + 24
            // Where it searches, at the end of the field. Unlike a
            // placeholder, it stays while typing. The tailnet has nothing
            // below it.
            Text {
                id: scope
                // Recents, Trash and Tailnet are named in C++, which
                // retranslating QML doesn't redo.
                readonly property string here: {
                    translator.language
                    return backend.crumbs.length > 0 ? backend.crumbs[backend.crumbs.length - 1].name : ""
                }
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: backend.path === "tailnet:" ? qsTr("Search %1").arg(here) : qsTr("Search %1 and below").arg(here)
                color: theme.secondaryForeground
                font.pixelSize: 12
            }
            onTextEdited: searchDelay.restart()
            // Enter or ↓ goes to the results, leaving the search up.
            function toResults() {
                searchDelay.stop()
                backend.folder.query = text.trim()
                if (backend.folder.query === "")
                    bar.endSearch()
                else
                    bar.editDone()
            }
            onAccepted: toResults()
            Keys.onDownPressed: toResults()
            Keys.onEscapePressed: bar.endSearch()
        }

        // Touch mode: Escape as a button, right beside the search or the
        // path it ends.
        PlainButton {
            visible: touch.enabled && (bar.editing || bar.searching)
            text: qsTr("Cancel")
            onClicked: bar.searching ? bar.endSearch() : bar.stopEditing()
        }
        Flickable {
            id: crumbFlick
            visible: !bar.editing && !bar.searching && !(bar.narrow && bar.picking)
            Layout.leftMargin: touch.enabled ? 8 : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: Math.max(width, crumbs.implicitWidth)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // Long paths keep their end in view; that's where you are.
            // Mirrored, the end is on the left.
            function revealEnd() { contentX = LayoutMirroring.enabled ? 0 : Math.max(0, contentWidth - width) }
            onContentWidthChanged: revealEnd()
            onWidthChanged: revealEnd()
            LayoutMirroring.onEnabledChanged: revealEnd()

            // Touch mode: a tap past the crumbs opens the path for typing,
            // as Ctrl+L does.
            TapHandler {
                enabled: touch.enabled
                onTapped: (point) => {
                    const x = point.position.x + crumbFlick.contentX
                    if (x < crumbs.x || x > crumbs.x + crumbs.width)
                        bar.editPath()
                }
            }

            Row {
                id: crumbs
                // A Row isn't placed by its Flickable, so it's moved to the
                // right edge by hand when mirrored.
                x: LayoutMirroring.enabled ? parent.width - width : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Repeater {
                    id: crumbList
                    // Recents, Trash and Tailnet are named in C++, which
                    // retranslating QML doesn't redo.
                    model: { translator.language; return bar.fitted(backend.crumbs, crumbFlick.width) }
                    Row {
                        id: crumb
                        required property var modelData
                        required property int index
                        readonly property bool last: index === crumbList.count - 1
                        spacing: 10
                        Text {
                            visible: crumb.index > 0
                            text: "/"
                            color: Qt.alpha(theme.foreground, 0.35)
                            font.pixelSize: 14
                        }
                        Text {
                            text: crumb.modelData.name
                            color: crumb.last ? theme.brightForeground : crumbMouse.containsMouse ? theme.foreground : theme.secondaryForeground
                            font.pixelSize: 14
                            font.weight: crumb.last ? Font.DemiBold : Font.Normal
                            MouseArea {
                                id: crumbMouse
                                anchors.fill: parent
                                // Touch mode: as tall as a finger needs.
                                anchors.margins: touch.enabled ? -Math.max(4, (44 - parent.height) / 2) : -4
                                hoverEnabled: !touch.enabled || touch.pointing
                                // The folder you're in opens the path for typing, as Ctrl+L does.
                                cursorShape: crumb.last ? Qt.IBeamCursor : Qt.PointingHandCursor
                                onClicked: crumb.modelData.hidden ? hiddenCrumbs.show(crumb, crumb.modelData.hidden)
                                         : crumb.last ? bar.editPath() : backend.navigate(crumb.modelData.path)
                            }
                            // Touch mode: a finger's drag can be dropped on a
                            // crumb, or held there to open it.
                            FileDrop {
                                anchors.fill: crumbMouse
                                enabled: touch.enabled && !crumb.modelData.hidden
                                folder: crumb.modelData.path
                                name: crumb.modelData.name
                            }
                        }
                    }
                }
            }
        }

        Item { visible: !bar.narrow && !bar.takenOver; implicitWidth: 16 }
        // Touch mode: / as a button.
        IconButton {
            visible: touch.enabled && !bar.picking && !bar.searching && !bar.takenOver && backend.path !== "recent:"
            glyph: "search"
            text: qsTr("Search")
            onClicked: bar.search()
        }
        // Shows the current view; clicking moves to the next one.
        IconButton {
            visible: bar.tools
            glyph: bar.viewMode
            // Names what a click does, like the buttons beside it.
            text: bar.viewMode === "grid" ? qsTr("Show as list")
                : bar.viewMode === "list" ? qsTr("Show as columns")
                : qsTr("Show as grid")
            onClicked: bar.cycleView()
        }
        IconButton {
            id: sortButton
            visible: bar.tools
            // Shows the order in use, and says it on hover.
            glyph: sortMenu.current.glyph
            text: sortMenu.current.tip
            active: sortMenu.visible
            // Under the button, reaching toward the files.
            onClicked: sortMenu.popup(sortButton, LayoutMirroring.enabled ? sortButton.width - sortMenu.width : 0, sortButton.height + 4)
        }
        SortMenu { id: sortMenu }
        // Touch mode: Ctrl+H as a button.
        IconButton {
            visible: touch.enabled && bar.tools
            glyph: "hidden"
            text: backend.folder.showHidden ? qsTr("Hide Hidden Files") : qsTr("Show Hidden Files")
            active: backend.folder.showHidden
            onClicked: backend.folder.showHidden = !backend.folder.showHidden
        }
        IconButton {
            glyph: "preview"
            // Only where the window has room to show them.
            visible: bar.previewFits && bar.tools
            text: qsTr("Details")
            active: bar.previewVisible
            onClicked: bar.togglePreview()
        }
        // Touch mode: select mode, for picking several without Shift, Alt
        // or a band; and on a phone, the folder's buttons as a menu.
        PlainButton {
            visible: touch.enabled && bar.tools
            text: qsTr("Select")
            onClicked: bar.pickingRequested(true)
        }
        IconButton {
            id: moreButton
            visible: bar.narrow && !bar.picking && !bar.takenOver
            glyph: "more"
            text: qsTr("More")
            active: moreMenu.visible
            onClicked: moreMenu.popup(moreButton, LayoutMirroring.enabled ? 0 : moreButton.width - moreMenu.width, moreButton.height + 4)
        }
        Text {
            visible: bar.picking
            Layout.fillWidth: bar.narrow
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            text: qsTr("%Ln selected", "", backend.folder.selectedCount)
            color: theme.brightForeground
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        PlainButton {
            visible: bar.picking
            text: qsTr("Select All")
            onClicked: backend.folder.selectAll()
        }
        PlainButton {
            visible: bar.picking
            text: qsTr("Done")
            onClicked: bar.pickingRequested(false)
        }
        IconButton {
            visible: bar.closable
            glyph: "close"
            text: qsTr("Close this pane")
            onClicked: bar.closeRequested()
        }
    }

    // Touch mode's menus: the crumbs … stands for, and a phone's view,
    // sort, hidden files and Select.
    FolioMenu {
        id: hiddenCrumbs
        property var folders: []
        function show(near, hidden) {
            folders = hidden
            popup(near, 0, near.height + 8)
        }
        Repeater {
            model: hiddenCrumbs.folders
            FolioMenuItem {
                required property var modelData
                text: modelData.name
                onTriggered: backend.navigate(modelData.path)
            }
        }
    }
    FolioMenu {
        id: moreMenu
        FolioMenuItem {
            text: bar.viewMode === "grid" ? qsTr("Show as list") : qsTr("Show as grid")
            onTriggered: bar.cycleView()
        }
        SortMenu { title: qsTr("Sort") }
        FolioMenuItem {
            text: backend.folder.showHidden ? qsTr("Hide Hidden Files") : qsTr("Show Hidden Files")
            onTriggered: backend.folder.showHidden = !backend.folder.showHidden
        }
        MenuLine { }
        FolioMenuItem {
            text: qsTr("Select")
            onTriggered: bar.pickingRequested(true)
        }
    }

    // Touch mode: the folders Tab would choose among, under the path being
    // typed, to tap.
    Rectangle {
        id: completions
        readonly property var paths: touch.enabled && bar.editing ? backend.completions(pathField.text) : []
        visible: paths.length > 0
        x: pathField.x + pathField.parent.x
        y: bar.height - 8
        width: pathField.width
        height: Math.min(paths.length, 5) * 44 + 2
        color: theme.background
        border.width: 1
        border.color: Qt.alpha(theme.foreground, 0.16)
        radius: Math.min(6, theme.radius)
        ListView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: completions.paths
            delegate: Item {
                id: completion
                required property string modelData
                width: ListView.view.width
                height: 44
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Math.min(4, theme.radius)
                    color: completionTap.pressed ? Qt.alpha(theme.foreground, 0.10) : "transparent"
                }
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                    text: completion.modelData
                    color: theme.foreground
                    elide: Text.ElideLeft
                }
                // A handler takes no keyboard focus, so the field keeps it.
                TapHandler {
                    id: completionTap
                    onTapped: bar.complete(completion.modelData)
                }
            }
        }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(theme.foreground, 0.12) }
}
