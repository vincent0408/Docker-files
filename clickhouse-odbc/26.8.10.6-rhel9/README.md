# ClickHouse 26.8.10.6 + Oracle ODBC on RHEL 9

Image `clickhouse-odbc:26.8.10.6-rhel9`, built from the `Dockerfile` in this folder on
Red Hat UBI 9 (RHEL 9.8 userland, freely redistributable, no subscription needed). Everything
comes from signed RPM repositories:

| Component | Version | Source |
|---|---|---|
| `clickhouse-server`, `clickhouse-client`, `clickhouse-common-static` | 26.8.10.6 | packages.clickhouse.com/rpm/stable |
| `clickhouse-odbc-bridge` | 25.1.5.31 (last published; works with any server version) | packages.clickhouse.com/rpm/stable |
| `oracle-instantclient-basic`, `-odbc`, `-sqlplus` | 23.26.3.0.0 (latest; connects to Oracle DB 19c and later) | yum.oracle.com OL9 instantclient23 |
| `unixODBC`, `libaio`, `tzdata` | RHEL 9 | UBI 9 repos |

The Instant Client is inside the image now (nothing to mount from the host). Its RPM registers
`/usr/lib/oracle/23/client64/lib` with `ldconfig`, so every process finds `libclntsh.so` without
`LD_LIBRARY_PATH`. The ODBC driver is registered in `/etc/odbcinst.ini` as **`Oracle`**.

Set in the image: `ORACLE_HOME=/opt/oracle-instantclient` (link to the lib dir),
`TNS_ADMIN=/etc/oracle`, `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` (without it non-ASCII text
arrives as `?`), `ODBCINI=/etc/odbc.ini`, `ODBCSYSINI=/etc`.

## Dependency check

`check-deps.sh` runs at the end of the build and fails it if anything is missing:

- `ldd` on ClickHouse, the bridge, `isql`/`odbcinst`, unixODBC's libraries and every Instant
  Client library and tool (`sqlplus`, `adrci`, `genezi`), with `LD_LIBRARY_PATH` unset
- `rpm -Va --nofiles` (unmet RPM dependencies)
- the `Oracle` driver is registered with unixODBC

Run it again in a running container with `podman exec clickhouse check-deps.sh`.

## Build

```bash
cd clickhouse-odbc/26.8.10.6-rhel9
cp /path/to/yuanta-websense-ca.pem certs/      # TLS-inspecting proxy CA, if any (not committed)
podman build -t docker.io/library/clickhouse-odbc:26.8.10.6-rhel9 .
```

If the build host needs an HTTP proxy, add
`--build-arg https_proxy=http://proxy:port --build-arg http_proxy=http://proxy:port`
(not stored in the image). Tag exactly as above: that is the name `start-clickhouse.sh`
runs.

## Run

```bash
cp odbc.ini.example odbc.ini                    # set ServerName / UserID / Password
CH_PASS=... ./start-clickhouse.sh
```

- `odbc.ini` is mounted at `/etc/odbc.ini`. Use `Driver = Oracle`, not a library path.
- For tnsnames.ora aliases, put `tnsnames.ora` (and `sqlnet.ora`) in `./tns`. The script mounts
  it at `/etc/oracle` when the folder exists.
- `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` create the login user, which replaces `default`
  (same behaviour as the official image).
- An existing `clickhouse-data` volume from the old Ubuntu-based image is reused as is. The
  entrypoint re-owns it for this image's `clickhouse` user.

## Query Oracle

Declare the columns and use the `ODBC` table engine:

```sql
CREATE TABLE logs.ora_emp
(
    EMPNO Int32,
    ENAME Nullable(String),
    HIRED Nullable(DateTime),
    SAL   Nullable(Decimal(7, 2))
)
ENGINE = ODBC('DSN=ORA', 'SCOTT', 'EMP');

SELECT * FROM logs.ora_emp WHERE SAL > 1000;    -- WHERE is pushed down to Oracle
```

ClickHouse sends `SELECT "EMPNO", ... FROM "SCOTT"."EMP"` with every name in double quotes, and
quoted names are case-sensitive in Oracle. Write the schema, table and column names exactly as
`ALL_TAB_COLUMNS` shows them (normally UPPERCASE). `'scott', 'emp'` gives `ORA-00942: table or view
does not exist`, and a lowercase column gives `ORA-00904: invalid identifier`. Pass the schema as
its own argument, not as `'SCOTT.EMP'`. `ORA-00942` also means the DSN's `UserID` has no `SELECT`
grant on the table. The exact SQL is in the server log:
`grep 'Query: SELECT' /var/log/clickhouse-server/clickhouse-server.log`.

The `odbc('DSN=ORA', 'SCOTT', 'EMP')` table function, and an `ODBC` table without a column
list, do **not** work with Oracle's driver (19c or 23ai): they need the bridge's automatic
column discovery, and Oracle's driver rejects the calls it makes (`HYT00 Timeout expired` for
the schema lookup, `HY090 Invalid string or buffer length` for the column lookup). The data path
works; only discovery fails. ODBC dictionaries with an explicit structure also work.

## Check it works

```bash
podman exec clickhouse check-deps.sh                                       # all "ok", exit 0
podman exec clickhouse sh -c 'echo "SELECT 1 FROM dual" | isql -b ORA'      # via unixODBC
podman exec -it clickhouse sqlplus scott/tiger@//dbhost:1521/ORCLPDB1     # via OCI
```

Tested against Oracle Database 23ai Free: build check passes; `isql`, `sqlplus` and the `ODBC`
engine table above read the data, including `中文` text; the server and bridge run as user
`clickhouse`; data written by the old image's volume is readable.
