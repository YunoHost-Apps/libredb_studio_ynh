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

## Adding your first connection

The application starts on two sample databases that ship inside it, so you can look around before pointing it at anything real. Add your own from the connections screen. If the database runs on the same server, its host is `127.0.0.1`.
