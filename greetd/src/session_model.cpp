#include "session_model.h"

#include <QDir>
#include <QFile>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <algorithm>

// Split a desktop-entry Exec= line into argv. Field codes (%f, %u, %%...)
// mean nothing for a session starter, so they are dropped; quoting and
// backslash escapes follow the desktop entry specification.
static QStringList splitExec(const QString &exec)
{
    QStringList out;
    QString current;
    bool quoted = false, escaped = false, any = false;
    for (const QChar ch : exec) {
        if (escaped) {
            current += ch;
            escaped = false;
            any = true;
        } else if (ch == '\\' && quoted) {
            escaped = true;
        } else if (ch == '"') {
            quoted = !quoted;
            any = true;
        } else if (!quoted && ch == ' ') {
            if (any || !current.isEmpty())
                out << current;
            current.clear();
            any = false;
        } else {
            current += ch;
            any = true;
        }
    }
    if (any || !current.isEmpty())
        out << current;

    QStringList cleaned;
    for (const QString &arg : out) {
        if (arg.size() == 2 && arg[0] == '%' && arg[1] != '%')
            continue; // bare field code: no file/URL is being opened
        QString a = arg;
        a.replace("%%", "%");
        cleaned << a;
    }
    return cleaned;
}

// Parse just the [Desktop Entry] group, first definition of a key wins.
static QHash<QString, QString> readDesktopEntry(const QString &path)
{
    QHash<QString, QString> keys;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return keys;
    QTextStream in(&file);
    bool inGroup = false;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.startsWith('[')) {
            inGroup = line == "[Desktop Entry]";
            continue;
        }
        if (!inGroup || line.isEmpty() || line.startsWith('#'))
            continue;
        const int eq = line.indexOf('=');
        if (eq < 1)
            continue;
        const QString key = line.left(eq);
        // Localised variants (Name[es]=...) never replace the base key.
        if (!key.contains('[') && !keys.contains(key))
            keys.insert(key, line.mid(eq + 1));
    }
    return keys;
}

static bool isExperimentalSession(const DesktopSession &s)
{
    return s.id.contains(QLatin1String("experimental"), Qt::CaseInsensitive)
        || s.name.contains(QLatin1String("experimental"), Qt::CaseInsensitive)
        || s.comment.contains(QLatin1String("experimental"), Qt::CaseInsensitive);
}

static int sessionPriority(const DesktopSession &s)
{
    const int base = isExperimentalSession(s) ? 4 : 0;
    if (s.id.contains(QLatin1String("hornero"), Qt::CaseInsensitive)
        || s.name.contains(QLatin1String("hornero"), Qt::CaseInsensitive))
        return base;
    if (s.id.contains(QLatin1String("hyprland"), Qt::CaseInsensitive)
        || s.name.contains(QLatin1String("hyprland"), Qt::CaseInsensitive))
        return base + 1;
    return base + (s.type == QLatin1String("wayland") ? 2 : 3);
}

QVector<DesktopSession> discoverSessions(const QStringList &extraDirs, bool includeX11)
{
    QStringList dataDirs = extraDirs;
    dataDirs += QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);

    const QStringList kinds = includeX11
        ? QStringList { QStringLiteral("wayland"), QStringLiteral("x") }
        : QStringList { QStringLiteral("wayland") };

    QVector<DesktopSession> sessions;
    QSet<QString> seen; // "<type>/<id>": first data dir wins

    for (const QString &base : dataDirs) {
        for (const QString &kind : kinds) {
            const QString dirName = kind == "x" ? "xsessions" : "wayland-sessions";
            const QDir dir(base + '/' + dirName);
            const QStringList files = dir.entryList({ "*.desktop" }, QDir::Files, QDir::Name);
            for (const QString &fileName : files) {
                const QString id = fileName.chopped(8); // strip ".desktop"
                const QString probe = kind + '/' + id;
                if (seen.contains(probe))
                    continue;
                const auto keys = readDesktopEntry(dir.absoluteFilePath(fileName));
                if (keys.value("Type") != "Application")
                    continue;
                if (keys.value("Hidden") == "true" || keys.value("NoDisplay") == "true")
                    continue;
                const QStringList exec = splitExec(keys.value("Exec"));
                if (exec.isEmpty())
                    continue;
                // TryExec names a binary that must exist for the
                // session to be offered (desktop entry spec). Without
                // this check, e.g. hyprland's uwsm-managed entry is
                // offered on systems where uwsm is not installed and
                // the login silently bounces back to the greeter.
                const QString tryExec = keys.value("TryExec").trimmed();
                if (!tryExec.isEmpty()
                    && QStandardPaths::findExecutable(tryExec).isEmpty())
                    continue;
                seen.insert(probe);
                sessions.push_back(DesktopSession {
                    id,
                    keys.value("Name", id),
                    keys.value("Comment"),
                    kind,
                    exec,
                    keys.value("DesktopNames"),
                    dir.absoluteFilePath(fileName),
                });
            }
        }
    }

    // Stable entries first (HorneroOS Desktop ahead of Hyprland, then other
    // Wayland/X11 sessions), experimental ones last (mirrors the SDDM
    // theme): an experimental session must never become the default
    // just because its file name sorts early.
    std::stable_sort(sessions.begin(), sessions.end(), [](const DesktopSession &a, const DesktopSession &b) {
        return sessionPriority(a) < sessionPriority(b);
    });
    return sessions;
}
