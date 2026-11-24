#pragma once

#include <QObject>
#include <QByteArray>

class QLocalSocket;

// Speaks the greetd IPC protocol (greetd-ipc(7)): each message is a
// 32-bit native-endian byte length followed by that many bytes of
// UTF-8 JSON, over the Unix socket whose path greetd exports as
// GREETD_SOCK. The client is asynchronous: every request is answered
// through exactly one of the response signals below.
class GreetdClient : public QObject {
    Q_OBJECT
public:
    explicit GreetdClient(QObject *parent = nullptr);

    // Socket path resolution: explicit override wins, otherwise the
    // GREETD_SOCK environment variable greetd sets for its greeter.
    bool connectToDaemon(const QString &socketPath = QString());
    bool isConnected() const;

    // Requests (see greetd-ipc(7)).
    void createSession(const QString &username);
    void postAuthMessageResponse(const QString &response, bool hasResponse);
    void startSession(const QStringList &cmd, const QStringList &env);
    void cancelSession();

    // Discrete, order-preserving pump used by the headless self-test:
    // returns true when a complete message was decoded and emitted.
    bool decodeOne();

signals:
    // "visible", "secret", "info" or "error" plus the message text.
    void authMessage(const QString &messageType, const QString &message);
    void succeeded();
    void failed(const QString &errorType, const QString &description);
    void transportError(const QString &description);

private:
    void sendMessage(const QByteArray &payload);
    void onReadyRead();
    void emitMessage(const QByteArray &payload);

    QLocalSocket *m_sock = nullptr;
    QByteArray m_rx;
};
