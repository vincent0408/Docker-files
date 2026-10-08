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
- About 7 GB of disk for the archives plus the loaded images.

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

Without `/dev/kvm` (direct NsJail sandbox, weaker isolation, development
only): the direct runner reads the Python/Node/Bun runtimes from the host,
so build them first with the original repo's `./build-packages.sh` (it fills
`./data/pkgs`; this takes a while). Then:

```bash
export KVM_ENABLED=false
export KVM_DEVICE_PATH=/dev/null      # the Compose file always maps a KVM device
export CODEAPI_SANDBOX_RUNNER_IMAGE=code-interpreter-sandbox-runner-direct
docker compose -f docker-compose.yaml -f docker-compose.images.yml up -d
```

## 6. Check it works

```bash
curl localhost:3112/v1/health          # OK
curl localhost:13000/ready             # {"status":"ready","checks":{"redis":"ok","s3":"ok"}}
curl localhost:3190/health             # OK

curl -s localhost:3112/v1/exec \
  -H 'Content-Type: application/json' \
  -d '{"lang":"py","code":"print(6*7)"}'
```

The last call should return output containing `42`. Logs:
`docker compose -f docker-compose.yaml -f docker-compose.images.yml logs -f api service-worker sandbox-runner`.

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
