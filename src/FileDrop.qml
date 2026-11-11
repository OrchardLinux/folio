import QtQuick

// Somewhere dragged files can be let go: a folder, which takes them (moved
// from its own drive, copied from another), or the trash. A drag from
// another app or by the mouse carries its files as URLs. A finger's drag
// stays inside the window, and its source holds them instead.
DropArea {
    id: area

    // The folder a drop goes into.
    property string folder
    // A drop here trashes the files instead.
    property bool trashes: false
    // How a finger's drag names this place: "Move to Pictures".
    property string name: folder.slice(folder.lastIndexOf("/") + 1) || folder
    // What a finger's drag held here for a second does, so it can go deeper
    // or higher: open the folder. Null where there's nothing to open.
    property var spring: () => backend.navigate(folder)
    // Only opens, for a finger's drag on its way elsewhere: a drop here
    // does nothing.
    property bool opensOnly: false

    // A list or grid whose items lie over this area, for an area under a
    // view's items: where a folder item lies, it takes the drop itself or
    // refuses it, and this refuses too rather than catch the drop as it
    // falls through.
    property Item items: null

    keys: ["text/uri-list"]

    function byFinger(event) { return !!event.source && event.source.urls !== undefined }
    function urlsOf(event) { return byFinger(event) ? event.source.urls : event.urls }
    function overFolder(event) {
        if (!items)
            return false
        const at = area.mapToItem(items.contentItem, event.x, event.y)
        const item = items.itemAt(at.x, at.y)
        return !!item && !!item.isDir
    }
    function takes(event) {
        return opensOnly ? byFinger(event)
             : trashes ? event.hasUrls || urlsOf(event).length > 0
             : !overFolder(event) && fileOps.canDrop(urlsOf(event), folder)
    }

    onEntered: (drag) => { drag.accepted = takes(drag) }
    onPositionChanged: (drag) => { if (items) drag.accepted = takes(drag) }
    onDropped: (drop) => {
        if (opensOnly || !takes(drop))
            return
        if (trashes)
            fileOps.trash(fileOps.localPaths(urlsOf(drop)))
        else
            fileOps.dropInto(urlsOf(drop), folder)
        drop.accept(Qt.MoveAction)
    }
}
