# LibreChat Code Interpreter v1.10.4 images

`docker save` archives (gzipped) of the seven prebuilt `linux/amd64` images that
[LibreChat-AI/code-interpreter](https://github.com/LibreChat-AI/code-interpreter)
publishes to GHCR, for release
[v1.10.4](https://github.com/LibreChat-AI/code-interpreter/releases/tag/v1.10.4)
(commit `a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`).

| File | Image | Compose service | Used by |
|---|---|---|---|
| `code-interpreter-api.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-api` | `api` | both paths |
| `code-interpreter-worker.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-worker` | `service-worker` | both paths |
| `code-interpreter-file-server.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-file-server` | `file_server` | both paths |
| `code-interpreter-egress-gateway.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-egress-gateway` | `egress_gateway` | both paths |
| `code-interpreter-tool-call-server.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-tool-call-server` | `tool_call_server` | both paths |
| `code-interpreter-sandbox-runner-direct.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-sandbox-runner-direct` | `sandbox-runner` | Path A (no-KVM) |
| `code-interpreter-sandbox-runner.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-sandbox-runner` | `sandbox-runner` | Path B (KVM) |

Every image is tagged `sha-a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`.

The code interpreter is not one container: it is a Compose stack of these
services plus Redis and MinIO (S3 storage), started from the original repo's
`docker-compose.yaml` with the override files in this folder. LibreChat sends
code to the `api` service on port 3112; the worker runs it in the sandbox
runner.

## Two paths on Windows

Both run in WSL2 (Ubuntu) on Windows and give LibreChat the same API. They
differ in how the sandbox isolates code.

| | **Path A: no-KVM** (start here) | **Path B: KVM** (later) |
|---|---|---|
| Sandbox | NsJail directly in a container | NsJail inside a libkrun microVM with its own kernel |
| Isolation | Weaker: shares the Linux kernel; no per-run memory or process limits. **Your own code only.** | Strong: the design upstream calls reasonably secure |
| Windows | Windows 10 or 11 | **Windows 11** (nested virtualization in WSL2) |
| Docker | Docker Desktop (WSL2 backend) | Docker Engine installed **inside Ubuntu** |
| Runner image | `sandbox-runner-direct` (359 MB) | `sandbox-runner` (1.35 GB) |
| Language runtimes | Built once with `build-packages.sh` | Already in the image |
| Compose files | `images`, `direct`, `server` | `images`, `server` |
| Tested | Same files and settings run end to end on Linux; Windows-side settings not tested on Windows hardware | Not tested (no `/dev/kvm` on the test machine) |

Either way you need: Git, Git LFS, `openssl` and `curl` in Ubuntu; Docker
Compose 2.24.4 or later (`docker compose version`); about 7 GB of disk; 8 GB+
of RAM for WSL2.

Work in your Ubuntu home folder (`~/`) for both paths, never under `/mnt/c`:
the Windows drive is slow from WSL, and cloning with Git for Windows can turn
the `.sh` scripts' line endings into CRLF, which breaks them.

---

## Path A: no-KVM (Docker Desktop)

### Settings to make

| Where | Setting | Why |
|---|---|---|
| `C:\Users\<you>\.wslconfig` | `[wsl2]` then `memory=8GB` (more if you have it) | The stack plus the package build need a few GB; WSL2 defaults to half your RAM. Skip if that is already 8 GB or more. `nestedVirtualization` is **not** needed. |
| Docker Desktop → Settings → General | "Use the WSL 2 based engine": on | Runs containers in WSL2. |
| Docker Desktop → Settings → Resources → WSL integration | On for your Ubuntu distro | Makes `docker` work inside Ubuntu. |
| Docker Desktop → Settings → General | "Start Docker Desktop when you sign in" (optional) | Docker must be running before the stack starts. |
| `code-interpreter/.env` | `CODEAPI_BRIDGE_TOKEN=<openssl rand -hex 32>` | Required by the API. |
| `code-interpreter/.env` | `COMPOSE_PROJECT_NAME=code-interpreter` | Fixes the network name LibreChat joins (`code-interpreter_default`). |
| `code-interpreter/.env` | `COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.direct.yml:docker-compose.server.yml` | Plain `docker compose up -d`, `ps`, `logs` and `down` then use all four files. |
| LibreChat `.env` | `LIBRECHAT_CODE_BASEURL=…` | See [A6](#a6-point-librechat-at-it). |

After changing `.wslconfig`, run `wsl --shutdown` in PowerShell and restart
Docker Desktop.

### A1. Prepare Ubuntu

If you don't have WSL2 and Ubuntu yet, in an administrator PowerShell:
`wsl --install -d Ubuntu`. Then in the Ubuntu terminal:

```bash
sudo apt-get update && sudo apt-get install -y git git-lfs openssl curl
docker compose version     # needs 2.24.4 or later; comes with Docker Desktop
cd ~
```

### A2. Download and load the images

Path A does not use the 1.35 GB KVM runner image, so skip it:

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --exclude "*sandbox-runner.tar.gz"
cd code-interpreter/v1.10.4
grep -v ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner.tar.gz ] || docker load -i "$f"
done
cd ~
```

The skipped file stays behind as a small LFS pointer, which is why both
commands leave it out. Each load prints
`Loaded image: ghcr.io/librechat-ai/<name>:sha-a62d69e…`.

### A3. Get the Compose files and set `.env`

```bash
git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
cp Docker-files/code-interpreter/v1.10.4/docker-compose.{images,direct,server}.yml code-interpreter/
cd code-interpreter
cp .env.example .env
sed -i "s/^CODEAPI_BRIDGE_TOKEN=.*/CODEAPI_BRIDGE_TOKEN=$(openssl rand -hex 32)/" .env
cat >> .env <<'EOF'

# --- Path A: no-KVM ---
COMPOSE_PROJECT_NAME=code-interpreter
COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.direct.yml:docker-compose.server.yml
EOF
```

What each file does: [Compose files](#compose-files).

### A4. Build the language runtimes

The no-KVM runner reads Python, Node and Bun from `./data/pkgs`; they are not
in its image. `build-packages.sh` builds them in a temporary container, so it
needs only Docker and internet. For a first test, Python and bash only:

```bash
SKIP_PYTHON_PACKAGES=1 SKIP_JS_PACKAGES=1 SKIP_NODE=1 SKIP_BUN=1 ./build-packages.sh
```

Later, run `./build-packages.sh` without the `SKIP_` variables for Python's
data-science packages, Node and Bun (much slower), then
`docker compose restart sandbox-runner`. The sandbox only offers the
languages it finds in `./data/pkgs` when it starts.

### A5. Start and check

```bash
docker compose up -d
docker compose ps              # sandbox-runner "(healthy)", all services Up
```

Then run the [checks](#check-it-works).

### A6. Point LibreChat at it

**LibreChat running directly** (`npm run backend`, on Windows or in WSL): in
LibreChat's `.env`:

```bash
LIBRECHAT_CODE_BASEURL=http://localhost:3112/v1
```

Docker Desktop forwards the `127.0.0.1` ports to Windows' `localhost`.

**LibreChat running in Docker Desktop**: join it to the code interpreter's
network, as in [LibreChat in Docker](#librechat-in-docker).

---

## Path B: KVM (Windows 11, Docker Engine in Ubuntu)

Windows itself has no `/dev/kvm`; it only exists on Linux. WSL2 runs a real
Linux kernel, and on Windows 11 it can pass hardware virtualization through
to that kernel (nested virtualization), which creates `/dev/kvm`. The sandbox
then starts its microVM inside WSL2. These steps were not tested on Windows
hardware; the `/dev/kvm` checks tell you at each stage whether it worked.

### Settings to make

| Where | Setting | Why |
|---|---|---|
| BIOS/UEFI | Intel VT-x or AMD-V/SVM on | Task Manager → Performance → CPU must say "Virtualization: Enabled". |
| `C:\Users\<you>\.wslconfig` | `[wsl2]`, `nestedVirtualization=true`, and `memory=8GB` or more | Creates `/dev/kvm` in WSL2. The sandbox microVM is configured with 2 GB and 2 vCPUs (`LAUNCHER_RAM_MIB`, `LAUNCHER_VCPUS` in `docker-compose.yaml`) on top of the other services. |
| Docker Desktop | Quit it, or Settings → Resources → WSL integration **off** for Ubuntu | Its hidden VM does not reliably pass `/dev/kvm` to containers; Ubuntu's own Docker Engine must own the `docker` command. |
| `code-interpreter/.env` | `CODEAPI_BRIDGE_TOKEN`, `COMPOSE_PROJECT_NAME=code-interpreter` | As in Path A. |
| `code-interpreter/.env` | `COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml` | Same as Path A **without** `docker-compose.direct.yml`. |
| LibreChat `.env` | `LIBRECHAT_CODE_BASEURL=…` | See [B7](#b7-point-librechat-at-it). |

### B1. Install WSL2 and Ubuntu (PowerShell as administrator)

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --version
```

Restart Windows if asked, then open Ubuntu once to create your Linux user.

### B2. Turn on nested virtualization

Create or edit `C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
nestedVirtualization=true
memory=8GB
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
```

### B3. Check for `/dev/kvm` (Ubuntu terminal)

```bash
ls -l /dev/kvm
```

If it says "No such file", load the module for your CPU and check again:

```bash
sudo modprobe kvm_intel   # Intel
sudo modprobe kvm_amd     # AMD
```

Still missing means virtualization is not reaching WSL: recheck the BIOS
setting, that you are on Windows 11, and that `wsl --update` ran. Until it
appears, stay on Path A.

Give your user access to it:

```bash
sudo usermod -aG kvm $USER
```

### B4. Install Docker Engine inside Ubuntu

Quit Docker Desktop (tray icon), or turn its WSL integration off for Ubuntu,
so it does not take over the `docker` command. Then, in Ubuntu:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo apt-get install -y git git-lfs openssl curl
```

Close and reopen the Ubuntu terminal (for the new groups), start Docker if
it is not running (`sudo service docker start`), and confirm containers can
use KVM:

```bash
docker compose version          # needs 2.24.4 or later
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
cd ~
```

The `docker run` line must print the device. If it does not, stay on Path A.

### B5. Download, load and set up

This Docker Engine has its own image store, separate from Docker Desktop's,
so the images are loaded here even if you already did Path A. Path B does not
use the direct runner, so skip it:

```bash
[ -d Docker-files ] || GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git pull && git lfs pull --exclude "*sandbox-runner-direct*"
cd code-interpreter/v1.10.4
grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner-direct.tar.gz ] || docker load -i "$f"
done
cd ~
```

If you already have `~/Docker-files` from Path A, `git lfs pull` now also
downloads the KVM runner; the direct runner you loaded earlier is already on
disk and is simply not loaded here.

Then the Compose files and `.env`. If `~/code-interpreter` exists from Path A,
skip the clone and the `.env` creation and only change `COMPOSE_FILE` (see
[Switching from Path A](#switching-from-path-a-to-path-b)):

```bash
git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
cp Docker-files/code-interpreter/v1.10.4/docker-compose.{images,server}.yml code-interpreter/
cd code-interpreter
cp .env.example .env
sed -i "s/^CODEAPI_BRIDGE_TOKEN=.*/CODEAPI_BRIDGE_TOKEN=$(openssl rand -hex 32)/" .env
cat >> .env <<'EOF'

# --- Path B: KVM ---
COMPOSE_PROJECT_NAME=code-interpreter
COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml
EOF
```

No `build-packages.sh`: the runtimes are inside the KVM runner image.

### B6. Start and check

```bash
docker compose up -d
docker compose ps              # sandbox-runner "(healthy)", all services Up
```

The KVM runner can take a minute or two to report healthy on first start;
`service-worker` waits for it. Then run the [checks](#check-it-works).

### B7. Point LibreChat at it

**LibreChat running directly** (`npm run backend`, on Windows or in WSL):

```bash
LIBRECHAT_CODE_BASEURL=http://localhost:3112/v1
```

From Windows, WSL2 forwards `localhost` to ports listening inside it.

**LibreChat running in Docker**: run it on the same Docker Engine inside
Ubuntu (not Docker Desktop, which is a separate engine and network), and join
it to the code interpreter's network as in
[LibreChat in Docker](#librechat-in-docker).

### Switching from Path A to Path B

1. Stop Path A while Docker Desktop is still running:
   `cd ~/code-interpreter && docker compose down -v`.
2. Follow B1–B5. In `~/code-interpreter/.env`, remove
   `docker-compose.direct.yml` from `COMPOSE_FILE`:

   ```bash
   sed -i 's#:docker-compose.direct.yml##' .env
   grep ^COMPOSE_FILE .env
   ```

3. Start with B6. `./data/pkgs` is no longer used; delete it if you want the
   space back.

To go back to Path A, add `docker-compose.direct.yml` back to `COMPOSE_FILE`
and use Docker Desktop again (its own image store still has the Path A
images).

---

## Shared reference

### Compose files

All start from the original repo's `docker-compose.yaml` at `v1.10.4`, which
must match these images.

| File | Path | What it does |
|---|---|---|
| `docker-compose.images.yml` | A and B | Uses the loaded images instead of building (`pull_policy: never`, so a missing image fails fast). Replaces `quay.io/minio/minio`, which no longer allows anonymous pulls, with `cgr.dev/chainguard/minio`. |
| `docker-compose.direct.yml` | A only | Runs `sandbox-runner-direct` without KVM: `/dev/null` in place of `/dev/kvm`; the capabilities and seccomp profile NsJail needs (from upstream's `docker-compose.mac.yml`), without which it loops on `unshare: Operation not permitted`; a health check that works after the runner switches into its sandbox filesystem; `SANDBOX_PIPE_ADDON`, which the published image is missing (`Cannot find module …anonymous-pipes.node`); and `SANDBOX_USE_CGROUPV2=false` (`Couldn't initialize cgroup 2 user namespace`), which turns off per-run memory and process limits. |
| `docker-compose.server.yml` | A and B | Publishes every port on `127.0.0.1` only. Upstream publishes all of them on every interface, including the sandbox runner (which would let anyone skip the API), Redis (password `localdev`) and MinIO (`minioadmin`/`minioadmin`). Also names the API `code-interpreter-api` for a LibreChat container on the same network. |

Setting `KVM_ENABLED=false` in upstream's `.env` alone does not give a working
no-KVM stack: the runner cannot be created without `/dev/kvm`, and with that
fixed it loops on `unshare: Operation not permitted`. That is why Path A uses
`docker-compose.direct.yml`.

### Check it works

```bash
curl localhost:3112/v1/health          # OK
curl localhost:13000/ready             # {"status":"ready","checks":{"redis":"ok","s3":"ok"}}
curl localhost:3190/health             # OK

curl -s localhost:3112/v1/exec \
  -H 'Content-Type: application/json' \
  -d '{"lang":"py","code":"print(6*7)\nopen(\"/mnt/data/hello.txt\",\"w\").write(\"hi\")"}'
```

A working stack answers with `"stdout":"42\n"`, `"code":0` and a `files`
entry for `hello.txt`. To download that file, use the `session_id` and the
file's `id` from the response:

```bash
curl "localhost:3112/v1/download/<session_id>/<file id>?kind=user"   # hi
```

If `code` is `255` with empty output, the sandbox failed to start the run;
the reason is in `docker compose logs sandbox-runner`.

### LibreChat in Docker

Create `docker-compose.override.yml` in the LibreChat folder (or add to the
one you have), so LibreChat's `api` service also joins the code
interpreter's network:

```yaml
services:
  api:
    networks:
      - default
      - code-interpreter

networks:
  code-interpreter:
    name: code-interpreter_default
    external: true
```

and in LibreChat's `.env`:

```bash
LIBRECHAT_CODE_BASEURL=http://code-interpreter-api:3112/v1
```

Use `code-interpreter-api`, not `api`: on the shared network `api` matches
both LibreChat's and the code interpreter's container. Start the code
interpreter first (the network must exist), then `docker compose up -d` in
LibreChat, and enable the code interpreter on an agent. Both must run on the
same Docker engine.

### Security

- The default `LOCAL_MODE=true` means the API accepts requests without any
  key and uses development secrets. Keep it on `127.0.0.1` (the `server`
  file does this) and don't expose port 3112 to other machines.
- Path A runs untrusted code without a separate kernel or resource limits.
  Use it only for code you'd run on your own machine anyway.

### Day-to-day

From `~/code-interpreter` (with `COMPOSE_FILE` in `.env`, no `-f` flags
needed):

| Task | Command |
|---|---|
| Start | `docker compose up -d` |
| Status | `docker compose ps` |
| Logs when a run fails | `docker compose logs -f sandbox-runner service-worker` |
| Stop | `docker compose down` |
| Stop and delete stored files | `docker compose down -v` |

Only the sandbox runner has a restart policy upstream; after a reboot (or
after Docker Desktop restarts), run `docker compose up -d` again.

### Ports

All bound to `127.0.0.1` by `docker-compose.server.yml`.

| Port | Service |
|---|---|
| 3112 | API (what LibreChat calls) |
| 3190 | Egress gateway |
| 2000 | Sandbox runner |
| 13000 | File server |
| 16379 | Redis |
| 19000 / 19001 | MinIO API / console |
