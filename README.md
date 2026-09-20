# LibreDB Studio for YunoHost

[![Install LibreDB Studio with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=libredb_studio)

*This README is generated from the manifest and the files in `doc/` once the app is in the catalogue. Until then it is written by hand.*

## Overview

LibreDB Studio is a web SQL client you run on your own server: browse a schema, read and edit rows, write queries with completion, read EXPLAIN plans, and draw an ER diagram. It speaks 16 engines through their own drivers.

**Shipped version:** 0.16.1~ynh1

## Screenshots

The installation guide at <https://libredb.org/helper/> shows every screen.

## Documentation and resources

- Official app website: <https://libredb.org>
- Upstream app code repository: <https://github.com/libredb/libredb-studio>
- Installation guide: <https://libredb.org/helper/>
- Report a bug: <https://github.com/libredb/libredb-studio/issues>

## Developer info

To try the testing branch:

```bash
sudo yunohost app install https://github.com/libredb/libredb_studio_ynh/tree/testing --debug
or
sudo yunohost app upgrade libredb_studio -u https://github.com/libredb/libredb_studio_ynh/tree/testing --debug
```
