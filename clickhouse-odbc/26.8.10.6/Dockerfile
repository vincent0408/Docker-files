# ClickHouse + unixODBC + clickhouse-odbc-bridge + libaio (Oracle Instant Client is mounted in,
# not baked in). clickhouse-server auto-starts clickhouse-odbc-bridge for odbc() table functions,
# so this image only adds the bridge binary, the unixODBC runtime, libaio and the library path.
#
#   podman run -d --name clickhouse --restart=always \
#     -p 8123:8123 -e TZ=Asia/Taipei --ulimit nofile=65535:65535 \
#     -v clickhouse-data:/var/lib/clickhouse -v clickhouse-logs:/var/log/clickhouse-server \
#     -e CLICKHOUSE_USER=vector -e CLICKHOUSE_PASSWORD=... \
#     -v /oracle/product/19.0.0.0/instantclient_19_23:/oracle/product/19.0.0.0/instantclient_19_23:ro \
#     -v ./odbc.ini:/etc/odbc.ini:ro \
#     docker.io/library/clickhouse-odbc:26.8.10.6
#
# Mount the Instant Client somewhere else with -e ORACLE_HOME=<container path>.

# Fully qualified so podman doesn't stop at short-name resolution.
FROM docker.io/clickhouse/clickhouse-server:26.8.10.6

# Bridge versions are interchangeable with any clickhouse-server (upstream:
# "All versions are compatible with each other").
ARG BRIDGE_VERSION=25.1.5.31
# SHA256 pinned from the official ClickHouse apt index
# (packages.clickhouse.com/deb/pool/main/c/clickhouse/).
ARG BRIDGE_SHA256=e27700953e6abe92f321279376168d48be9de048d67b8bbaa24f08a16a1f4436
# Plain-HTTP Ubuntu mirror, so the corporate TLS proxy never sees apt traffic.
ARG APT_MIRROR=http://ubuntu.cs.nctu.edu.tw/ubuntu/

COPY clickhouse-odbc-bridge_${BRIDGE_VERSION}_amd64.deb /tmp/
# Plain COPY + chmod (not COPY --chmod) so older podman/buildah can build it.
COPY oracle-entrypoint.sh /usr/local/bin/oracle-entrypoint.sh

RUN set -eux; \
    run() { for i in 1 2 3 4 5; do "$@" && return 0; sleep 5; done; return 1; }; \
    sed -i -e "s|http://archive\.ubuntu\.com/ubuntu/|${APT_MIRROR}|g" \
           -e "s|http://security\.ubuntu\.com/ubuntu/|${APT_MIRROR}|g" \
        /etc/apt/sources.list; \
    # The base image's HTTPS ClickHouse repo is not needed (the bridge deb is COPY'd) and fails
    # behind the TLS proxy.
    rm -f /etc/apt/sources.list.d/clickhouse.list; \
    run apt-get update; \
    # unixodbc: libodbc2 (bridge loads the ODBC driver manager) + isql/odbcinst for debugging
    # libaio1:  libaio.so.1, needed by libclntsh.so / libsqora.so
    run apt-get install -y --no-install-recommends unixodbc odbcinst libaio1; \
    echo "${BRIDGE_SHA256}  /tmp/clickhouse-odbc-bridge_${BRIDGE_VERSION}_amd64.deb" | sha256sum -c -; \
    dpkg -i /tmp/clickhouse-odbc-bridge_${BRIDGE_VERSION}_amd64.deb; \
    rm /tmp/clickhouse-odbc-bridge_${BRIDGE_VERSION}_amd64.deb; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    test -e /usr/lib/x86_64-linux-gnu/libaio.so.1; \
    chmod 755 /usr/local/bin/oracle-entrypoint.sh

ENV ORACLE_HOME=/oracle/product/19.0.0.0/instantclient_19_23 \
    ODBCSYSINI=/etc \
    ODBCINI=/etc/odbc.ini
# Defaults for the build-time ORACLE_HOME; oracle-entrypoint.sh recomputes them from the runtime
# ORACLE_HOME, so -e ORACLE_HOME=... still works.
ENV LD_LIBRARY_PATH=${ORACLE_HOME} \
    TNS_ADMIN=${ORACLE_HOME}/network/admin \
    PATH=${ORACLE_HOME}:${PATH}

ENTRYPOINT ["/usr/local/bin/oracle-entrypoint.sh"]
