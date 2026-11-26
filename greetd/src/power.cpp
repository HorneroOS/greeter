#include "power.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

static const QString kService = QStringLiteral("org.freedesktop.login1");
static const QString kPath = QStringLiteral("/org/freedesktop/login1");
static const QString kIface = QStringLiteral("org.freedesktop.login1.Manager");

PowerActions::PowerActions(QObject *parent) : QObject(parent)
{
    refresh();
}

// logind answers Can* with "yes", "no", "na" or "challenge". Only an
// unqualified "yes" is offered: at a greeter there is nobody signed in
// to answer an authorization challenge.
void PowerActions::refresh()
{
    const QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected())
        return;
    QDBusInterface logind(kService, kPath, kIface, bus);
    auto check = [this, &logind](const QString &method, bool *target) {
        const QDBusPendingCall pending = logind.asyncCall(method);
        auto *watcher = new QDBusPendingCallWatcher(pending, this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this,
                [this, watcher, target] {
            const QDBusPendingReply<QString> reply = *watcher;
            const bool allowed =
                reply.isValid() && reply.value() == QLatin1String("yes");
            if (*target != allowed) {
                *target = allowed;
                emit availabilityChanged();
            }
            watcher->deleteLater();
        });
    };
    check(QStringLiteral("CanSuspend"), &m_canSuspend);
    check(QStringLiteral("CanReboot"), &m_canReboot);
    check(QStringLiteral("CanPowerOff"), &m_canPowerOff);
}

void PowerActions::call(const QString &method)
{
    const QDBusConnection bus = QDBusConnection::systemBus();
    if (!bus.isConnected())
        return;
    QDBusInterface logind(kService, kPath, kIface, bus);
    // interactive=false: polkit must not try to prompt on a greeter seat.
    logind.asyncCall(method, false);
}

void PowerActions::suspend() { call("Suspend"); }
void PowerActions::reboot() { call("Reboot"); }
void PowerActions::powerOff() { call("PowerOff"); }
