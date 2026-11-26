#pragma once

#include <QString>
#include <QStringList>
#include <QVector>

// One launchable desktop session discovered from the standard
// <datadir>/{wayland,x}-sessions/*.desktop entries. greetd starts the
// session with an argv vector, so Exec= is tokenised once, here.
struct DesktopSession {
    QString id;            // desktop file base name ("hyprland")
    QString name;          // display Name=
    QString comment;       // Comment=
    QString type;          // "wayland" or "x"
    QStringList exec;      // tokenised Exec=
    QString desktopNames;  // DesktopNames= (for XDG_SESSION_DESKTOP)
    QString desktopFile;   // absolute path, for provenance in logs
};

// Extra directories may be injected for tests; by default the XDG data
// dirs are searched in precedence order and the first entry with a
// given id wins, matching freedesktop session lookup rules. X11 sessions
// (/usr/share/xsessions) are excluded by default under greetd.
QVector<DesktopSession> discoverSessions(const QStringList &extraDirs = {},
                                         bool includeX11 = false);
