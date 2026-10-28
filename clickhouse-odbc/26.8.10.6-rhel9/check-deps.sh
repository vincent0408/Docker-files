#!/bin/bash
# Fail if any ClickHouse binary, the ODBC bridge, unixODBC or an Oracle Instant Client library or
# tool has an unresolved shared-library dependency, or an installed RPM has an unmet dependency. Runs at build time; also usable inside the container:
#   podman exec clickhouse check-deps.sh
set -uo pipefail

ic_lib="$(readlink -f /opt/oracle-instantclient)"
files=(/usr/bin/clickhouse /usr/bin/clickhouse-odbc-bridge
       /usr/bin/isql /usr/bin/odbcinst /usr/lib64/libodbc.so.2 /usr/lib64/libodbcinst.so.2)
while IFS= read -r f; do files+=("$f"); done < <(find "$ic_lib" "$(dirname "$ic_lib")/bin" -maxdepth 1 -type f \( -name '*.so*' -o -perm -u+x \))

bad=0
for f in "${files[@]}"; do
    [ "$(head -c4 "$f" | od -An -c | tr -d ' ')" = '177ELF' ] || continue
    # Statically linked binaries (clickhouse) report "not a dynamic executable": nothing to resolve.
    missing="$(env -u LD_LIBRARY_PATH ldd "$f" 2>&1 | grep 'not found')"
    if [ -n "$missing" ]; then
        echo "MISSING for $f:"; echo "$missing"; bad=1
    else
        echo "ok  $f"
    fi
done

# RPM-level dependencies of every installed package.
rpm -Va --nofiles --nodigest --noscripts || { echo "unsatisfied RPM dependencies (above)"; bad=1; }

# The driver the bridge actually loads, through unixODBC.
odbcinst -q -d -n Oracle >/dev/null || { echo "Oracle driver not registered in odbcinst.ini"; bad=1; }

exit "$bad"
