#!/bin/bash
# Minimal replacement for the official image's entrypoint: create the login user from
# CLICKHOUSE_USER / CLICKHOUSE_PASSWORD, fix volume ownership, run clickhouse-server unprivileged.
set -euo pipefail

CONFIG=/etc/clickhouse-server/config.xml
CH_USER="${CLICKHOUSE_USER:-default}"
CH_PASSWORD="${CLICKHOUSE_PASSWORD:-}"

# Any other command (bash, isql, sqlplus, ...) runs as-is.
if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
    exec "$@"
fi

if [ "$(id -u)" = 0 ]; then
    chown -R clickhouse:clickhouse /var/lib/clickhouse /var/log/clickhouse-server
fi

if [ "$CH_USER" != default ] || [ -n "$CH_PASSWORD" ]; then
    case "$CH_USER" in
        *[!A-Za-z0-9_]*|'') echo "CLICKHOUSE_USER must be letters, digits or _" >&2; exit 1 ;;
    esac
    hash="$(printf '%s' "$CH_PASSWORD" | sha256sum | cut -d' ' -f1)"
    # Like the official image: the login user replaces 'default'.
    remove_default=""
    [ "$CH_USER" != default ] && remove_default='        <default remove="remove"/>'
    cat > /etc/clickhouse-server/users.d/login-user.xml <<EOF
<clickhouse>
    <users>
$remove_default
        <$CH_USER>
            <password_sha256_hex>$hash</password_sha256_hex>
            <networks><ip>::/0</ip></networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>${CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT:-1}</access_management>
        </$CH_USER>
    </users>
</clickhouse>
EOF
fi

if [ "$(id -u)" = 0 ]; then
    exec clickhouse su clickhouse:clickhouse clickhouse-server --config-file="$CONFIG" "$@"
fi
exec clickhouse-server --config-file="$CONFIG" "$@"
