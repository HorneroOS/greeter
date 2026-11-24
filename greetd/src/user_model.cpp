#include "user_model.h"

#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>

QVector<GreeterUser> discoverUsers(const QString &passwdFile)
{
    QVector<GreeterUser> users;
    QFile file(passwdFile);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return users;
    while (!file.atEnd()) {
        const QStringList fields =
            QString::fromUtf8(file.readLine()).trimmed().split(':');
        // name:passwd:uid:gid:gecos:home:shell
        if (fields.size() != 7)
            continue;
        bool ok = false;
        const int uid = fields[2].toInt(&ok);
        if (!ok || uid < 1000)
            continue;
        const QString shell = fields[6];
        if (shell.endsWith("nologin") || shell.endsWith("false") || shell.isEmpty())
            continue;
        const QString realName = fields[4].section(',', 0, 0).trimmed();
        users.push_back(GreeterUser { fields[0], realName, fields[5] });
    }
    return users;
}

QString lastUserFilePath()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    return base + "/hornero-greetd-greeter/last-user";
}

QString loadLastUser()
{
    QFile file(lastUserFilePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

void saveLastUser(const QString &name)
{
    if (name.isEmpty())
        return;
    const QString path = lastUserFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(name.toUtf8());
        file.write("\n");
        file.commit();
    }
}
