LibreDB Studio is a web SQL client you run on your own server. You open it in a browser, add a connection, and work against the database from there: browse the schema, read and edit rows in a grid, write queries with completion, read EXPLAIN plans, and draw an ER diagram of what you are looking at.

It speaks 16 engines through their own drivers, including PostgreSQL, MySQL and MariaDB, SQLite and libSQL, SQL Server, Oracle, MongoDB, Redis, ClickHouse and DuckDB.

Two things are worth knowing before you install it:

- **It has its own accounts.** Local password login, optional OIDC, and per-account TOTP. It does not read YunoHost's LDAP directory and it does not consume the SSO headers, so the permission is set to visitors by default and the application asks for its own login. The first run generates an administrator password and prints it once.
- **A connection it can reach, it can change.** This is an administrative tool, not a read-only viewer. Give it a database account with the privileges you actually want it to have, and keep the login to people you would hand those privileges to directly.

Query assistance from a language model is optional and off unless you configure a provider.
