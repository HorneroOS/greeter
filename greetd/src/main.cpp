#include "backend.h"
#include "power.h"

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

// hornero-greetd-greeter: a graphical greetd greeter on Hornero Signal.
//
// greetd runs us as its greeter program (normally inside `cage`, a
// kiosk Wayland compositor) and exports GREETD_SOCK. For development
// the window can run anywhere: --socket points at any greetd-compatible
// endpoint (including the test doubles under tests/), and without a
// socket the UI still loads in its disconnected state.
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("hornero-greetd-greeter"));
    QGuiApplication::setOrganizationName(QStringLiteral("HorneroOS"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("HorneroOS greetd greeter"));
    parser.addHelpOption();
    const QCommandLineOption socketOpt(
        QStringLiteral("socket"),
        QStringLiteral("greetd socket path (default: $GREETD_SOCK)"), "path");
    parser.addOption(socketOpt);
    const QCommandLineOption shotOpt(
        QStringLiteral("screenshot"),
        QStringLiteral("render one frame to this PNG and exit (preview/QA)"), "path");
    parser.addOption(shotOpt);
    parser.process(app);

    Backend backend;
    PowerActions power;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("power"), &power);
    engine.load(QUrl(QStringLiteral("qrc:///Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    // Connect after the window exists so early auth prompts land on a
    // visible surface.
    backend.connectDaemon(parser.value(socketOpt));

    const QString shot = parser.value(shotOpt);
    if (!shot.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(700, &app, [&app, window, shot] {
            const QImage frame = window ? window->grabWindow() : QImage();
            app.exit(frame.save(shot) ? 0 : 2);
        });
    }

    return app.exec();
}
