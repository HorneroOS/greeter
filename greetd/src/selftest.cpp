#include "greetd_client.h"
#include "session_model.h"
#include "user_model.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTextStream>
#include <QTimer>

// Headless protocol driver used by tests/test_greetd_protocol.py: it
// runs one scripted conversation against any greetd-compatible socket
// and prints one JSON object per event, so the real client code path —
// framing, parsing, state handling — can be verified without PAM or a
// display. Usage:
//
//   hornero-greetd-selftest <socket-path> <username> [answer1 answer2 ...]
//
// Answers are consumed in order for visible/secret prompts; info/error
// prompts are acknowledged with an absent response. On auth success it
// starts the literal session `true` (the test double never executes).
//
// With `--retry` as the last argument, an auth_error does not end the
// run: the driver mirrors Backend::begin-after-failure and issues a
// second create_session on the same connection (regression coverage
// for the retry-after-wrong-password path).

static void emitEvent(const QJsonObject &obj)
{
    QTextStream stream(stdout);
    stream << QJsonDocument(obj).toJson(QJsonDocument::Compact) << '\n';
    stream.flush();
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 3)
        return 2;

    GreetdClient client;
    QStringList answers = args.mid(3);
    const bool retry = answers.contains("--retry");
    answers.removeAll("--retry");
    bool authDone = false;
    bool retried = false;
    bool cancelAckPending = false;

    QObject::connect(&client, &GreetdClient::authMessage, &client,
                     [&](const QString &type, const QString &message) {
        emitEvent({ { "event", "auth_message" }, { "kind", type }, { "message", message } });
        const bool typed = (type == "visible" || type == "secret");
        const QString answer = typed && !answers.isEmpty() ? answers.takeFirst() : QString();
        client.postAuthMessageResponse(answer, typed);
    });
    QObject::connect(&client, &GreetdClient::succeeded, &client, [&] {
        if (cancelAckPending) {
            // The cancel was acknowledged: greetd has dropped the
            // failed session-under-configuration, so a fresh
            // create_session is accepted again.
            cancelAckPending = false;
            emitEvent({ { "event", "cancel_ack" } });
            client.createSession(args.at(2));
        } else if (!authDone) {
            authDone = true;
            emitEvent({ { "event", "auth_success" } });
            client.startSession({ "true" }, { "XDG_SESSION_TYPE=wayland" });
        } else {
            emitEvent({ { "event", "session_started" } });
            app.exit(0);
        }
    });
    QObject::connect(&client, &GreetdClient::failed, &client,
                     [&](const QString &errorType, const QString &description) {
        emitEvent({ { "event", "error" },
                    { "error_type", errorType },
                    { "description", description } });
        if (retry && !retried && errorType == "auth_error") {
            // Mirror Backend: greetd keeps the failed session under
            // configuration until cancelled, so cancel first and only
            // re-create once the cancel is acknowledged.
            retried = true;
            cancelAckPending = true;
            emitEvent({ { "event", "retrying" } });
            client.cancelSession();
            return;
        }
        app.exit(0); // an auth failure is a complete, valid conversation
    });
    QObject::connect(&client, &GreetdClient::transportError, &client,
                     [&](const QString &description) {
        emitEvent({ { "event", "transport_error" }, { "description", description } });
        app.exit(3);
    });

    QTimer::singleShot(8000, &app, [&app] {
        emitEvent({ { "event", "timeout" } });
        app.exit(4);
    });

    if (!client.connectToDaemon(args.at(1)))
        return 3;
    client.createSession(args.at(2));
    return app.exec();
}
