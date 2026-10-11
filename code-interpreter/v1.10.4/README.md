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
| Docker | Docker Desktop (WSL2 backend) | Docker Desktop (WSL2 backend); Docker Engine inside Ubuntu only as a fallback |
| Runner image | `sandbox-runner-direct` (359 MB) | `sandbox-runner` (1.35 GB) |
| Language runtimes | Built once with `build-packages.sh` | Already in the image |
| Compose files | `images`, `direct`, `server` | `images`, `server` |
| Tested | Same files and settings run end to end on Linux; Windows-side settings not tested on Windows hardware | Not tested (no `/dev/kvm` on the test machine) |
| Commands | bash (Ubuntu terminal) or PowerShell; see [Bash or PowerShell](#bash-or-powershell) | Same |

Either way you need: Git, Git LFS, `openssl` and `curl` in Ubuntu; Docker
Compose 2.24.4 or later (`docker compose version`); about 7 GB of disk; and
enough memory for WSL2 (see [Memory](#memory)).

Work in your Ubuntu home folder (`~/`) for both paths, never under `/mnt/c`:
the Windows drive is slow from WSL, and cloning with Git for Windows can turn
the `.sh` scripts' line endings into CRLF, which breaks them.

### Bash or PowerShell

Every command block below comes in two versions. The **bash** one runs in the
Ubuntu terminal. The **PowerShell** one runs in Windows PowerShell and does the
same thing: Windows-side steps run directly, and steps that work on files in
your Ubuntu home folder are handed to Ubuntu with `wsl`, so the files still
live in `~/` with Linux line endings. You can switch shells between steps.

The PowerShell versions assume your distro is called `Ubuntu`. Check with
`wsl -l -v`; if it is named differently (for example `Ubuntu-24.04`), change
`Ubuntu` in the helpers below and in the commands.

Paste these two helpers into each new PowerShell window before you start (or
add them to your profile once with `notepad $PROFILE`):

```powershell
# ub: run a bash script in your Ubuntu home folder
function ub([string]$Script) {
  $f = Join-Path $env:TEMP 'ub.sh'
  [IO.File]::WriteAllText($f, ($Script -replace "`r", ''))
  $p = '/mnt/' + $f.Substring(0, 1).ToLower() + ($f.Substring(2) -replace '\\', '/')
  wsl -d Ubuntu --cd ~ -- bash $p
}
# dc: docker compose in ~/code-interpreter
function dc { wsl -d Ubuntu --cd ~ -- cd code-interpreter '&&' docker compose @args }
```

`ub` saves the script to a temporary file with Linux line endings and runs it
with bash, so `sudo` can still ask for your password. Keep the `@'` … `'@`
quotes in the examples as they are: they stop PowerShell from changing `$` and
quotes inside the script, and the closing `'@` must start its line. `dc up -d`
is the same as `docker compose up -d` in the Ubuntu terminal.

---

## Path A: no-KVM (Docker Desktop)

### Settings to make

| Where | Setting | Why |
|---|---|---|
| `C:\Users\<you>\.wslconfig` | Usually nothing | WSL2 already gets half your RAM by default; see [Memory](#memory). `nestedVirtualization` is **not** needed. |
| Docker Desktop → Settings → General | "Use the WSL 2 based engine": on | Runs containers in WSL2. |
| Docker Desktop → Settings → Resources → WSL integration | On for your Ubuntu distro | Makes `docker` work inside Ubuntu. |
| Docker Desktop → Settings → General | "Start Docker Desktop when you sign in" (optional) | Docker must be running before the stack starts. |
| `code-interpreter/.env` | `CODEAPI_BRIDGE_TOKEN=<openssl rand -hex 32>` | Required by the API. |
| `code-interpreter/.env` | `COMPOSE_PROJECT_NAME=code-interpreter` | Fixes the network name LibreChat joins (`code-interpreter_default`). |
| `code-interpreter/.env` | `COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.direct.yml:docker-compose.server.yml` | Plain `docker compose up -d`, `ps`, `logs` and `down` then use all four files. |
| LibreChat `.env` | `LIBRECHAT_CODE_BASEURL=…` and `LIBRECHAT_CODE_API_KEY=…` | See [A6](#a6-point-librechat-at-it). |

If you change `.wslconfig`, run `wsl --shutdown` in PowerShell and restart
Docker Desktop.

### A1. Prepare Ubuntu

If you don't have WSL2 and Ubuntu yet, in an administrator PowerShell:
`wsl --install -d Ubuntu`. Then in the Ubuntu terminal:

```bash
sudo apt-get update && sudo apt-get install -y git git-lfs openssl curl
docker compose version     # needs 2.24.4 or later; comes with Docker Desktop
cd ~
```

PowerShell:

```powershell
wsl -d Ubuntu -u root -- apt-get update
wsl -d Ubuntu -u root -- apt-get install -y git git-lfs openssl curl
wsl -d Ubuntu -- docker compose version   # needs 2.24.4 or later
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

PowerShell:

```powershell
ub @'
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --exclude "*sandbox-runner.tar.gz"
cd code-interpreter/v1.10.4
grep -v ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner.tar.gz ] || docker load -i "$f"
done
'@
```

The skipped file stays behind as a small LFS pointer, which is why both
commands leave it out. What to check at each stage, and how to fix a failed
download: [After the LFS download](#after-the-lfs-download).

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

PowerShell:

```powershell
ub @'
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
'@
```

What each file does: [Compose files](#compose-files).

### A4. Build the language runtimes

The no-KVM runner reads Python, Node and Bun from `./data/pkgs`; they are not
in its image. `build-packages.sh` builds them in a temporary container, so it
needs only Docker and internet. For a first test, Python and bash only:

```bash
SKIP_PYTHON_PACKAGES=1 SKIP_JS_PACKAGES=1 SKIP_NODE=1 SKIP_BUN=1 ./build-packages.sh
```

PowerShell:

```powershell
ub 'cd ~/code-interpreter && SKIP_PYTHON_PACKAGES=1 SKIP_JS_PACKAGES=1 SKIP_NODE=1 SKIP_BUN=1 ./build-packages.sh'
```

Later, run `./build-packages.sh` without the `SKIP_` variables for Python's
data-science packages, Node and Bun (much slower), then
`docker compose restart sandbox-runner` (PowerShell:
`ub 'cd ~/code-interpreter && ./build-packages.sh'`, then
`dc restart sandbox-runner`). The sandbox only offers the
languages it finds in `./data/pkgs` when it starts.

### A5. Start and check

```bash
docker compose up -d
docker compose ps              # sandbox-runner "(healthy)", all services Up
```

PowerShell:

```powershell
dc up -d
dc ps                          # sandbox-runner "(healthy)", all services Up
```

Then run the [checks](#check-it-works).

### A6. Point LibreChat at it

**LibreChat running directly** (`npm run backend`, on Windows or in WSL): in
LibreChat's `.env`:

```bash
LIBRECHAT_CODE_BASEURL=http://localhost:3112/v1
LIBRECHAT_CODE_API_KEY=local-no-auth
```

Docker Desktop forwards the `127.0.0.1` ports to Windows' `localhost`. About
the API key, see [LibreChat settings](#librechat-settings).

**LibreChat running in Docker Desktop**: join it to the code interpreter's
network, as in [LibreChat in Docker](#librechat-in-docker).

---

## Path B: KVM (Windows 11)

Windows itself has no `/dev/kvm`; it only exists on Linux. WSL2 runs a real
Linux kernel, and on Windows 11 it can pass hardware virtualization through
to that kernel (nested virtualization), which creates `/dev/kvm`. Docker
Desktop's WSL2 engine runs in that same WSL2 VM, so its containers can be
given `/dev/kvm` too, and the sandbox starts its microVM there.

This does **not** work on Windows 10: WSL there forces nested virtualization
off whatever `.wslconfig` says
([microsoft/WSL#40735](https://github.com/microsoft/WSL/issues/40735)). A
work-managed PC can also block it by policy
([Intune setting](https://learn.microsoft.com/windows/wsl/intune)). The
[dockur/windows](https://github.com/dockur/windows) project, which needs the
same `/dev/kvm` access, lists Docker Desktop on Windows 11 with nested
virtualization as supported and Docker Desktop on Windows 10 as not.

These steps were not tested on Windows hardware for this repo; the checks in
B3 tell you whether your machine can do it before you change anything else.

Setting this up with an AI agent? Point it at
[AGENT-KVM-SETUP.md](AGENT-KVM-SETUP.md): the same steps as agent
instructions, with the questions it must ask you before changing anything.

### Settings to make

| Where | Setting | Why |
|---|---|---|
| BIOS/UEFI | Intel VT-x or AMD-V/SVM on | Task Manager → Performance → CPU must say "Virtualization: Enabled". |
| `C:\Users\<you>\.wslconfig` | `[wsl2]` and `nestedVirtualization=true` | Creates `/dev/kvm` in WSL2. Memory usually needs no setting; see [Memory](#memory). |
| Docker Desktop | Same settings as Path A (WSL 2 based engine, WSL integration on for Ubuntu) | Only if B3 shows Docker Desktop can't pass `/dev/kvm`, use the [Docker Engine fallback](#b4-fallback-docker-engine-inside-ubuntu). |
| `code-interpreter/.env` | `CODEAPI_BRIDGE_TOKEN`, `COMPOSE_PROJECT_NAME=code-interpreter` | As in Path A. |
| `code-interpreter/.env` | `COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml` | Same as Path A **without** `docker-compose.direct.yml`. |
| LibreChat `.env` | `LIBRECHAT_CODE_BASEURL=…` and `LIBRECHAT_CODE_API_KEY=…` | Same as Path A ([A6](#a6-point-librechat-at-it)). |

### B1. Check Windows and WSL (PowerShell)

```powershell
winver            # must be Windows 11
wsl --update
wsl --version
```

No WSL2 and Ubuntu yet? In an administrator PowerShell:
`wsl --install -d Ubuntu`, restart if asked, and open Ubuntu once to create
your Linux user. You also need Docker Desktop with the Path A settings.

### B2. Turn on nested virtualization

Create or edit `C:\Users\<you>\.wslconfig` (add the lines under an existing
`[wsl2]` section if there is one):

```ini
[wsl2]
nestedVirtualization=true
```

Then quit Docker Desktop (tray icon → Quit), run `wsl --shutdown` in
PowerShell, and start Docker Desktop again.

PowerShell, for the whole step (Notepad offers to create the file if it does
not exist; save it as `.wslconfig`, not `.wslconfig.txt`):

```powershell
notepad "$env:USERPROFILE\.wslconfig"      # add the two lines above, save, close
# quit Docker Desktop from the tray icon first, then:
wsl --shutdown
Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
Get-Content "$env:USERPROFILE\.wslconfig"  # must show [wsl2] and nestedVirtualization=true
```

### B3. Check for KVM (Ubuntu terminal)

```bash
ls -l /dev/kvm
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

PowerShell:

```powershell
wsl -d Ubuntu -- ls -l /dev/kvm
wsl -d Ubuntu -- docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

If the `docker run` line says `Cannot connect to the Docker daemon`, Docker is
not reachable from Ubuntu: start Docker Desktop and check its WSL integration
is on for your distro (see [Path A settings](#settings-to-make)), then run it
again. That error says nothing about KVM yet.

| `ls -l /dev/kvm` | `docker run …` | Meaning | Next |
|---|---|---|---|
| Prints the device | Prints the device | Docker Desktop passes KVM to containers | B5 |
| Prints the device | Error | WSL has KVM, Docker Desktop does not pass it on | [B4 fallback](#b4-fallback-docker-engine-inside-ubuntu) |
| "No such file" | — | KVM is not reaching WSL | See below |

If `/dev/kvm` is missing, load the module for your CPU and check again:

```bash
sudo modprobe kvm_intel   # Intel
sudo modprobe kvm_amd     # AMD
```

PowerShell:

```powershell
wsl -d Ubuntu -u root -- modprobe kvm_intel   # Intel
wsl -d Ubuntu -u root -- modprobe kvm_amd     # AMD
```

Still missing means virtualization is not reaching WSL: recheck the BIOS
setting, that you are on Windows 11, that `.wslconfig` is in your user folder
(not `.wslconfig.txt`), and that you ran `wsl --shutdown` after editing it.
Until it appears, stay on Path A.

### B4 (fallback): Docker Engine inside Ubuntu

Only if B3 showed `/dev/kvm` in Ubuntu but the `docker run` line failed. This
replaces Docker Desktop for the code interpreter with Docker Engine running
directly in Ubuntu, which uses the kernel you just checked.

Quit Docker Desktop, or turn its WSL integration off for Ubuntu, so it does not
take over the `docker` command. Then:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker,kvm $USER
```

Close and reopen the Ubuntu terminal (for the new groups), start Docker if it
is not running (`sudo service docker start`), and check again:

```bash
docker compose version          # needs 2.24.4 or later
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

PowerShell, for the whole step (`wsl --terminate` restarts Ubuntu so the new
groups apply):

```powershell
ub 'curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker,kvm $USER'
wsl --terminate Ubuntu
wsl -d Ubuntu -u root -- service docker start
wsl -d Ubuntu -- docker compose version    # needs 2.24.4 or later
wsl -d Ubuntu -- docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

The `docker run` line must print the device. If it does not, stay on Path A.

Docker Engine has its own image store and networks, separate from Docker
Desktop's. So with this fallback, B5 loads all six images again (use the
commands for a fresh setup), and a LibreChat running in Docker must also run
on this engine to join the code interpreter's network.

### B5. Load the KVM runner and switch `COMPOSE_FILE`

**Coming from Path A on Docker Desktop** (the usual case): the other five
images are already loaded, so only the KVM runner is needed:

```bash
cd ~/code-interpreter && docker compose down     # stop Path A
cd ~/Docker-files && git pull && git lfs pull --include "*sandbox-runner.tar.gz"
cd code-interpreter/v1.10.4
grep ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c
docker load -i code-interpreter-sandbox-runner.tar.gz
cd ~/code-interpreter
sed -i 's#:docker-compose.direct.yml##' .env
grep ^COMPOSE_FILE .env    # must not list docker-compose.direct.yml
```

PowerShell:

```powershell
ub @'
cd ~/code-interpreter && docker compose down     # stop Path A
cd ~/Docker-files && git pull && git lfs pull --include "*sandbox-runner.tar.gz"
cd code-interpreter/v1.10.4
grep ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c
docker load -i code-interpreter-sandbox-runner.tar.gz
cd ~/code-interpreter
sed -i 's#:docker-compose.direct.yml##' .env
grep ^COMPOSE_FILE .env    # must not list docker-compose.direct.yml
'@
```

**Fresh setup** (no Path A, or the Docker Engine fallback): load everything
except the direct runner and create `.env`:

```bash
cd ~
[ -d Docker-files ] || GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git pull && git lfs pull --exclude "*sandbox-runner-direct*"
cd code-interpreter/v1.10.4
grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner-direct.tar.gz ] || docker load -i "$f"
done
cd ~
[ -d code-interpreter ] || git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
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

PowerShell:

```powershell
ub @'
[ -d Docker-files ] || GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git pull && git lfs pull --exclude "*sandbox-runner-direct*"
cd code-interpreter/v1.10.4
grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner-direct.tar.gz ] || docker load -i "$f"
done
cd ~
[ -d code-interpreter ] || git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
cp Docker-files/code-interpreter/v1.10.4/docker-compose.{images,server}.yml code-interpreter/
cd code-interpreter
cp .env.example .env
sed -i "s/^CODEAPI_BRIDGE_TOKEN=.*/CODEAPI_BRIDGE_TOKEN=$(openssl rand -hex 32)/" .env
cat >> .env <<'EOF'

# --- Path B: KVM ---
COMPOSE_PROJECT_NAME=code-interpreter
COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml
EOF
'@
```

No `build-packages.sh`: the runtimes are inside the KVM runner image.

What to check after the download and load commands above, and how to fix a
failed download: [After the LFS download](#after-the-lfs-download).

### B6. Start and check

```bash
docker compose up -d
docker compose ps              # sandbox-runner "(healthy)", all services Up
```

PowerShell:

```powershell
dc up -d
dc ps                          # sandbox-runner "(healthy)", all services Up
```

The KVM runner can take a minute or two to report healthy on first start;
`service-worker` waits for it. Then run the [checks](#check-it-works).

### B7. LibreChat

Nothing changes from [A6](#a6-point-librechat-at-it): same
`LIBRECHAT_CODE_BASEURL`, same network for a LibreChat container. With the
Docker Engine fallback, a LibreChat container must run on that engine too,
and from Windows `localhost:3112` reaches the API through WSL2's localhost
forwarding.

### Going back to Path A

Add `docker-compose.direct.yml` back to `COMPOSE_FILE` (after
`docker-compose.images.yml`), then `docker compose up -d`. The direct runner
image and `./data/pkgs` are still there.

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

### After the LFS download

What to do between `git lfs pull` and starting the stack. Run these in
`~/Docker-files/code-interpreter/v1.10.4` (the PowerShell versions change to
that folder themselves). Which files you need:

| Setup | Needed (large) | Left as a pointer (fine) |
|---|---|---|
| Path A | everything except `code-interpreter-sandbox-runner.tar.gz` | `code-interpreter-sandbox-runner.tar.gz` |
| Path B, fresh | everything except `code-interpreter-sandbox-runner-direct.tar.gz` | `code-interpreter-sandbox-runner-direct.tar.gz` |
| Path B, coming from Path A | `code-interpreter-sandbox-runner.tar.gz` (the rest is already loaded) | — |

**1. Check the download finished**

```bash
ls -lh *.tar.gz
```

PowerShell:

```powershell
ub 'cd ~/Docker-files/code-interpreter/v1.10.4 && ls -lh *.tar.gz'
```

Real files are large: about 1.3G for `code-interpreter-sandbox-runner`,
343M for `-direct`, about 100M for each of the others. A file of about
**134 bytes** is still an LFS pointer, not the image. If one you need is that
small, run your `git lfs pull …` command again; it resumes and only fetches
what is missing.

**2. Verify the checksums**

```bash
grep -v ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c    # Path A
grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c                       # Path B, fresh
grep ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c      # Path B, from Path A
```

PowerShell (run the one line for your setup):

```powershell
ub "cd ~/Docker-files/code-interpreter/v1.10.4 && grep -v ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c"   # Path A
ub 'cd ~/Docker-files/code-interpreter/v1.10.4 && grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c'                       # Path B, fresh
ub "cd ~/Docker-files/code-interpreter/v1.10.4 && grep ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c"      # Path B, from Path A
```

Every line must end in `OK`. For a `FAILED` file, from `~/Docker-files`:

```bash
rm code-interpreter/v1.10.4/<file>.tar.gz
git lfs fsck                                  # moves a corrupt stored copy aside
git lfs pull --include "*<file>.tar.gz"       # restores or re-downloads it
```

PowerShell (put the file's name in `$file` first, without `.tar.gz`):

```powershell
$file = 'code-interpreter-api'
ub "cd ~/Docker-files && rm code-interpreter/v1.10.4/$file.tar.gz && git lfs fsck && git lfs pull --include '*$file.tar.gz'"
```

then check it again.

**3. Load the images into Docker**

`docker load` reads the gzipped archives directly; there is nothing to
extract. Use the loop from [A2](#a2-download-and-load-the-images) or
[B5](#b5-load-the-kvm-runner-and-switch-compose_file), which skips the
pointer file. Each file prints a line like:

```text
Loaded image: ghcr.io/librechat-ai/code-interpreter-api:sha-a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24
```

The 1.3 GB KVM runner takes a minute or so.

**4. Confirm Docker has them**

```bash
docker images 'ghcr.io/librechat-ai/*'
```

PowerShell:

```powershell
ub "docker images 'ghcr.io/librechat-ai/*'"
```

Both paths need `code-interpreter-api`, `-worker`, `-file-server`,
`-egress-gateway` and `-tool-call-server`, plus the runner for your path:
`code-interpreter-sandbox-runner-direct` (Path A) or
`code-interpreter-sandbox-runner` (Path B). Having both runners is fine.

Docker keeps its own copy, so the archives are only needed again to reload
(after resetting Docker Desktop, or on another machine).

**5. Optional: free the disk space**

The clone holds every downloaded archive twice: once in the folder and once
in Git LFS's store inside `.git` (about 2.1 GB each when everything is
downloaded). After the images are loaded, the clone is not needed to run the
stack (the Compose files you use are the copies in `~/code-interpreter`), so
you can delete it:

```bash
rm -rf ~/Docker-files
```

PowerShell:

```powershell
ub 'rm -rf ~/Docker-files'
```

Clone it again if you need to reload. (`git lfs prune` does not help here: it
only removes old versions, not the files you have checked out.)

Then continue with A3 or the rest of B5.

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

PowerShell (runs from Windows; it fills in `session_id` and the file `id` for
you):

```powershell
Invoke-RestMethod http://localhost:3112/v1/health        # OK
Invoke-RestMethod http://localhost:13000/ready           # status ready, redis ok, s3 ok
Invoke-RestMethod http://localhost:3190/health           # OK

$body = @{ lang = 'py'; code = "print(6*7)`nopen('/mnt/data/hello.txt','w').write('hi')" } | ConvertTo-Json
$r = Invoke-RestMethod http://localhost:3112/v1/exec -Method Post -ContentType 'application/json' -Body $body
$r | ConvertTo-Json -Depth 5                             # stdout 42, code 0, files: hello.txt
Invoke-RestMethod "http://localhost:3112/v1/download/$($r.session_id)/$($r.files[0].id)?kind=user"   # hi
```

If `code` is `255` with empty output, the sandbox failed to start the run;
the reason is in `docker compose logs sandbox-runner` (PowerShell:
`dc logs sandbox-runner`).

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
LIBRECHAT_CODE_API_KEY=local-no-auth
```

Use `code-interpreter-api`, not `api`: on the shared network `api` matches
both LibreChat's and the code interpreter's container. Start the code
interpreter first (the network must exist), then `docker compose up -d` in
LibreChat, and enable the code interpreter on an agent. Both must run on the
same Docker engine.

### LibreChat settings

LibreChat reads two settings for the code interpreter
([LibreChat docs](https://www.librechat.ai/docs/features/code_interpreter),
[environment variables](https://www.librechat.ai/docs/configuration/dotenv)):

- `LIBRECHAT_CODE_BASEURL`: where the API is, ending in `/v1`.
- `LIBRECHAT_CODE_API_KEY`: sent as an `x-api-key` header. Set globally in
  `.env`, it applies to all users; without it, each user may be asked for a
  key. With this stack's default `LOCAL_MODE=true` the API accepts every
  request and ignores the key, so any placeholder such as `local-no-auth`
  works. (A real key or LibreChat's JWT setup only matters once you turn
  `LOCAL_MODE` off.)

After editing LibreChat's `.env`, restart LibreChat
(`docker compose down && docker compose up -d` for the Docker setup).

### Memory

Measured on this stack: every service except the sandbox runner together uses
about 235 MiB (`docker stats` after a few runs). The sandbox runner adds:

| Path | Sandbox runner | Total, roughly |
|---|---|---|
| A (no-KVM) | ~60 MiB plus what running code uses | well under 1 GB |
| B (KVM) | One long-lived microVM, configured for 2 GiB (`LAUNCHER_RAM_MIB=2048` in `docker-compose.yaml`), shared by all runs | ~2.3 GB at full use |

On top of that come Docker Desktop itself and, if LibreChat runs in Docker
too, its own containers (MongoDB, Meilisearch and so on). The full
`build-packages.sh` (Path A) compiles Python and installs many packages, which
also takes memory while it runs.

WSL2 gets half of your computer's RAM by default, so on a 16 GB PC it already
has 8 GB and you don't need a `memory` line. Only if WSL2 runs out (containers
killed, `docker compose ps` showing restarts) add one to `.wslconfig`, for
example on a 16 GB PC:

```ini
[wsl2]
memory=10GB
```

and leave Windows at least 4–6 GB. Then `wsl --shutdown` and restart Docker
Desktop.

### Troubleshooting

| Symptom | Check |
|---|---|
| `sandbox-runner` never becomes healthy, or runs return `"code":255` | `docker compose logs --tail 50 sandbox-runner` (PowerShell: `dc logs --tail 50 sandbox-runner`) |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` in Ubuntu | Docker is not reachable from Ubuntu; `docker version` shows only a Client section. Start Docker Desktop and turn on Settings → Resources → WSL integration for your distro, then open a new terminal. Don't switch to the `desktop-linux` context: its `npipe` endpoint only works from Windows. With the [Docker Engine fallback](#b4-fallback-docker-engine-inside-ubuntu), start the engine with `sudo service docker start`. |
| `curl localhost:3112/…` from Ubuntu says "Connection refused" though `docker compose ps` shows `api` up | A 2023 WSL pre-release bug refused connections to `127.0.0.1`-published ports ([docker/for-win#13182](https://github.com/docker/for-win/issues/13182), closed). Run `wsl --update`, and try the same request from PowerShell with `curl.exe` to see whether only WSL is affected. |
| LibreChat cannot reach `code-interpreter-api` | Start the code interpreter first; check `docker network inspect code-interpreter_default` lists LibreChat's container. |
| Containers restart or get killed under load | See [Memory](#memory). |

### Security

- The default `LOCAL_MODE=true` means the API accepts requests without any
  key and uses development secrets. Keep it on `127.0.0.1` (the `server`
  file does this) and don't expose port 3112 to other machines.
- Path A runs untrusted code without a separate kernel or resource limits.
  Use it only for code you'd run on your own machine anyway.

### Day-to-day

From `~/code-interpreter` (with `COMPOSE_FILE` in `.env`, no `-f` flags
needed), or from any folder in PowerShell with the `dc` helper from
[Bash or PowerShell](#bash-or-powershell):

| Task | bash (in `~/code-interpreter`) | PowerShell |
|---|---|---|
| Start | `docker compose up -d` | `dc up -d` |
| Status | `docker compose ps` | `dc ps` |
| Logs when a run fails | `docker compose logs -f sandbox-runner service-worker` | `dc logs -f sandbox-runner service-worker` |
| Stop | `docker compose down` | `dc down` |
| Stop and delete stored files | `docker compose down -v` | `dc down -v` |

Only the sandbox runner has a restart policy upstream; after a reboot (or
after Docker Desktop restarts), run `docker compose up -d` (or `dc up -d`)
again.

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
