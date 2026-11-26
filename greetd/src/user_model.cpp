#include "user_model.h"

#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <pwd.h>

namespace {
constexpr int kUidMin = 1000;
constexpr int kUidMax = 60000;

bool isLoginShell(const QString &shell)
{
    return !shell.isEmpty()
        && !shell.endsWith(QLatin1String("nologin"))
        && !shell.endsWith(QLatin1String("false"));
}
} // namespace

QVector<GreeterUser> discoverUsers(const QString &passwdFile)
{
    QVector<GreeterUser> users;
    QSet<QString> seen;

    if (passwdFile.isEmpty() || passwdFile == QLatin1String("/etc/passwd")) {
        setpwent();
        while (const struct passwd *pw = getpwent()) {
            if (pw->pw_uid < static_cast<uid_t>(kUidMin)
                || pw->pw_uid > static_cast<uid_t>(kUidMax))
                continue;
            const QString shell = QString::fromLocal8Bit(pw->pw_shell ? pw->pw_shell : "");
            if (!isLoginShell(shell))
                continue;
            const QString name = QString::fromLocal8Bit(pw->pw_name ? pw->pw_name : "");
            if (name.isEmpty() || seen.contains(name))
                continue;
            seen.insert(name);
            const QString gecos = QString::fromLocal8Bit(pw->pw_gecos ? pw->pw_gecos : "");
            const QString realName = gecos.section(',', 0, 0).trimmed();
            const QString home = QString::fromLocal8Bit(pw->pw_dir ? pw->pw_dir : "");
            users.push_back(GreeterUser { name, realName, home });
        }
        endpwent();
        return users;
    }

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
        if (!ok || uid < kUidMin || uid > kUidMax)
            continue;
        const QString shell = fields[6];
        if (!isLoginShell(shell))
            continue;
        if (fields[0].isEmpty() || seen.contains(fields[0]))
            continue;
        seen.insert(fields[0]);
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
