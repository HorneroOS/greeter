#pragma once

#include <QString>
#include <QVector>

struct GreeterUser {
    QString name;     // login name
    QString realName; // GECOS full name, may be empty
    QString home;
};

// Human accounts from the system password database: UID >= 1000 with a
// real login shell (anything but nologin/false). Reading /etc/passwd is
// what every minimal greeter does; it needs no daemon and no accountsservice.
QVector<GreeterUser> discoverUsers(const QString &passwdFile = QStringLiteral("/etc/passwd"));

// The last successful login, persisted inside the greeter user's own
// XDG cache so the channels can pre-tune last time's account. Never
// load-bearing: any failure just falls back to the first account.
QString lastUserFilePath();
QString loadLastUser();
void saveLastUser(const QString &name);
