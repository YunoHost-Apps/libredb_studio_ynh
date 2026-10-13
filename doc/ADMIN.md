## Where its state lives

Everything the application generates is in one directory: the SQLite store that holds your saved connections, the sample databases, and `auth-bootstrap.json` with the credentials from the first run. That directory is backed up with the app and survives an upgrade, which replaces the program but not the data.

## Changing the configuration

The environment file is `.env` in the install directory. It is rewritten from the package template on every upgrade, so an edit there does not survive one. The values it sets are the port, the bind address, the storage path and the signing secret, and, when this server's databases are connected, the seed file path and the passwords of the two database accounts.

The signing secret is kept in the app's YunoHost settings rather than generated at runtime, so an upgrade or a restore does not log everybody out.

## This server's databases

With the install question on, the package creates `__APP___admin` on each running local MariaDB (all privileges, with grant option) and PostgreSQL (superuser). Their passwords are the app settings `mysql_admin_pwd` and `psql_admin_pwd`, and they reach the service through `.env`. The package writes `/etc/__APP__/seed-connections.yaml`, which lists the connections and names those passwords as `${LIBREDB_YNH_MYSQL_PWD}` and `${LIBREDB_YNH_PSQL_PWD}` without holding them, and points `SEED_CONFIG_PATH` at it. The MariaDB connection opens on the read-only `information_schema`, so a statement typed without a database name cannot land in the grant tables; the object browser still lists every database.

The list is rebuilt on every upgrade. To pick up a server or a database added since, run:

```
yunohost app upgrade __APP__ --force
```

To turn it on after the install, or off, set the setting and run the same command:

```
yunohost app setting __APP__ seed_databases -v 1
yunohost app upgrade __APP__ --force
```

Turning it off drops both accounts and the file. Objects the PostgreSQL account created are handed to `postgres`, not deleted. The permission is set to `admins` only by an install with the question on. An upgrade or a restore leaves it as you set it and warns when it is open to more than `admins` while the accounts exist, so if you turn the feature on after the install, limit the permission yourself:

```
yunohost user permission update __APP__.main --add admins --remove visitors all_users
```

## Reading the logs

```
yunohost service log __APP__
```

The service writes to `/var/log/__APP__/__APP__.log`, which is rotated. That is
the only place its output goes: `journalctl -u __APP__` shows the unit starting
and stopping but carries none of the application's own lines, because the unit
sends stdout to the file rather than to the journal. It is the file that the
first-run password is in.

## What it can reach

The service listens on loopback only; nginx is the one thing in front of it. Outbound, it connects to whatever databases you configure, and to a language model provider only if you set one up. It does not phone home.
