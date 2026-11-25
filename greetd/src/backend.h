#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class GreetdClient;

// The single object QML talks to. It owns the greetd conversation state
// machine:
//
//   idle --begin()--> authenticating --(prompts answered)--> starting
//        --(auth error)--> idle (error shown, attempts counted)
//
// greetd/PAM may ask any number of questions (password, OTP, fingerprint
// notices...); every one surfaces as `promptKind` != none with a label,
// and `respond()` posts the answer. Nothing here shells out: sessions
// come from the desktop-entry model, power goes through PowerActions.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString hostname READ hostname CONSTANT)
    Q_PROPERTY(QVariantList users READ users CONSTANT)
    Q_PROPERTY(QVariantList sessions READ sessions CONSTANT)
    Q_PROPERTY(int lastUserIndex READ lastUserIndex CONSTANT)
    Q_PROPERTY(QString promptKind READ promptKind NOTIFY promptChanged)   // none|visible|secret|info|error
    Q_PROPERTY(QString promptLabel READ promptLabel NOTIFY promptChanged)
    Q_PROPERTY(QString infoMessage READ infoMessage NOTIFY messagesChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY messagesChanged)
    Q_PROPERTY(int failedAttempts READ failedAttempts NOTIFY messagesChanged)
    Q_PROPERTY(bool lastFailureWasAuth READ lastFailureWasAuth NOTIFY messagesChanged)
    Q_PROPERTY(bool daemonConnected READ daemonConnected NOTIFY stateChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QString state() const { return m_state; }
    QString hostname() const;
    QVariantList users() const { return m_users; }
    QVariantList sessions() const { return m_sessions; }
    int lastUserIndex() const { return m_lastUserIndex; }
    QString promptKind() const { return m_promptKind; }
    QString promptLabel() const { return m_promptLabel; }
    QString infoMessage() const { return m_info; }
    QString errorMessage() const { return m_error; }
    int failedAttempts() const { return m_attempts; }
    bool lastFailureWasAuth() const { return m_lastFailureWasAuth; }
    bool daemonConnected() const;

    // Begin authenticating `username`; on success start session `index`
    // into the sessions list. Synchronous field validation stays in QML.
    Q_INVOKABLE void begin(const QString &username, int sessionIndex);
    // Answer the current prompt. For info/error prompts pass anything;
    // the field is omitted on the wire, as greetd expects.
    Q_INVOKABLE void respond(const QString &text);
    // Abort the in-flight attempt (Escape during prompts) and reset.
    Q_INVOKABLE void cancel();
    // Terminal signal QML should treat as "greetd will replace us soon".
    Q_INVOKABLE void connectDaemon(const QString &socketPath = QString());

signals:
    void stateChanged();
    void promptChanged();
    void messagesChanged();
    void sessionStarted(); // greetd accepted; the greeter should just wait

private:
    void setState(const QString &state);
    void resetPrompt();
    void startPendingSession();

    GreetdClient *m_client = nullptr;
    // Honest initial state: nothing is reachable until connectDaemon
    // actually speaks to greetd.
    QString m_state = QStringLiteral("disconnected");
    QString m_promptKind = QStringLiteral("none");
    QString m_promptLabel;
    QString m_info;
    QString m_error;
    int m_attempts = 0;
    bool m_lastFailureWasAuth = false;
    QString m_pendingUser;
    QStringList m_pendingCmd;
    QStringList m_pendingEnv;
    QVariantList m_users;
    QVariantList m_sessions;
    int m_lastUserIndex = 0;
};
