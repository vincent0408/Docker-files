# LibreChat Code Interpreter v1.10.4 images

`docker save` archives (gzipped) of the seven prebuilt `linux/amd64` images that
[LibreChat-AI/code-interpreter](https://github.com/LibreChat-AI/code-interpreter)
publishes to GHCR, for release
[v1.10.4](https://github.com/LibreChat-AI/code-interpreter/releases/tag/v1.10.4)
(commit `a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`).

| File | Image | Compose service |
|---|---|---|
| `code-interpreter-api.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-api` | `api` |
| `code-interpreter-worker.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-worker` | `service-worker` |
| `code-interpreter-file-server.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-file-server` | `file_server` |
| `code-interpreter-egress-gateway.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-egress-gateway` | `egress_gateway` |
| `code-interpreter-tool-call-server.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-tool-call-server` | `tool_call_server` |
| `code-interpreter-sandbox-runner.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-sandbox-runner` | `sandbox-runner` (`KVM_ENABLED=true`) |
| `code-interpreter-sandbox-runner-direct.tar.gz` | `ghcr.io/librechat-ai/code-interpreter-sandbox-runner-direct` | `sandbox-runner` (`KVM_ENABLED=false`) |

Every image is tagged `sha-a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`.

The code interpreter is not one container: it is a Compose stack of these
seven services plus Redis and MinIO (S3 storage). LibreChat sends code to the
`api` service on port 3112; the worker runs it in the sandbox runner.

## Requirements

- Linux on x86_64 (the images are `linux/amd64` only).
- Docker with Docker Compose 2.24.4 or later (`docker compose version`).
- Git and [Git LFS](https://git-lfs.com) (`git lfs version`).
- For the default sandbox: hardware virtualization exposed as `/dev/kvm`
  (`ls -l /dev/kvm`). Bare metal, or a VM with nested virtualization.
  On Windows 11, WSL2 can provide it: see [Windows (WSL2)](#windows-wsl2).
  Without it, use the no-KVM mode in step 5.
- Running it on a server for a LibreChat elsewhere: see
  [RHEL server + LibreChat on your own computer](#rhel-server--librechat-on-your-own-computer).
- About 7 GB of disk for the archives plus the loaded images.

## Windows (WSL2)

Windows itself has no `/dev/kvm`; it only exists on Linux. WSL2 runs a real
Linux kernel, and on Windows 11 it can pass hardware virtualization through
to that kernel (nested virtualization), which creates `/dev/kvm`. The sandbox
then starts its microVM inside WSL2.

> These steps follow Microsoft's and Docker's documented setup but were not
> tested on Windows hardware for this repo. The `/dev/kvm` checks below tell
> you at each stage whether it worked.

### What you need

| What | Size / cost | Notes |
|---|---|---|
| Windows 11 | — | WSL2 nested virtualization is Windows 11 only. On Windows 10, use a [Hyper-V VM](#alternative-a-hyper-v-linux-vm) or no-KVM mode. |
| CPU virtualization on in BIOS/UEFI | — | Intel VT-x or AMD-V/SVM. Task Manager → Performance → CPU must say "Virtualization: Enabled". |
| WSL2 + Ubuntu | ~1–2 GB | `wsl --install` downloads both. |
| Docker Engine inside Ubuntu | ~500 MB | Not Docker Desktop: see step W4. |
| `git`, `git-lfs`, `openssl`, `curl` in Ubuntu | small | `apt` packages. |
| This repo's archives | ~2.2 GB | Skip the 359 MB `sandbox-runner-direct` file; KVM mode does not use it. |
| `code-interpreter` repo at `v1.10.4` | small | Compose files and configuration. |
| `redis:7-alpine`, `cgr.dev/chainguard/minio` | ~150 MB | Pulled automatically on first start. |
| RAM | 8 GB+ recommended | The sandbox microVM is configured with 2 GB and 2 vCPUs (`LAUNCHER_RAM_MIB`, `LAUNCHER_VCPUS` in `docker-compose.yaml`), on top of the other services. WSL2 gets half of your RAM by default. |

KVM mode does **not** need `build-packages.sh`: Python, Node and Bun are
already inside the `code-interpreter-sandbox-runner` image.

### W1. Install WSL2 and Ubuntu (PowerShell as administrator)

```powershell
wsl --install -d Ubuntu
wsl --update
wsl --version
```

Restart Windows if asked, then open Ubuntu once to create your Linux user.

### W2. Turn on nested virtualization

Create or edit `C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
nestedVirtualization=true
# Optional: give WSL more memory than the default half of your RAM.
# memory=12GB
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
```

### W3. Check for `/dev/kvm` (Ubuntu terminal)

```bash
ls -l /dev/kvm
```

If it says "No such file", load the module for your CPU and check again:

```bash
sudo modprobe kvm_intel   # Intel
sudo modprobe kvm_amd     # AMD
```

Still missing means virtualization is not reaching WSL: recheck the BIOS
setting, that you are on Windows 11, and that `wsl --update` ran. Then use an
[alternative](#alternatives) instead.

Give your user access to it:

```bash
sudo usermod -aG kvm $USER
```

### W4. Install Docker Engine inside Ubuntu

Docker Desktop runs containers in its own hidden VM, which does not reliably
pass `/dev/kvm` through to containers. Docker Engine installed directly in
Ubuntu uses the same kernel you just checked.

If Docker Desktop is installed, quit it (tray icon), or open its Settings →
Resources → WSL integration and turn integration off for Ubuntu, so the
`docker` command in Ubuntu is not taken over. Then, in Ubuntu:

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
```

The last command must print the device. If it does, continue with step 1
below **inside Ubuntu**, from your home folder:

```bash
cd ~
```

Keep the repos under `~/`, not `/mnt/c/...`: the Windows drive is slow from
WSL and breaks Linux file permissions, and cloning with Git for Windows can
convert the `.sh` scripts to CRLF line endings. In step 1, use the
`--exclude "*sandbox-runner-direct*"` variant to skip the file KVM mode does
not need, and the matching commands in step 2. In step 5 use the "With
`/dev/kvm`" commands. From Windows, the API is reachable at
`http://localhost:3112`.

### Alternatives

#### Alternative A: Hyper-V Linux VM

Works on Windows 10/11 Pro, Enterprise or Education (Intel CPUs on Windows
10; AMD needs Windows 11). Create an Ubuntu VM in Hyper-V Manager, shut it
down, enable nested virtualization from an administrator PowerShell, then
start it and follow this README inside the VM as on any Linux host:

```powershell
Set-VMProcessor -VMName <vm-name> -ExposeVirtualizationExtensions $true
```

#### Alternative B: no-KVM mode

If neither works, use the no-KVM mode in step 5. It runs on Docker Desktop
but with weaker isolation, for testing only.

## RHEL server + LibreChat on your own computer

Run the code interpreter on a RHEL 8/9 server and keep LibreChat on your
laptop or desktop. LibreChat reaches the server's API through an SSH tunnel,
so nothing but SSH is exposed: with the default `LOCAL_MODE=true` the API has
no authentication, and anyone who can reach port 3112 could run code on the
server.

```text
your computer                              RHEL server
LibreChat ──► localhost:3112 ══ SSH ══►  127.0.0.1:3112  code-interpreter api
                                          (every other port: 127.0.0.1 only)
```

> The RHEL-specific commands (dnf, firewalld, SELinux) follow Red Hat's and
> Docker's documentation but were not run on RHEL for this repo. The
> server override, the SSH tunnel and the container route through
> `host.docker.internal` were tested on Linux.

### What you need

| What | Notes |
|---|---|
| RHEL 8 or 9, x86_64 | 4+ vCPUs and 8 GB+ RAM recommended; the sandbox microVM alone is configured with 2 vCPUs and 2 GB. ~10 GB free disk. |
| `/dev/kvm` on the server | Bare metal, or a VM whose hypervisor exposes nested virtualization (VMware: "Expose hardware assisted virtualization to the guest OS"; KVM/libvirt hosts: nested enabled; cloud: an instance type that supports nested virtualization or bare metal). Without it, the no-KVM mode in step 5 works, for testing only. |
| Docker CE + Compose plugin | From Docker's RHEL repository (R2). Not Podman. |
| `git`, `git-lfs`, `openssl`, `curl` | `dnf` packages. |
| This repo's archives (~1.9 GB without the direct runner) and the `code-interpreter` repo at `v1.10.4` | As in steps 1–3. |
| `redis:7-alpine`, `cgr.dev/chainguard/minio` | Pulled on first start. No internet on the server? See R6. |
| SSH access from your computer to the server | Windows 10/11, macOS and Linux all include an `ssh` client. |

KVM mode needs no `build-packages.sh`; the runtimes are in the image.

### R1. Check for KVM (on the server)

```bash
grep -cE 'vmx|svm' /proc/cpuinfo   # more than 0: the CPU exposes virtualization
ls -l /dev/kvm
```

If `/dev/kvm` is missing but the first command prints a number above 0, load
the module (`sudo modprobe kvm_intel` or `sudo modprobe kvm_amd`) and check
again. If the first command prints `0`, the server (or its hypervisor) does
not expose virtualization: fix that, or use no-KVM mode.

### R2. Install Docker CE and tools

RHEL ships Podman by default, and it conflicts with Docker CE's packages, so
remove it first (skip this if other things on the server use Podman, and
ask whoever runs them):

```bash
sudo dnf remove -y podman runc buildah
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo dnf install -y git git-lfs openssl curl
sudo usermod -aG docker,kvm $USER
```

Log out and back in for the groups, then check:

```bash
docker compose version          # needs 2.24.4 or later
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

If `git-lfs` is not found, enable the AppStream repository
(`sudo subscription-manager repos --list-enabled`), or skip it and copy the
archives over from your computer instead:
`scp code-interpreter/v1.10.4/*.tar.gz code-interpreter/v1.10.4/SHA256SUMS <user>@<server>:~/Docker-files/code-interpreter/v1.10.4/`.

### R3. Set up the code interpreter (on the server)

Follow steps 1–4 above in your home folder (use the `--exclude` variant to
skip the direct runner). Then also copy the server override:

```bash
cp ../Docker-files/code-interpreter/v1.10.4/docker-compose.server.yml .
```

`docker-compose.server.yml` publishes every port on `127.0.0.1` only. The
upstream Compose file publishes all of them on every interface, including
the sandbox runner (which would let anyone skip the API), Redis (password
`localdev`) and MinIO (`minioadmin`/`minioadmin`). Docker's published ports
also bypass firewalld, so a firewall rule alone does not protect them.

Start it with three files:

```bash
docker compose -f docker-compose.yaml -f docker-compose.images.yml \
  -f docker-compose.server.yml up -d
docker compose -f docker-compose.yaml -f docker-compose.images.yml \
  -f docker-compose.server.yml ps
curl localhost:3112/v1/health     # OK
```

Run the step 6 checks on the server too.

After a reboot, Docker itself starts again (`systemctl enable` above), but
upstream's Compose file only gives the sandbox runner a restart policy. Run
the same `up -d` command after a reboot, or add `restart: unless-stopped` to
each service in `docker-compose.server.yml` to bring them all back
automatically.

SELinux: Docker CE does not turn on SELinux labeling for containers by
default, so the `/dev/kvm` device and bind mounts work as is. If you
enabled `"selinux-enabled": true` in `/etc/docker/daemon.json` and the
runner fails, check `sudo ausearch -m avc -ts recent`.

firewalld needs no change: only SSH (open by default) is used.

### R4. Open the tunnel (on your computer)

```bash
ssh -N -L 3112:127.0.0.1:3112 <user>@<server>
```

Leave it running. It forwards `localhost:3112` on your computer to the API on
the server. Check from another terminal: `curl localhost:3112/v1/health`.
Add `-o ServerAliveInterval=30` to keep it from idling out, or use `autossh`
to reconnect it automatically.

If LibreChat runs in Docker on a **Linux** computer, a container cannot reach
your computer's `127.0.0.1`. Make the tunnel listen on Docker's bridge
address as well:

```bash
ssh -N -L 172.17.0.1:3112:127.0.0.1:3112 <user>@<server>
```

On Docker Desktop (Windows, macOS) the plain command works.

### R5. Point LibreChat at it (on your computer)

In LibreChat's `.env`:

| LibreChat runs | Setting |
|---|---|
| Directly (`npm run backend`) | `LIBRECHAT_CODE_BASEURL=http://localhost:3112/v1` |
| In Docker | `LIBRECHAT_CODE_BASEURL=http://host.docker.internal:3112/v1` |

For Docker, the LibreChat service needs `host.docker.internal` mapped; if its
Compose file does not already have it, add to the `api` service:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

Restart LibreChat and enable the code interpreter on an agent. Its runs now
execute on the server; the tunnel must be open whenever you use it.

### R6. Server without internet access

Everything the server needs can be carried over as files. On a computer with
internet and Docker:

```bash
docker pull redis:7-alpine
docker pull cgr.dev/chainguard/minio:latest
docker save redis:7-alpine cgr.dev/chainguard/minio:latest | gzip > deps.tar.gz
```

Copy `deps.tar.gz`, this folder's archives and a checkout of the
`code-interpreter` repo (`git clone --branch v1.10.4 --depth 1 …`, then
`scp -r`) to the server, and run `docker load -i deps.tar.gz` there along with
step 2. Docker CE itself can be installed from downloaded RPMs (Docker's
"Install from a package" instructions).

### Exposing the API without a tunnel

Only do this with authentication on: set `LOCAL_MODE=false` and configure an
auth provider (the original repo's `scripts/setup-local-auth-env.js` writes
LibreChat JWT settings into both `.env` files), put TLS in front of it (a
reverse proxy), and then set `CODEAPI_API_BIND=0.0.0.0` before starting so
the server override publishes port 3112 on all interfaces. This path was not
tested for this repo.

## 1. Download the archives

The `.tar.gz` files are stored with Git LFS, so a plain download gives you
small pointer files instead. Clone with LFS installed:

```bash
git lfs install
git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files/code-interpreter/v1.10.4
```

If you cloned without LFS, run `git lfs pull` in the repo. To fetch only
some images (for example everything except the 359 MB direct runner):

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files
git lfs pull --exclude "*sandbox-runner-direct*"
cd code-interpreter/v1.10.4
```

## 2. Verify and load the images

There is nothing to extract by hand: `docker load` reads the gzipped archives
directly.

```bash
sha256sum -c SHA256SUMS
for f in *.tar.gz; do docker load -i "$f"; done
docker images 'ghcr.io/librechat-ai/*'
```

Each load prints `Loaded image: ghcr.io/librechat-ai/<name>:sha-a62d69e…`.

If you skipped the direct runner with `--exclude` in step 1, its file is
still there as a small LFS pointer, so leave it out of both commands:

```bash
grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c
for f in *.tar.gz; do
  [ "$f" = code-interpreter-sandbox-runner-direct.tar.gz ] || docker load -i "$f"
done
```

## 3. Get the matching Compose configuration

The images expect the Compose files from the same commit, so check out the
`v1.10.4` tag of the original repo next to this one and copy the override from
this folder into it:

```bash
cd ../../..   # back to the folder that holds Docker-files
git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
cp Docker-files/code-interpreter/v1.10.4/docker-compose.images.yml code-interpreter/
cd code-interpreter
```

`docker-compose.images.yml` switches every service from building to the
loaded images (with `pull_policy: never`, so a missing image fails fast
instead of downloading). It also replaces `quay.io/minio/minio`, which no
longer allows anonymous pulls, with `cgr.dev/chainguard/minio`.

## 4. Configure

```bash
cp .env.example .env
sed -i "s/^CODEAPI_BRIDGE_TOKEN=.*/CODEAPI_BRIDGE_TOKEN=$(openssl rand -hex 32)/" .env
```

The Compose defaults run in `LOCAL_MODE=true`: the API accepts requests
without an API key and uses development secrets. That is fine on your own
machine. Before exposing it to anyone else, set `LOCAL_MODE=false`, real
secrets (`CODEAPI_INTERNAL_SERVICE_TOKEN`, `CODEAPI_EGRESS_GRANT_SECRET`,
the execution manifest key pair) and an auth provider; the original repo's
`scripts/setup-local-auth-env.js` wires LibreChat JWT auth into both `.env`
files.

## 5. Start the stack

With `/dev/kvm` (default, microVM sandbox):

```bash
docker compose -f docker-compose.yaml -f docker-compose.images.yml up -d
docker compose -f docker-compose.yaml -f docker-compose.images.yml ps
```

`service-worker` waits until `sandbox-runner` reports healthy, which can take
a minute or two on first start.

### Without `/dev/kvm` (no-KVM mode, for testing)

Use this on Docker Desktop for Windows or Mac, or any host without `/dev/kvm`.
Sandboxed code shares the host kernel, so it is weaker isolation: use it only
on your own machine, never for code from people you don't trust.

On Windows, run every command in a WSL2 Ubuntu terminal (with Docker
Desktop's WSL integration turned on for that distro), and clone both repos
into your Ubuntu home folder (`~/`), not under `/mnt/c`. Cloning with Git for
Windows can turn the `.sh` scripts' line endings into CRLF, which breaks them.

1. Copy the no-KVM override next to the other one:

   ```bash
   cp ../Docker-files/code-interpreter/v1.10.4/docker-compose.direct.yml .
   ```

   It switches the runner to `code-interpreter-sandbox-runner-direct` and
   fixes what that image needs outside a microVM:

   - `/dev/null` mapped in place of `/dev/kvm`.
   - The Linux capabilities and seccomp profile from upstream's
     `docker-compose.mac.yml`. Without them the runner restarts in a loop
     with `unshare: Operation not permitted`.
   - A health check that works after the runner switches into the sandbox
     filesystem. Without it the worker never starts.
   - `SANDBOX_PIPE_ADDON`, which the published direct image is missing.
     Without it every run fails with `Cannot find module
     '/sandbox_api/.build/anonymous-pipes.node'`.
   - `SANDBOX_USE_CGROUPV2=false`, as upstream does for Docker Desktop.
     Without it hosts lacking a usable cgroup v2 tree fail every run with
     `Couldn't initialize cgroup 2 user namespace`. The cost: per-run memory
     and process-count limits are not enforced, one more reason to keep this
     mode for testing.

2. Build the language runtimes into `./data/pkgs`. The direct runner reads
   them from there; they are not inside the images. The script runs the build
   in a temporary Docker container, so it only needs Docker and internet.

   ```bash
   ./build-packages.sh
   ```

   The full build (Python with its data-science packages, Node, Bun and their
   npm packages) is slow: expect a long wait the first time. For a quicker
   first test, build Python alone:

   ```bash
   SKIP_PYTHON_PACKAGES=1 SKIP_JS_PACKAGES=1 SKIP_NODE=1 SKIP_BUN=1 ./build-packages.sh
   ```

   Run the full build later to add the rest; the sandbox only offers the
   languages it finds in `./data/pkgs`, read when it starts.

3. Start with all three Compose files:

   ```bash
   docker compose -f docker-compose.yaml -f docker-compose.images.yml \
     -f docker-compose.direct.yml up -d
   ```

   Use the same three `-f` flags for `ps`, `logs` and `down`. After building
   more runtimes, restart the runner with
   `docker compose -f docker-compose.yaml -f docker-compose.images.yml -f docker-compose.direct.yml restart sandbox-runner`.

## 6. Check it works

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

If `code` is `255` with empty output, NsJail failed to start the run; the
reason is in `docker logs sandbox-runner`. Logs for everything:
`docker compose -f docker-compose.yaml -f docker-compose.images.yml logs -f api service-worker sandbox-runner`
(add `-f docker-compose.direct.yml` in no-KVM mode).

## 7. Point LibreChat at it

In LibreChat's `.env`:

```bash
LIBRECHAT_CODE_BASEURL=http://<host running the stack>:3112/v1
```

Use `http://host.docker.internal:3112/v1` if LibreChat runs in Docker on the
same machine. Restart LibreChat and enable the code interpreter on an agent.

## Stop

```bash
docker compose -f docker-compose.yaml -f docker-compose.images.yml down      # keep data
docker compose -f docker-compose.yaml -f docker-compose.images.yml down -v   # also delete Redis/MinIO data
```

## Ports

| Port | Service |
|---|---|
| 3112 | API (what LibreChat calls) |
| 3190 | Egress gateway |
| 2000 | Sandbox runner |
| 13000 | File server |
| 16379 | Redis |
| 19000 / 19001 | MinIO API / console |
