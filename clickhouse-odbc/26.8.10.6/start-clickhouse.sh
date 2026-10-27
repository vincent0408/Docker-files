#!/usr/bin/env bash
# ClickHouse server for Vector logs. Re-run safely (data lives in the clickhouse-data volume).
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=docker.io/library/clickhouse-odbc:26.8.10.6
CH_USER=vector
CH_PASS="${CH_PASS:?export CH_PASS first (must match start-vector.sh)}"
TIMEZONE=Asia/Taipei                  # display tz + day partitions (image default is UTC)

# Host ODBC config -> container /etc (Driver= paths inside must point at container paths)
ODBCINI=./odbc.ini
# Host Oracle Instant Client dir -> $ORACLE_HOME in the container
ORACLE_HOME=/oracle/product/19.0.0.0/instantclient_19_23

# Load the archive when it is here (built locally instead: skipped). Always reload, so an older
# image with the same tag is not kept.
if [ -f clickhouse-odbc-26.8.10.6.tar.gz ]; then podman load -i clickhouse-odbc-26.8.10.6.tar.gz; fi
podman image exists "$IMAGE" || { echo "no $IMAGE: build it (see README) or put the .tar.gz here" >&2; exit 1; }
podman rm -f clickhouse 2>/dev/null || true

# 8123 = HTTP (Vector, DBeaver, curl). Add -p 9000:9000 for native-protocol clients.
podman run -d --name clickhouse --restart=always \
     -p 8123:8123 \
     -e TZ="$TIMEZONE" \
     --ulimit nofile=65535:65535 \
     -v clickhouse-data:/var/lib/clickhouse \
     -v clickhouse-logs:/var/log/clickhouse-server \
     -v "$ODBCINI:/etc/odbc.ini:ro" \
     -v "$ORACLE_HOME:$ORACLE_HOME:ro" \
     -e ORACLE_HOME="$ORACLE_HOME" \
     -e CLICKHOUSE_USER="$CH_USER" -e CLICKHOUSE_PASSWORD="$CH_PASS" \
     "$IMAGE"

ch() { podman exec -i clickhouse clickhouse-client -u "$CH_USER" --password "$CH_PASS" "$@"; }
for _ in $(seq 60); do ch -q 'SELECT 1' >/dev/null 2>&1 && break; sleep 1; done
# ch --multiquery < init.sql
echo "ClickHouse ready on http://$HOSTNAME:8123  (tables logs.FIX_logs, AP_logs.OrderSvc)"
