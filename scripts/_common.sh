#!/bin/bash

#=================================================
# THIS SERVER'S DATABASES (install question seed_databases)
#=================================================
# Since YunoHost 12.0.1 the base system installs neither MariaDB nor PostgreSQL,
# so a server is here only when another app pulled it in. The installed and
# running checks are the ones the core's regen-conf hooks make (34-mysql and
# 35-postgresql). $PSQL_VERSION comes from the helpers: 15 on YunoHost 12, 17 on 13.
#
# The seed file names the passwords as ${LIBREDB_YNH_MYSQL_PWD} and
# ${LIBREDB_YNH_PSQL_PWD}; the values are in .env, which the service reads.

_mariadb_is_installed() {
    dpkg-query --show --showformat='${db:Status-Status}' mariadb-server 2> /dev/null | grep --quiet --line-regexp "installed"
}

_mariadb_is_running() {
    systemctl --quiet is-active mariadb.service
}

_postgresql_is_installed() {
    dpkg-query --show --showformat='${db:Status-Status}' "postgresql-$PSQL_VERSION" 2> /dev/null | grep --quiet --line-regexp "installed"
}

# The cluster unit: postgresql.service reports active even when the cluster failed.
_postgresql_is_running() {
    systemctl --quiet is-active "postgresql@$PSQL_VERSION-main.service"
}

# A database name as a psql --dbname value. psql reads a value that contains
# '=' as a conninfo string, so every name goes in as dbname='...', with a
# backslash and a single quote escaped by a backslash, as conninfo requires.
_psql_dbname() {
    local name="$1"
    name=${name//\\/\\\\}
    name=${name//\'/\\\'}
    printf "dbname='%s'" "$name"
}

# psql as postgres, stopping at the first failed statement: without ON_ERROR_STOP
# psql exits 0 after one.
_psql() {
    sudo --user=postgres psql --no-psqlrc --quiet --set=ON_ERROR_STOP=1 "$@"
}

# The phpMyAdmin package's grant: every database, and the right to manage accounts.
_mariadb_admin_ensure() {
    if [ -z "${mysql_admin_user:-}" ]; then
        mysql_admin_user="${app}_admin"
        mysql_admin_pwd=$(ynh_string_random --length=32)
        ynh_app_setting_set --key=mysql_admin_user --value="$mysql_admin_user"
        ynh_app_setting_set --key=mysql_admin_pwd --value="$mysql_admin_pwd"
    fi

    # The account at localhost only: one of the same name on another host is a
    # different account. ALTER sets the password every time, because a restore
    # brings it back from the settings and the account may have outlived a
    # removal. Passwords go to mysql on stdin, never in its arguments.
    mysql --batch <<< "CREATE USER IF NOT EXISTS '$mysql_admin_user'@'localhost';"
    mysql --batch <<< "ALTER USER '$mysql_admin_user'@'localhost' IDENTIFIED BY '$mysql_admin_pwd';"
    mysql --batch <<< "GRANT ALL PRIVILEGES ON *.* TO '$mysql_admin_user'@'localhost' WITH GRANT OPTION;"

    # Read by the seed template through ynh_config_add --jinja.
    # shellcheck disable=SC2034
    mysql_port=$(mysql --batch --skip-column-names <<< "SELECT @@port;")
}

# One seed id per PostgreSQL database, read as one name per line on stdin and
# printed as a JSON list of {database, id}. An id is LibreDB Studio's slug,
# [a-z0-9-] and at most 64 characters: "yunohost-pg-", up to 40 characters of
# the name, and 8 hex digits of the name's md5, so two names that slug alike
# (case, punctuation, non-ASCII, length) still get different ids.
_postgresql_seed_ids() {
    local name
    local slug
    local hash
    local id
    local entries=""

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        slug=$(printf '%s' "$name" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' | cut -c 1-40 | sed -e 's/-$//')
        hash=$(printf '%s' "$name" | md5sum | cut -c 1-8)
        if [ -n "$slug" ]; then
            id="yunohost-pg-$slug-$hash"
        else
            id="yunohost-pg-$hash"
        fi
        entries+=$(jq --null-input --compact-output --arg database "$name" --arg id "$id" '{database: $database, id: $id}')
        entries+=$'\n'
    done

    jq --slurp --compact-output '.' <<< "$entries"
}

# The pgAdmin package's grant: a superuser, which every app database admits.
_postgresql_admin_ensure() {
    if [ -z "${psql_admin_user:-}" ]; then
        psql_admin_user="${app}_admin"
        psql_admin_pwd=$(ynh_string_random --length=32)
        ynh_app_setting_set --key=psql_admin_user --value="$psql_admin_user"
        ynh_app_setting_set --key=psql_admin_pwd --value="$psql_admin_pwd"
    fi

    local statement="CREATE"
    if ynh_psql_user_exists "$psql_admin_user"; then
        statement="ALTER"
    fi
    _psql --dbname=postgres <<< "$statement ROLE \"$psql_admin_user\" WITH LOGIN SUPERUSER PASSWORD '$psql_admin_pwd';"

    # Read by the seed template through ynh_config_add --jinja.
    # shellcheck disable=SC2034
    psql_port=$(_psql --dbname=postgres --tuples-only --no-align --command="SHOW port;")

    # One entry per database: a PostgreSQL session sees only the database it opened.
    local names
    names=$(_psql --dbname=postgres --tuples-only --no-align --command="SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname;")
    psql_databases=$(_postgresql_seed_ids <<< "$names")

    # The hash makes a clash a bug in this script, not something the admin can fix.
    if [ "$(jq 'map(.id) | length != (unique | length)' <<< "$psql_databases")" = "true" ]; then
        ynh_die "Two PostgreSQL databases got the same LibreDB Studio id, which the package should never produce: $(jq --raw-output 'map(.database) | join(", ")' <<< "$psql_databases"). Please report it."
    fi
}

# The groups and users allowed on the main permission, one per line.
_main_permission_allowed() {
    yunohost user permission info "$app.main" --output-as json --quiet \
        | jq --raw-output '.allowed[]'
}

# The same list without admins. grep exits 1 when admins is the only entry.
_main_permission_others() {
    local allowed
    allowed=$(_main_permission_allowed)
    grep --invert-match --line-regexp "admins" <<< "$allowed" || true
}

# Install only: the app holds administrator accounts on this server's databases,
# so nobody but the admins group may reach it.
_main_permission_admins_only() {
    local allowed
    local others
    local group
    allowed=$(_main_permission_allowed)
    others=$(_main_permission_others)

    if ! grep --quiet --line-regexp "admins" <<< "$allowed"; then
        ynh_permission_update --permission=main --add=admins
    fi
    # visitors first: the core pairs it with all_users when the question asks for it.
    if grep --quiet --line-regexp "visitors" <<< "$others"; then
        ynh_permission_update --permission=main --remove=visitors
    fi
    while IFS= read -r group; do
        [ -n "$group" ] && [ "$group" != "visitors" ] || continue
        ynh_permission_update --permission=main --remove="$group"
    done <<< "$others"
    ynh_print_info "Access to $app is limited to the admins group, because it holds administrator accounts on this server's databases."
}

# Upgrade and restore: the permission is the admin's to set after the install,
# so a wider one is reported, never changed.
_main_permission_warn_if_wider() {
    local others
    others=$(_main_permission_others)

    if [ -n "$others" ]; then
        ynh_print_warn "Access to $app is open to more than the admins group ($(paste --serial --delimiters=',' <<< "$others" | sed 's/,/, /g')), while it holds administrator accounts on this server's databases. To limit it: yunohost user permission update $app.main --add admins --remove $(paste --serial --delimiters=' ' <<< "$others")"
    fi
}

# Called by install, upgrade and restore. Leaves seed_config_path set to the
# seed file it wrote, or empty when there is none, for the env template.
_seed_connections_configure() {
    seed_config_path=""
    mysql_seeded=0
    psql_databases="[]"

    if [ "${seed_databases:-0}" != "1" ]; then
        _db_admins_drop
        if [ -e "/etc/$app" ]; then
            ynh_safe_rm "/etc/$app"
        fi
        return 0
    fi

    ynh_print_info "Connecting this server's databases..."

    if _mariadb_is_installed; then
        local skip_networking
        local skip_name_resolve
        if ! _mariadb_is_running; then
            ynh_print_warn "MariaDB is installed but not running, so LibreDB Studio does not list it. Start it, then run: yunohost app upgrade $app --force"
        else
            skip_networking=$(mysql --batch --skip-column-names <<< "SELECT @@skip_networking;")
            skip_name_resolve=$(mysql --batch --skip-column-names <<< "SELECT @@skip_name_resolve;")
            if [ "$skip_networking" != "0" ]; then
                ynh_print_warn "MariaDB takes no TCP connections (skip_networking), so LibreDB Studio does not list it."
            elif [ "$skip_name_resolve" != "0" ]; then
                # A 'localhost' account matches a TCP client from 127.0.0.1 only through name resolution.
                ynh_print_warn "MariaDB runs with skip_name_resolve, so an account at 'localhost' cannot log in over TCP and LibreDB Studio does not list it."
            else
                _mariadb_admin_ensure
                mysql_seeded=1
            fi
        fi
    fi

    if _postgresql_is_installed; then
        if _postgresql_is_running; then
            _postgresql_admin_ensure
        else
            ynh_print_warn "PostgreSQL is installed but not running, so LibreDB Studio does not list it. Start it, then run: yunohost app upgrade $app --force"
        fi
    fi

    if [ "$mysql_seeded" = "0" ] && [ "$psql_databases" = "[]" ]; then
        ynh_print_warn "No running MariaDB or PostgreSQL server was found, so LibreDB Studio lists none of this server's databases."
        if [ -e "/etc/$app" ]; then
            ynh_safe_rm "/etc/$app"
        fi
        return 0
    fi

    # root owns the directory, so the app cannot add files next to the seed.
    mkdir -p "/etc/$app"
    chown "root:$app" "/etc/$app"
    chmod 750 "/etc/$app"
    seed_config_path="/etc/$app/seed-connections.yaml"
    # ynh_config_add makes a file under /etc/$app mode 600, owned by $app.
    ynh_config_add --jinja --template="seed-connections.yaml" --destination="$seed_config_path"
}

# Drops the accounts named in the settings. Objects the PostgreSQL account
# created are kept and handed to postgres; MariaDB keeps them as they are.
_db_admins_drop() {
    if [ -n "${mysql_admin_user:-}" ]; then
        ynh_print_info "Removing the MariaDB account $mysql_admin_user..."
        if ! _mariadb_is_installed; then
            ynh_print_warn "MariaDB is no longer installed. If its data directory was kept, the account $mysql_admin_user is still in it."
            ynh_app_setting_delete --key=mysql_admin_user
            ynh_app_setting_delete --key=mysql_admin_pwd
        elif ! _mariadb_is_running; then
            ynh_print_warn "MariaDB is not running, so the account $mysql_admin_user is still on it. Start MariaDB and run: mysql -e \"DROP USER '$mysql_admin_user'@'localhost';\""
        else
            # The localhost account only, like _mariadb_admin_ensure: ynh_mysql_user_exists
            # matches the name on any host, and a drop of a missing account would stop the run.
            mysql --batch <<< "DROP USER IF EXISTS '$mysql_admin_user'@'localhost';"
            ynh_app_setting_delete --key=mysql_admin_user
            ynh_app_setting_delete --key=mysql_admin_pwd
        fi
    fi

    if [ -n "${psql_admin_user:-}" ]; then
        ynh_print_info "Removing the PostgreSQL account $psql_admin_user..."
        if ! _postgresql_is_installed; then
            ynh_print_warn "PostgreSQL $PSQL_VERSION is no longer installed. If its cluster was kept, the role $psql_admin_user is still in it."
            ynh_app_setting_delete --key=psql_admin_user
            ynh_app_setting_delete --key=psql_admin_pwd
        elif ! _postgresql_is_running; then
            ynh_print_warn "PostgreSQL is not running, so the role $psql_admin_user is still on it. Start PostgreSQL, reassign what it owns to postgres in each database, then drop it."
        else
            if ynh_psql_user_exists "$psql_admin_user"; then
                local names
                local database
                names=$(_psql --dbname=postgres --tuples-only --no-align --command="SELECT datname FROM pg_database WHERE datallowconn;")
                while IFS= read -r database; do
                    [ -n "$database" ] || continue
                    _psql --dbname="$(_psql_dbname "$database")" <<< "REASSIGN OWNED BY \"$psql_admin_user\" TO postgres; DROP OWNED BY \"$psql_admin_user\";"
                done <<< "$names"
                _psql --dbname=postgres <<< "DROP ROLE \"$psql_admin_user\";"
            fi
            ynh_app_setting_delete --key=psql_admin_user
            ynh_app_setting_delete --key=psql_admin_pwd
        fi
    fi
}
