#include "touch.h"

#include <QCoreApplication>
#include <QInputDevice>
#include <QMouseEvent>
#include <QSettings>

Touch::Touch(QObject *parent) : Touch(QSettings().value("touch").toString(), hasTouchscreen(), parent) {}

Touch::Touch(const QString &setting, bool touchscreen, QObject *parent)
    : QObject(parent), m_enabled(decide(setting, touchscreen)) {
    // Every window's touches and mouse moves pass here first.
    if (m_enabled && QCoreApplication::instance())
        QCoreApplication::instance()->installEventFilter(this);
}

bool Touch::eventFilter(QObject *, QEvent *event) {
    switch (event->type()) {
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
        setPointing(false);
        break;
    case QEvent::MouseMove:
    case QEvent::MouseButtonPress: {
        // The mouse itself, not what Qt makes of a finger nobody took.
        const auto *mouse = static_cast<QMouseEvent *>(event);
        if (mouse->source() == Qt::MouseEventNotSynthesized
            && mouse->pointingDevice()->type() != QInputDevice::DeviceType::TouchScreen)
            setPointing(true);
        break;
    }
    default:
        break;
    }
    return false;
}

void Touch::setPointing(bool pointing) {
    if (m_pointing == pointing)
        return;
    m_pointing = pointing;
    emit pointingChanged();
}

bool Touch::decide(const QString &setting, bool touchscreen) {
    // QSettings reads a bare on or off as text, true or false the same way.
    const QString value = setting.trimmed().toLower();
    if (value == "on" || value == "true")
        return true;
    if (value == "off" || value == "false")
        return false;
    return touchscreen;
}

bool Touch::hasTouchscreen() {
    const auto devices = QInputDevice::devices();
    for (const QInputDevice *device : devices)
        if (device->type() == QInputDevice::DeviceType::TouchScreen)
            return true;
    return false;
}
