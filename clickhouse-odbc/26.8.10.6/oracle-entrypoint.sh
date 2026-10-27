#!/bin/bash
# Make the mounted Oracle Instant Client loadable, then hand off to the stock ClickHouse entrypoint.
set -e

: "${ORACLE_HOME:=/oracle/product/19.0.0.0/instantclient_19_23}"
ORACLE_HOME="${ORACLE_HOME%/}"
export ORACLE_HOME TNS_ADMIN="${TNS_ADMIN:-$ORACLE_HOME/network/admin}"

# LD_LIBRARY_PATH alone is not enough: anything started without the variable (clickhouse su,
# `podman exec ... isql`, ldd from a fresh shell) only sees the ld.so cache. The Instant Client is
# a runtime mount, so the cache has to be rebuilt here, not at build time.
case ":${LD_LIBRARY_PATH}:" in
    *":$ORACLE_HOME:"*) ;;
    *) export LD_LIBRARY_PATH="$ORACLE_HOME${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
esac
case ":${PATH}:" in
    *":$ORACLE_HOME:"*) ;;
    *) export PATH="$ORACLE_HOME:$PATH" ;;
esac

if ls "$ORACLE_HOME"/libclntsh.so.* >/dev/null 2>&1; then
    echo "$ORACLE_HOME" > /etc/ld.so.conf.d/oracle-instantclient.conf
    ldconfig || echo "oracle-entrypoint: ldconfig failed (not root?); relying on LD_LIBRARY_PATH" >&2
else
    echo "oracle-entrypoint: no libclntsh.so.* in ORACLE_HOME=$ORACLE_HOME (is the Instant Client mounted?)" >&2
fi

exec /entrypoint.sh "$@"
