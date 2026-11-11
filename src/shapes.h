#pragma once

#include <QColor>
#include <QImage>
#include <QPainterPath>
#include <QQuickImageProvider>

// Folio's line icons and folder cards as pictures, for Qt's software
// renderer (QT_QUICK_BACKEND=software, or no GPU). There a Shape is painted
// past the edge of the view that clips it, so a row scrolling out of a list
// left its icon drawn over the bar above; a picture is clipped as it should
// be. Glyph.qml and FileTile.qml ask for one only on that renderer, by a
// URL that says the whole drawing:
//
//   image://shape/WIDTH/HEIGHT/STROKE/ROUND/FILL/LINE/PATH
//
// the box the path is drawn in and its stroke's width, in the path's own
// units; 1 for round ends and joins, 0 for square ones; the fill's and the
// line's colors as hex without the #, or "none"; and the SVG path. The
// picture comes at the size asked for, the drawing scaled to fill it.
class ShapeProvider : public QQuickImageProvider {
public:
    ShapeProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // The path data Folio's drawings use: M L H V Q A Z, absolute or
    // relative, a command's letter left out when it repeats.
    static QPainterPath parse(const QString &svg);
    static QImage draw(const QPainterPath &path, const QSizeF &box, qreal stroke, bool round, const QColor &fill,
                       const QColor &line, const QSize &size);
};
