#include "shapes.h"

#include <QPainter>
#include <QUrl>
#include <QtMath>

ShapeProvider::ShapeProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

// An SVG arc from the path's current point to `to`, as the ellipse's arc
// QPainterPath draws: the center worked out from the two ends, as the SVG
// specification's notes on implementation give it. Folio's arcs are never
// tilted, so the x axis rotation is taken as none.
static void arcTo(QPainterPath &path, qreal rx, qreal ry, bool large, bool sweep, const QPointF &to) {
    const QPointF from = path.currentPosition();
    rx = qAbs(rx);
    ry = qAbs(ry);
    if (from == to)
        return;
    if (rx == 0 || ry == 0) {
        path.lineTo(to);
        return;
    }
    const qreal x = (from.x() - to.x()) / 2;
    const qreal y = (from.y() - to.y()) / 2;
    // Radii too small to reach are scaled up until they do.
    const qreal reach = x * x / (rx * rx) + y * y / (ry * ry);
    if (reach > 1) {
        rx *= qSqrt(reach);
        ry *= qSqrt(reach);
    }
    const qreal over = rx * rx * y * y + ry * ry * x * x;
    const qreal factor = (large != sweep ? 1 : -1) * qSqrt(qMax(0.0, (rx * rx * ry * ry - over) / over));
    const qreal cx = factor * rx * y / ry;
    const qreal cy = -factor * ry * x / rx;
    const QPointF center(cx + (from.x() + to.x()) / 2, cy + (from.y() + to.y()) / 2);
    const qreal start = qAtan2((y - cy) / ry, (x - cx) / rx);
    qreal turn = qAtan2((-y - cy) / ry, (-x - cx) / rx) - start;
    if (!sweep && turn > 0)
        turn -= 2 * M_PI;
    else if (sweep && turn < 0)
        turn += 2 * M_PI;
    // SVG turns clockwise with y pointing down; QPainterPath counts the
    // other way round.
    path.arcTo(QRectF(center.x() - rx, center.y() - ry, 2 * rx, 2 * ry), -qRadiansToDegrees(start),
               -qRadiansToDegrees(turn));
}

QPainterPath ShapeProvider::parse(const QString &svg) {
    QPainterPath path;
    qsizetype at = 0;
    auto blank = [&] {
        while (at < svg.size() && (svg.at(at).isSpace() || svg.at(at) == ','))
            ++at;
    };
    // The next number: digits, one point, a sign only in front, an exponent.
    auto number = [&](bool *ok) {
        blank();
        const qsizetype from = at;
        if (at < svg.size() && (svg.at(at) == '-' || svg.at(at) == '+'))
            ++at;
        bool point = false;
        while (at < svg.size()) {
            const QChar c = svg.at(at);
            if (c.isDigit()) {
                ++at;
            } else if (c == '.' && !point) {
                point = true;
                ++at;
            } else if ((c == 'e' || c == 'E') && at + 1 < svg.size()
                       && (svg.at(at + 1).isDigit() || svg.at(at + 1) == '-' || svg.at(at + 1) == '+')) {
                at += 2;
            } else {
                break;
            }
        }
        return svg.mid(from, at - from).toDouble(ok);
    };

    QChar command;
    QPointF start;
    while (true) {
        blank();
        if (at >= svg.size())
            break;
        if (svg.at(at).isLetter())
            command = svg.at(at++);
        else if (command.isNull())
            break;
        const bool relative = command.isLower();
        const QPointF origin = relative ? path.currentPosition() : QPointF();
        bool ok = true;
        auto point = [&] {
            const qreal x = number(&ok);
            const qreal y = ok ? number(&ok) : 0;
            return origin + QPointF(x, y);
        };
        switch (command.toUpper().unicode()) {
        case 'M': {
            const QPointF to = point();
            if (!ok)
                return path;
            path.moveTo(to);
            start = to;
            // More pairs after a move are lines.
            command = relative ? 'l' : 'L';
            break;
        }
        case 'L': {
            const QPointF to = point();
            if (!ok)
                return path;
            path.lineTo(to);
            break;
        }
        case 'H': {
            const qreal x = number(&ok);
            if (!ok)
                return path;
            path.lineTo(origin.x() + x, path.currentPosition().y());
            break;
        }
        case 'V': {
            const qreal y = number(&ok);
            if (!ok)
                return path;
            path.lineTo(path.currentPosition().x(), origin.y() + y);
            break;
        }
        case 'Q': {
            const QPointF control = point();
            const QPointF to = ok ? point() : QPointF();
            if (!ok)
                return path;
            path.quadTo(control, to);
            break;
        }
        case 'A': {
            const qreal rx = number(&ok);
            const qreal ry = ok ? number(&ok) : 0;
            if (ok)
                number(&ok); // The tilt, which Folio's arcs don't have.
            const bool large = ok && number(&ok) != 0;
            const bool sweep = ok && number(&ok) != 0;
            const QPointF to = ok ? point() : QPointF();
            if (!ok)
                return path;
            arcTo(path, rx, ry, large, sweep, to);
            break;
        }
        case 'Z':
            path.closeSubpath();
            path.moveTo(start);
            break;
        default:
            return path; // Not a command these drawings use.
        }
    }
    return path;
}

QImage ShapeProvider::draw(const QPainterPath &path, const QSizeF &box, qreal stroke, bool round, const QColor &fill,
                           const QColor &line, const QSize &size) {
    QImage image(size, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    if (box.isEmpty() || size.isEmpty())
        return image;
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.scale(size.width() / box.width(), size.height() / box.height());
    painter.setBrush(fill.isValid() ? QBrush(fill) : Qt::NoBrush);
    if (line.isValid() && stroke > 0)
        painter.setPen(QPen(line, stroke, Qt::SolidLine, round ? Qt::RoundCap : Qt::SquareCap,
                            round ? Qt::RoundJoin : Qt::MiterJoin));
    else
        painter.setPen(Qt::NoPen);
    painter.drawPath(path);
    return image;
}

QImage ShapeProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    // WIDTH/HEIGHT/STROKE/ROUND/FILL/LINE/PATH; the path may hold anything.
    const QStringList parts = id.split('/');
    if (parts.size() < 7)
        return {};
    const QSizeF box(parts.at(0).toDouble(), parts.at(1).toDouble());
    auto color = [](const QString &hex) { return hex == "none" ? QColor() : QColor('#' + hex); };
    const QString path = QUrl::fromPercentEncoding(parts.mid(6).join('/').toUtf8());
    const QSize pixels = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : box.toSize();
    const QImage image = draw(parse(path), box, parts.at(2).toDouble(), parts.at(3) == "1", color(parts.at(4)),
                              color(parts.at(5)), pixels);
    if (size)
        *size = image.size();
    return image;
}
