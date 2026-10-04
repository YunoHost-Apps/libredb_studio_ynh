## Your administrator password

The first run generated one and printed it once. Read it with:

```
grep -A4 'first run' /var/log/__APP__/__APP__.log
```

It was also written to `auth-bootstrap.json` in the app's data directory, with permissions `600`:

```
sudo cat /home/yunohost.app/__APP__/auth-bootstrap.json
```

The account is `admin@libredb.org`. Sign in and change the password from the account menu; the file stays where it is and is ignored once a password is set in the application.

## Nobody is locked out by YunoHost

The permission defaults to `visitors`, because the application does its own authentication. Anyone who reaches the address sees the login screen and nothing more. If you would rather have YunoHost's SSO in front of it as well, change the permission in the admin panel; you will then be asked for two logins rather than one.

## If you connected this server's databases

Then the install set the permission to `admins` instead, because the app holds an administrator account on each local MariaDB and PostgreSQL server. Sign in to YunoHost as an admin, then to LibreDB Studio as `admin@libredb.org`. The sidebar has a YunoHost group: one connection for MariaDB, which reaches every database on it, and one for each PostgreSQL database. They are locked, their passwords never reach the browser, and other LibreDB Studio accounts do not see them. If you open the permission to more than `admins` later, every upgrade and restore warns about it but leaves it as you set it.

## Adding your first connection

The application starts on two sample databases that ship inside it, so you can look around before pointing it at anything real. Add your own from the connections screen. If the database runs on the same server, its host is `127.0.0.1`.
