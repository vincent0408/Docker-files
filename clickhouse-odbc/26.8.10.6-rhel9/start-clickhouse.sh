#!/usr/bin/env bash
# ClickHouse server for Vector logs (RHEL 9 image). Re-run safely (data lives in the clickhouse-data volume).
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=docker.io/library/clickhouse-odbc:26.8.10.6-rhel9
CH_USER=vector
CH_PASS="${CH_PASS:?export CH_PASS first (must match start-vector.sh)}"
TIMEZONE=Asia/Taipei                  # display tz + day partitions (image default is UTC)

# Host ODBC DSNs -> /etc/odbc.ini. Use "Driver = Oracle" (registered in the image's odbcinst.ini).
ODBCINI=./odbc.ini
# Optional: a folder with tnsnames.ora / sqlnet.ora -> /etc/oracle ($TNS_ADMIN). Not needed for
# EZConnect (ServerName = //host:1521/service).
TNS_DIR=./tns

podman image exists "$IMAGE" || { echo "no $IMAGE: build it first (see README)" >&2; exit 1; }
podman rm -f clickhouse 2>/dev/null || true

tns=()
[ -d "$TNS_DIR" ] && tns=(-v "$(realpath "$TNS_DIR"):/etc/oracle:ro")

# 8123 = HTTP (Vector, DBeaver, curl). Add -p 9000:9000 for native-protocol clients.
podman run -d --name clickhouse --restart=always \
     -p 8123:8123 \
     -e TZ="$TIMEZONE" \
     --ulimit nofile=65535:65535 \
     -v clickhouse-data:/var/lib/clickhouse \
     -v clickhouse-logs:/var/log/clickhouse-server \
     -v "$(realpath "$ODBCINI"):/etc/odbc.ini:ro" \
     "${tns[@]}" \
     -e CLICKHOUSE_USER="$CH_USER" -e CLICKHOUSE_PASSWORD="$CH_PASS" \
     "$IMAGE"

ch() { podman exec -i clickhouse clickhouse-client -u "$CH_USER" --password "$CH_PASS" "$@"; }
for _ in $(seq 60); do ch -q 'SELECT 1' >/dev/null 2>&1 && break; sleep 1; done
# ch --multiquery < init.sql
echo "ClickHouse ready on http://$HOSTNAME:8123  (tables logs.FIX_logs, AP_logs.OrderSvc)"
