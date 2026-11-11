#pragma once

#include <QObject>
#include <QString>

// Touch mode: the sizes and the controls a finger needs, on top of the
// window as the keyboard and mouse know it. On when the system has a
// touchscreen, unless folio.conf says `touch=on` or `touch=off`. Off, the
// window is exactly the keyboard-first one.
class Touch : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled CONSTANT)
    // Whether the pointer last used was a mouse (or a touchpad or pen)
    // rather than a finger. Qt passes a finger on to everything that
    // hovers as the mouse's pointer arriving, so in touch mode whatever
    // shows a hover asks this first: a finger has none to show.
    Q_PROPERTY(bool pointing READ pointing NOTIFY pointingChanged)

public:
    // The setting as folio.conf has it, and whether there's a touchscreen;
    // left out, both are read from the system.
    explicit Touch(QObject *parent = nullptr);
    Touch(const QString &setting, bool touchscreen, QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    bool pointing() const { return m_pointing; }

    static bool decide(const QString &setting, bool touchscreen);
    static bool hasTouchscreen();

signals:
    void pointingChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void setPointing(bool pointing);

    bool m_enabled = false;
    bool m_pointing = false;
};
