# ClickHouse server + clickhouse-odbc-bridge + unixODBC + Oracle Instant Client on RHEL 9 (UBI 9).
# Everything is installed from signed RPM repos; nothing is mounted in from the host except config.
#
#   podman build -t docker.io/library/clickhouse-odbc:26.8.10.6-rhel9 .
#   CH_PASS=... ./start-clickhouse.sh
#
# Behind a TLS-inspecting proxy, put its CA (.pem/.crt) in certs/ before building and pass the
# proxy with --build-arg https_proxy=... (see README).

FROM registry.access.redhat.com/ubi9/ubi:9.8

ARG CLICKHOUSE_VERSION=26.8.10.6
# Last clickhouse-odbc-bridge ClickHouse published (it is not built into 25.2+ binaries). Bridge
# and server versions are interchangeable (upstream: "All versions are compatible with each other").
ARG BRIDGE_VERSION=25.1.5.31
# Newest Instant Client in Oracle's OL9 repo. 23.x connects to Oracle Database 19c and later.
ARG ORACLE_IC_VERSION=23.26.3.0.0

# Optional extra CAs (corporate TLS proxy). Only *.pem / *.crt files are used.
COPY certs/ /tmp/certs/
COPY clickhouse-entrypoint.sh /usr/local/bin/clickhouse-entrypoint.sh
COPY check-deps.sh /usr/local/bin/check-deps.sh

RUN set -eux; \
    find /tmp/certs -type f \( -name '*.pem' -o -name '*.crt' \) -exec cp {} /etc/pki/ca-trust/source/anchors/ \; ; \
    update-ca-trust; \
    rm -rf /tmp/certs; \
    # ClickHouse: upstream repo definition (signed metadata).
    printf '%s\n' \
        '[clickhouse-stable]' \
        'name=ClickHouse - Stable Repository' \
        'baseurl=https://packages.clickhouse.com/rpm/stable/' \
        'gpgkey=https://packages.clickhouse.com/rpm/stable/repodata/repomd.xml.key' \
        'gpgcheck=0' \
        'repo_gpgcheck=1' \
        'enabled=1' > /etc/yum.repos.d/clickhouse.repo; \
    # Oracle Instant Client 23: Oracle Linux 9 repo (signed packages, installs as-is on RHEL 9).
    printf '%s\n' \
        '[ol9_oracle_instantclient23]' \
        'name=Oracle Instant Client 23 for Oracle Linux 9' \
        'baseurl=https://yum.oracle.com/repo/OracleLinux/OL9/oracle/instantclient23/x86_64/' \
        'gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol9' \
        'gpgcheck=1' \
        'enabled=1' > /etc/yum.repos.d/oracle-instantclient23.repo; \
    dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
        "clickhouse-server-${CLICKHOUSE_VERSION}" \
        "clickhouse-client-${CLICKHOUSE_VERSION}" \
        "clickhouse-common-static-${CLICKHOUSE_VERSION}" \
        "clickhouse-odbc-bridge-${BRIDGE_VERSION}" \
        "oracle-instantclient-basic-${ORACLE_IC_VERSION}" \
        "oracle-instantclient-odbc-${ORACLE_IC_VERSION}" \
        "oracle-instantclient-sqlplus-${ORACLE_IC_VERSION}" \
        unixODBC libaio tzdata; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum; \
    # The basic RPM registers its lib dir in /etc/ld.so.conf.d, so libclntsh & co. resolve for every
    # process (no LD_LIBRARY_PATH needed). Register the ODBC driver with unixODBC.
    SQORA="$(rpm -ql "oracle-instantclient-odbc-${ORACLE_IC_VERSION}" | grep '/libsqora\.so\.[0-9.]*$')"; \
    ln -s "$(dirname "$SQORA")" /opt/oracle-instantclient; \
    printf '%s\n' \
        '[Oracle]' \
        'Description = Oracle Instant Client ODBC driver' \
        "Driver      = /opt/oracle-instantclient/$(basename "$SQORA")" \
        'Threading   = 0' > /etc/odbcinst.ini; \
    mkdir -p /etc/oracle /var/lib/clickhouse /var/log/clickhouse-server /etc/clickhouse-server/config.d /etc/clickhouse-server/users.d; \
    # Listen on all interfaces and also log to stdout (`podman logs`).
    printf '%s\n' \
        '<clickhouse>' \
        '    <listen_host>0.0.0.0</listen_host>' \
        '    <listen_host>::</listen_host>' \
        '    <listen_try>1</listen_try>' \
        '    <logger><console>1</console></logger>' \
        '</clickhouse>' > /etc/clickhouse-server/config.d/docker.xml; \
    chmod 755 /usr/local/bin/clickhouse-entrypoint.sh /usr/local/bin/check-deps.sh; \
    /usr/local/bin/check-deps.sh

# NLS_LANG: without it the Oracle client converts to US7ASCII and non-ASCII text comes back as '?'.
ENV ORACLE_HOME=/opt/oracle-instantclient \
    TNS_ADMIN=/etc/oracle \
    NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
    ODBCSYSINI=/etc \
    ODBCINI=/etc/odbc.ini \
    PATH=/opt/oracle-instantclient:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    TZ=UTC

EXPOSE 8123 9000
VOLUME ["/var/lib/clickhouse", "/var/log/clickhouse-server"]
ENTRYPOINT ["/usr/local/bin/clickhouse-entrypoint.sh"]
