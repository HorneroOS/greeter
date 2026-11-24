#include "power.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>

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
    auto check = [&logind](const QString &method) {
        const QDBusReply<QString> reply = logind.call(QDBus::BlockWithGui, method);
        return reply.isValid() && reply.value() == "yes";
    };
    m_canSuspend = check("CanSuspend");
    m_canReboot = check("CanReboot");
    m_canPowerOff = check("CanPowerOff");
    emit availabilityChanged();
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
