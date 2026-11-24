#pragma once

#include <QObject>

// Power actions through logind's D-Bus interface — the same authority
// every display manager uses. Availability comes from logind's own
// Can* replies, so the UI hides actions the seat does not allow
// instead of promising and failing at click time.
class PowerActions : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool canSuspend READ canSuspend NOTIFY availabilityChanged)
    Q_PROPERTY(bool canReboot READ canReboot NOTIFY availabilityChanged)
    Q_PROPERTY(bool canPowerOff READ canPowerOff NOTIFY availabilityChanged)

public:
    explicit PowerActions(QObject *parent = nullptr);

    bool canSuspend() const { return m_canSuspend; }
    bool canReboot() const { return m_canReboot; }
    bool canPowerOff() const { return m_canPowerOff; }

    Q_INVOKABLE void suspend();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void powerOff();

signals:
    void availabilityChanged();

private:
    void refresh();
    void call(const QString &method);

    bool m_canSuspend = false;
    bool m_canReboot = false;
    bool m_canPowerOff = false;
};
