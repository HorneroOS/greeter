#include "greetd_client.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <cstring>

// greetd caps messages at 64 KiB; anything larger is a protocol fault,
// never something to keep buffering.
static constexpr quint32 kMaxMessageSize = 65536;

GreetdClient::GreetdClient(QObject *parent) : QObject(parent)
{
    m_sock = new QLocalSocket(this);
    connect(m_sock, &QLocalSocket::readyRead, this, &GreetdClient::onReadyRead);
    connect(m_sock, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        emit transportError(m_sock->errorString());
    });
    connect(m_sock, &QLocalSocket::disconnected, this, [this] {
        if (m_sock->state() == QLocalSocket::UnconnectedState)
            emit transportError(QStringLiteral("greetd closed the connection"));
    });
}

bool GreetdClient::connectToDaemon(const QString &socketPath)
{
    QString path = socketPath;
    if (path.isEmpty())
        path = QString::fromUtf8(qgetenv("GREETD_SOCK"));
    if (path.isEmpty()) {
        emit transportError(QStringLiteral("GREETD_SOCK is not set"));
        return false;
    }
    m_sock->connectToServer(path);
    if (!m_sock->waitForConnected(3000)) {
        emit transportError(m_sock->errorString());
        return false;
    }
    return true;
}

bool GreetdClient::isConnected() const
{
    return m_sock->state() == QLocalSocket::ConnectedState;
}

static QByteArray toJson(const QJsonObject &obj)
{
    return QJsonDocument(obj).toJson(QJsonDocument::Compact);
}

void GreetdClient::createSession(const QString &username)
{
    sendMessage(toJson({ { "type", "create_session" }, { "username", username } }));
}

void GreetdClient::postAuthMessageResponse(const QString &response, bool hasResponse)
{
    QJsonObject obj { { "type", "post_auth_message_response" } };
    // greetd distinguishes an absent answer (info/error prompts) from an
    // empty one; only include the field when the user actually typed.
    if (hasResponse)
        obj.insert("response", response);
    else
        obj.insert("response", QJsonValue::Null);
    sendMessage(toJson(obj));
}

void GreetdClient::startSession(const QStringList &cmd, const QStringList &env)
{
    QJsonArray cmdArr, envArr;
    for (const QString &c : cmd) cmdArr.append(c);
    for (const QString &e : env) envArr.append(e);
    sendMessage(toJson({ { "type", "start_session" }, { "cmd", cmdArr }, { "env", envArr } }));
}

void GreetdClient::cancelSession()
{
    sendMessage(toJson({ { "type", "cancel_session" } }));
}

void GreetdClient::sendMessage(const QByteArray &payload)
{
    quint32 len = static_cast<quint32>(payload.size());
    QByteArray frame(4, Qt::Uninitialized);
    std::memcpy(frame.data(), &len, 4); // native byte order, per spec
    frame += payload;
    m_sock->write(frame);
    m_sock->flush();
}

void GreetdClient::onReadyRead()
{
    m_rx += m_sock->readAll();
    while (decodeOne()) {
    }
}

bool GreetdClient::decodeOne()
{
    if (m_rx.size() < 4)
        return false;
    quint32 len = 0;
    std::memcpy(&len, m_rx.constData(), 4);
    if (len > kMaxMessageSize) {
        m_rx.clear();
        emit transportError(QStringLiteral("greetd sent an oversized message"));
        return false;
    }
    if (m_rx.size() < 4 + int(len))
        return false;
    QByteArray payload = m_rx.mid(4, int(len));
    m_rx.remove(0, 4 + int(len));
    emitMessage(payload);
    return true;
}

void GreetdClient::emitMessage(const QByteArray &payload)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        emit transportError(QStringLiteral("unparseable greetd message"));
        return;
    }
    const QJsonObject obj = doc.object();
    const QString type = obj.value("type").toString();
    if (type == "auth_message") {
        emit authMessage(obj.value("auth_message_type").toString(),
                         obj.value("auth_message").toString());
    } else if (type == "success") {
        emit succeeded();
    } else if (type == "error") {
        emit failed(obj.value("error_type").toString(), obj.value("description").toString());
    } else {
        emit transportError(QStringLiteral("unknown greetd message type: %1").arg(type));
    }
}
