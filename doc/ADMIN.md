## Where its state lives

Everything the application generates is in one directory: the SQLite store that holds your saved connections, the sample databases, and `auth-bootstrap.json` with the credentials from the first run. That directory is backed up with the app and survives an upgrade, which replaces the program but not the data.

## Changing the configuration

The environment file is `.env` in the install directory. It is rewritten from the package template on every upgrade, so an edit there does not survive one. The values it sets are the port, the bind address, the storage path and the signing secret.

The signing secret is kept in the app's YunoHost settings rather than generated at runtime, so an upgrade or a restore does not log everybody out.

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
