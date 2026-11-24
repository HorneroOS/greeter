#include "backend.h"

#include "greetd_client.h"
#include "session_model.h"
#include "user_model.h"

#include <QHostInfo>

Backend::Backend(QObject *parent) : QObject(parent)
{
    const QString last = loadLastUser();
    const auto users = discoverUsers();
    for (int i = 0; i < users.size(); ++i) {
        if (users[i].name == last)
            m_lastUserIndex = i;
        m_users.append(QVariantMap {
            { "name", users[i].name },
            { "realName", users[i].realName },
            { "home", users[i].home },
        });
    }

    const auto sessions = discoverSessions();
    for (const DesktopSession &s : sessions) {
        m_sessions.append(QVariantMap {
            { "id", s.id },
            { "name", s.name },
            { "comment", s.comment },
            { "type", s.type },
            { "exec", s.exec },
            { "desktopNames", s.desktopNames },
        });
    }

    m_client = new GreetdClient(this);
    connect(m_client, &GreetdClient::authMessage, this,
            [this](const QString &type, const QString &message) {
        if (type == "info" || type == "error") {
            // Informative messages still need an empty response, but the
            // person should get to read them first: show, then respond().
            m_info = message;
            emit messagesChanged();
        }
        m_promptKind = type;
        m_promptLabel = message;
        emit promptChanged();
    });
    connect(m_client, &GreetdClient::succeeded, this, [this] {
        if (m_state == "authenticating")
            startPendingSession();
        else if (m_state == "starting") {
            saveLastUser(m_pendingUser);
            resetPrompt();
            emit sessionStarted();
        }
    });
    connect(m_client, &GreetdClient::failed, this,
            [this](const QString &errorType, const QString &description) {
        if (errorType == "auth_error")
            ++m_attempts;
        m_error = description.isEmpty() ? errorType : description;
        resetPrompt();
        setState("idle");
        emit messagesChanged();
    });
    connect(m_client, &GreetdClient::transportError, this, [this](const QString &description) {
        m_error = description;
        resetPrompt();
        setState("disconnected");
        emit messagesChanged();
    });
}

QString Backend::hostname() const
{
    return QHostInfo::localHostName();
}

bool Backend::daemonConnected() const
{
    return m_client->isConnected();
}

void Backend::connectDaemon(const QString &socketPath)
{
    if (m_client->connectToDaemon(socketPath))
        setState("idle");
    else
        setState("disconnected");
}

void Backend::begin(const QString &username, int sessionIndex)
{
    if (m_state == "authenticating" || m_state == "starting")
        return;
    m_error.clear();
    m_info.clear();
    m_pendingUser = username;

    m_pendingCmd.clear();
    m_pendingEnv.clear();
    if (sessionIndex >= 0 && sessionIndex < m_sessions.size()) {
        const QVariantMap s = m_sessions[sessionIndex].toMap();
        m_pendingCmd = s.value("exec").toStringList();
        const QString type = s.value("type").toString();
        const QString desktop = s.value("desktopNames").toString().section(';', 0, 0);
        m_pendingEnv << "XDG_SESSION_TYPE=" + (type == "x" ? QStringLiteral("x11") : type);
        m_pendingEnv << "XDG_SESSION_DESKTOP=" + (desktop.isEmpty() ? s.value("id").toString() : desktop);
        m_pendingEnv << "DESKTOP_SESSION=" + s.value("id").toString();
        m_pendingEnv << "XDG_CURRENT_DESKTOP=" + (desktop.isEmpty() ? s.value("name").toString() : desktop);
    }
    setState("authenticating");
    emit messagesChanged();
    m_client->createSession(username);
}

void Backend::respond(const QString &text)
{
    if (m_promptKind == "none")
        return;
    const bool typed = (m_promptKind == "visible" || m_promptKind == "secret");
    m_client->postAuthMessageResponse(text, typed);
    // The next prompt, success or error arrives asynchronously.
    m_promptKind = "none";
    m_promptLabel.clear();
    m_info.clear();
    emit promptChanged();
    emit messagesChanged();
}

void Backend::cancel()
{
    if (m_state != "authenticating")
        return;
    m_client->cancelSession();
    resetPrompt();
    setState("idle");
}

void Backend::startPendingSession()
{
    if (m_pendingCmd.isEmpty()) {
        // No session entries on disk: this is a broken install, not a
        // login failure. Say so instead of starting nothing.
        m_error = "No sessions are installed on this system.";
        resetPrompt();
        setState("idle");
        emit messagesChanged();
        return;
    }
    setState("starting");
    m_client->startSession(m_pendingCmd, m_pendingEnv);
}

void Backend::resetPrompt()
{
    m_promptKind = "none";
    m_promptLabel.clear();
    emit promptChanged();
}

void Backend::setState(const QString &state)
{
    if (m_state == state)
        return;
    m_state = state;
    emit stateChanged();
}
