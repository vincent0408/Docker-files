# KVM runner patch (v1.10.4)

The published v1.10.4 KVM sandbox runner
(`ghcr.io/librechat-ai/code-interpreter-sandbox-runner:sha-a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`)
cannot run any code. This folder carries a small fix for it: a derived image
built from [`Dockerfile.runner-pipe-addon-fix`](Dockerfile.runner-pipe-addon-fix)
and used through [`docker-compose.kvm-fix.yml`](docker-compose.kvm-fix.yml).
[README.md](README.md) step B5b builds it. Path A (no-KVM) does not need it:
`docker-compose.direct.yml` already works around the same bug for the direct
runner.

## Symptom

Every execution fails, with or without LibreChat:

```text
$ curl -s localhost:3112/v1/exec -H 'Content-Type: application/json' -d '{"lang":"py","code":"print(42)"}'
{"error":"sandbox_execution_failed","message":"Sandbox execution failed"}
```

and `docker compose logs sandbox-runner` shows:

```text
Failed to spawn nsjail: Cannot find module '/sandbox_api/.build/anonymous-pipes.node'
Require stack: - /sandbox_api/.build/index.js
```

## Cause

Upstream commit #315 ("Harden Runner Supervisors with Anonymous Pipes", the
head of v1.10.4) added a native addon:

- `api/src/pipe-process.ts` loads it from `$SANDBOX_PIPE_ADDON`, falling back
  to `<__dirname>/../.build/anonymous-pipes.node`.
- `api/Dockerfile` puts the addon at `/usr/local/lib/anonymous-pipes.node` and
  sets `ENV SANDBOX_PIPE_ADDON=…` on the stage the guest disk is built from.
- In KVM mode that stage becomes an ext4 disk image, `/sandbox-rootfs.img`,
  which libkrun boots as a microVM. A Dockerfile `ENV` does not survive that
  conversion, so the variable is unset inside the guest.
- Setting it on the `sandbox-runner` container does not help either: the
  launcher only passes allowlisted variables into the guest
  (`is_allowed_guest_env_key` in `launcher/src/main.rs`), and
  `SANDBOX_PIPE_ADDON` is not on the list; anything not listed is dropped.
- So the guest uses the fallback path, which does not exist in the image.

Upstream `main` was one commit past v1.10.4 (`c854ab5`) with the same addon
handling when this was written; not fixed or reported upstream yet.

## The fix

No source rebuild. The Dockerfile copies `/sandbox-rootfs.img` out of the
published runner, checks the addon is there, adds one symlink inside the disk
image with `debugfs -w`, verifies it, runs `e2fsck -fn`, and puts the image
back:

```text
/sandbox_api/.build/anonymous-pipes.node -> /usr/local/lib/anonymous-pipes.node
```

Everything else in the runner image is unchanged. The result is tagged
`local/code-interpreter-sandbox-runner:v1.10.4-pipe-addon-fix`; the `local/`
prefix keeps it apart from images Compose builds itself (which it names
`code-interpreter-sandbox-runner`).

Building needs internet access (it pulls `debian:bookworm-slim` and installs
`e2fsprogs`) and about 9 GB of free disk while it runs, since the 4.4 GB guest
disk is copied between build stages. `docker builder prune` afterwards frees
the build cache; the finished image adds about 4.4 GB on top of the original
runner. For a different runner image, add
`--build-arg RUNNER_IMAGE=<image>` to the build.

## Verification

- Checked against the published image in this folder: the guest disk has
  `/usr/local/lib/anonymous-pipes.node` and no `/sandbox_api/.build/anonymous-pipes.node`;
  running the Dockerfile's `debugfs` steps on it creates the symlink and
  `e2fsck -fn` reports the filesystem clean.
- On Windows 11 with Docker Desktop (KVM mode, `LOCAL_MODE=true`), after
  recreating `sandbox-runner` on the patched image: `print(1+1)` via
  `POST /v1/exec` returned `"stdout":"2\n"`, `"code":0`, and the same call
  from inside the LibreChat container returned output; no new error lines in
  the runner log.
- Not yet tested: a full agent run in the LibreChat chat UI, file upload and
  download, and `/v1/exec/programmatic`.

## Removing it

When upstream forwards or bakes in `SANDBOX_PIPE_ADDON` for the KVM guest,
remove `:docker-compose.kvm-fix.yml` from `COMPOSE_FILE`, run
`docker compose up -d`, and delete the image with
`docker rmi local/code-interpreter-sandbox-runner:v1.10.4-pipe-addon-fix`.
