# ClickHouse 26.8.10.6 + Oracle ODBC image

`docker save` archive (gzipped) of `clickhouse-odbc:26.8.10.6`, built from the
`Dockerfile` in this folder:

- base `clickhouse/clickhouse-server:26.8.10.6` (Ubuntu 22.04)
- `clickhouse-odbc-bridge` 25.1.5.31 (SHA256-checked deb from packages.clickhouse.com)
- `unixodbc`, `odbcinst`, `libaio1` (`libaio.so.1`, needed by `libclntsh.so`)
- `ORACLE_HOME`, `LD_LIBRARY_PATH`, `TNS_ADMIN`, `PATH`, `ODBCINI=/etc/odbc.ini`,
  `ODBCSYSINI=/etc` set in the image

The Oracle Instant Client is **not** in the image: mount it from the host. On
start, `oracle-entrypoint.sh` registers `$ORACLE_HOME` in the `ld.so` cache
(`ldconfig`), so `libclntsh.so.19.1` and `libclntshcore.so.19.1` also resolve for
processes that don't inherit `LD_LIBRARY_PATH` (`podman exec`, `ldd`, the bridge
started via `clickhouse su`), then runs the stock `/entrypoint.sh`.

| File | Image | Size |
|---|---|---|
| `clickhouse-odbc-26.8.10.6.tar.gz` | `clickhouse-odbc:26.8.10.6` | 1.1 GB (3.7 GB loaded) |

## Load and run

```bash
git lfs pull --include "clickhouse-odbc/**"
cd clickhouse-odbc/26.8.10.6
sha256sum -c SHA256SUMS                     # clickhouse-odbc-26.8.10.6.tar.gz: OK
CH_PASS=... ./start-clickhouse.sh           # loads the archive and starts the container
```

`start-clickhouse.sh` loads the archive on every run. The old version skipped
the load when an image with the same tag already existed, so a rebuilt archive
was never picked up. It mounts the Instant Client at the same path
(`/oracle/product/19.0.0.0/instantclient_19_23`) and `./odbc.ini` at
`/etc/odbc.ini`. `Driver=` in `odbc.ini` must be the container path, for example
`/oracle/product/19.0.0.0/instantclient_19_23/libsqora.so.19.1`.

To mount the Instant Client somewhere else, also pass `-e ORACLE_HOME=<container path>`.

## Check it works

```bash
podman exec clickhouse ldd /oracle/product/19.0.0.0/instantclient_19_23/libsqora.so.19.1 | grep 'not found'   # prints nothing
podman exec -it clickhouse isql -v <DSN>
podman exec -it clickhouse clickhouse-client -u vector --password "$CH_PASS" \
  -q "SELECT * FROM odbc('DSN=<DSN>', '<SCHEMA>', '<TABLE>') LIMIT 1"
```

Tested with Instant Client 19.23 (basic + odbc) and no database running: `ldd`
reports no missing libraries, and both `isql` and `odbc()` return
`ORA-12541: TNS:no listener`. That error comes from Oracle's client, so the
driver and its libraries loaded.

## Rebuild

Put `clickhouse-odbc-bridge_25.1.5.31_amd64.deb` (from
`https://packages.clickhouse.com/deb/pool/main/c/clickhouse/`) next to the
Dockerfile, then:

```bash
docker build --provenance=false --sbom=false -t clickhouse-odbc:26.8.10.6 .
docker save docker.io/library/clickhouse-odbc:26.8.10.6 | gzip > clickhouse-odbc-26.8.10.6.tar.gz
```

`--build-arg APT_MIRROR=...` changes the Ubuntu mirror (default
`http://ubuntu.cs.nctu.edu.tw/ubuntu/`).
