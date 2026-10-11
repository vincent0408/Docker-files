# Agent instructions: set up the code interpreter in KVM mode (Windows 11, WSL2)

You are an AI agent running commands in the user's WSL2 Ubuntu terminal. Your
job: download this repo's images with Git LFS and bring up the LibreChat code
interpreter v1.10.4 in **KVM mode** (Path B of [README.md](README.md)), then
help connect LibreChat.

Read all of this file before running anything. [README.md](README.md) in this
folder is the human version of the same steps; when they differ, ask the user.

## Rules

1. **Ask, don't assume.** Every point marked **ASK** is a question for the user.
   Ask it, wait for the answer, and do not pick a default yourself. If an answer
   is unclear, ask again. Ask the start-up questions in Phase 0 together.
2. **Confirm before changing anything outside the working folders.** Before
   any of the following, show the user the exact command or edit and wait for a
   yes:
   - any `sudo` command (it may also need their password);
   - editing any Windows file (such as `.wslconfig`);
   - `docker compose down`, especially `down -v`, which deletes stored data;
   - `rm` or `rm -rf` of anything;
   - installing or removing software;
   - changing LibreChat's files.
3. **Never run these yourself:**
   - `wsl --shutdown`, `wsl --terminate` or restarting Docker Desktop. If you
     run inside WSL, this ends your own session. Ask the user to do it and to
     tell you when it is done.
   - BIOS changes or Windows settings. Explain what to change and let the user
     do it.
4. **Check every step.** Each step lists what success looks like. If the output
   does not match, stop, show the user the relevant output, explain what it
   means and ask how to proceed. Do not retry blindly more than once.
5. **Stop conditions.** Stop and report (don't work around) if: Windows is not
   Windows 11; `/dev/kvm` cannot be made to appear; a checksum fails twice; or
   the user says stop. KVM mode cannot work in those cases. Offer Path A
   (no-KVM, see README) as an option, but do not switch without the user's
   explicit choice.
6. **Keep a short log** of what you ran and what happened, and give it to the
   user at the end.
7. **Secrets.** Never print the value of `CODEAPI_BRIDGE_TOKEN` or other
   secrets back to the user or into logs; refer to them by name.

## Phase 0: Find out where the user is

Gather facts first (read-only, no confirmation needed):

```bash
uname -r; grep -i microsoft /proc/version >/dev/null && echo "WSL: yes"
docker info --format '{{.OperatingSystem}} | server {{.ServerVersion}}'
docker compose version
command -v git git-lfs openssl curl
ls -l /dev/kvm 2>&1
ls -d ~/Docker-files ~/code-interpreter 2>&1
[ -f ~/code-interpreter/.env ] && grep -E '^COMPOSE_(FILE|PROJECT_NAME)=' ~/code-interpreter/.env
docker images --format '{{.Repository}}' 'ghcr.io/librechat-ai/*'
[ -d ~/code-interpreter ] && (cd ~/code-interpreter && docker compose ps 2>&1 | head)
df -h ~ | tail -1
```

How to read them:

- **`OperatingSystem` says `Docker Desktop`:** the user runs Docker Desktop.
  Anything else (for example `Ubuntu …`): Docker Engine inside Ubuntu.
- **`COMPOSE_FILE` lists `docker-compose.direct.yml`:** Path A (no-KVM) is set
  up.
- **Free disk space:** the download needs about 2 GB per copy, and Git LFS
  stores each file twice, so plan for 4–5 GB free.

Then **ASK** the user, all together, adding what the facts already answered
for them to confirm:

1. Are you on **Windows 11**? (Run `winver` in Windows if unsure.) If they are
   on Windows 10, stop: rule 5.
2. Is this a **work-managed PC**? (An Intune policy can block nested
   virtualization; if so they may need IT.)
3. You found Path A set up / not set up. Should you **reuse the existing
   setup** (switch it to KVM mode) or **set up from scratch**? If from scratch
   while one exists, ask whether to keep or delete the old one.
4. Is the code interpreter **currently running and in use**? You will need to
   stop it during the switch. Ask when that is OK.
5. **How does LibreChat run:** not installed yet, directly (`npm run
   backend`), or in Docker? Where is its folder? (Needed in Phase 6.)
6. Do they want you to **delete the downloaded clone** at the end to free about
   4 GB? (They can re-clone later.)

Do not continue until all six are answered.

## Phase 1: Nested virtualization (user acts in Windows)

Skip to Phase 2 if `ls -l /dev/kvm` already printed the device.

1. Tell the user to check Task Manager → Performance → CPU shows
   "Virtualization: Enabled". If not, it must be turned on in the BIOS/UEFI
   (Intel VT-x or AMD-V/SVM). They do this, not you.
2. `.wslconfig` needs this under `[wsl2]`:

   ```ini
   [wsl2]
   nestedVirtualization=true
   ```

   Find the Windows user folder (read-only):

   ```bash
   WINHOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
   echo "$WINHOME"; cat "$WINHOME/.wslconfig" 2>&1
   ```

   **ASK**: "May I add `nestedVirtualization=true` under `[wsl2]` in
   `<path>/.wslconfig`? Current contents: …" Show the exact resulting file.
   Only edit it after a yes. Keep everything else in the file unchanged. If the
   user prefers to edit it themselves, give them the lines.

   Don't add a `memory=` line unless the user asks: WSL2 already gets half of
   the RAM, and KVM mode needs about 2.3 GB (README, "Memory").
3. Tell the user, and wait for them to confirm each:
   1. Quit Docker Desktop (tray icon → Quit).
   2. In **PowerShell**: `wsl --shutdown`. (This closes your session; they
      will need to start you again and tell you to continue at Phase 2.)
   3. Start Docker Desktop again and wait until it is running.

## Phase 2: Check KVM

```bash
ls -l /dev/kvm
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

| `ls -l /dev/kvm` | `docker run` line | Do |
|---|---|---|
| prints the device | prints the device | Continue to Phase 3. |
| prints the device | error | Docker Desktop is not passing KVM. Explain the fallback (README B4: Docker Engine inside Ubuntu, which replaces Docker Desktop for this and means loading every image again) and **ASK** whether to do it. Do not install anything without a yes. |
| "No such file" | — | **ASK** to run `sudo modprobe kvm_intel` (Intel) or `sudo modprobe kvm_amd` (AMD; check `grep -m1 -o -E 'vmx|svm' /proc/cpuinfo`: `vmx` is Intel, `svm` AMD), then re-check. Still missing: go back over Phase 1 with the user (BIOS, Windows 11, file name `.wslconfig` not `.wslconfig.txt`, `wsl --shutdown` done). If still missing: stop, rule 5. |

Once both work, **ASK** to run `sudo usermod -aG kvm $USER` (it takes effect in
new terminals).

## Phase 3: Tools and download

Install missing tools only after asking (rule 2):

```bash
sudo apt-get update && sudo apt-get install -y git git-lfs openssl curl
git lfs install
```

Check: `docker compose version` must be **2.24.4 or later** (the Compose files
use `!reset` and `!override`). If older, stop and tell the user to update
Docker Desktop.

**Reusing Path A** (answer 3), when the other images are already loaded:

```bash
cd ~/Docker-files && git pull
git lfs pull --include "*sandbox-runner.tar.gz"
```

**From scratch:**

```bash
cd ~
[ -d Docker-files ] || GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git pull && git lfs pull --exclude "*sandbox-runner-direct*"
```

These downloads are large (up to about 1.9 GB) and can take a while; tell the
user before starting, and report when done.

## Phase 4: Check and load the images

In `~/Docker-files/code-interpreter/v1.10.4`:

1. **Download complete?** `ls -lh *.tar.gz`. Files you need must be large
   (`code-interpreter-sandbox-runner.tar.gz` about 1.3G, others about 100M). A
   file of about **134 bytes** is still an LFS pointer. If one you need is that
   small, run the same `git lfs pull …` again once, then stop (rule 4).
2. **Checksums.** Reusing Path A:

   ```bash
   grep ' code-interpreter-sandbox-runner.tar.gz' SHA256SUMS | sha256sum -c
   ```

   From scratch:

   ```bash
   grep -v sandbox-runner-direct SHA256SUMS | sha256sum -c
   ```

   Every line must end in `OK`. For a `FAILED` file, repair once, then
   re-check; if it fails again, stop (rule 5):

   ```bash
   cd ~/Docker-files
   rm code-interpreter/v1.10.4/<file>.tar.gz
   git lfs fsck
   git lfs pull --include "*<file>.tar.gz"
   ```

   (The `rm` is of a corrupt download inside the clone; tell the user, but it
   does not need a separate yes.)
3. **Load.** Reusing Path A:

   ```bash
   docker load -i code-interpreter-sandbox-runner.tar.gz
   ```

   From scratch:

   ```bash
   for f in *.tar.gz; do
     [ "$f" = code-interpreter-sandbox-runner-direct.tar.gz ] || docker load -i "$f"
   done
   ```

   Each prints `Loaded image: ghcr.io/librechat-ai/<name>:sha-a62d69e…`.
4. **Confirm:** `docker images 'ghcr.io/librechat-ai/*'` must list
   `code-interpreter-api`, `-worker`, `-file-server`, `-egress-gateway`,
   `-tool-call-server` and `-sandbox-runner`. Having `-sandbox-runner-direct`
   too is fine.

## Phase 5: Configure and start

**Reusing Path A:** if the stack is running, **ASK** to stop it (per answer 4)
with `cd ~/code-interpreter && docker compose down` (no `-v`, so stored files
stay). Then switch `.env` to KVM mode:

```bash
cd ~/code-interpreter
cp .env .env.before-kvm
sed -i 's#:docker-compose.direct.yml##' .env
grep ^COMPOSE_FILE .env
```

`COMPOSE_FILE` must now be
`docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml`.

**From scratch:**

```bash
cd ~
[ -d code-interpreter ] || git clone --branch v1.10.4 --depth 1 https://github.com/LibreChat-AI/code-interpreter.git
cp Docker-files/code-interpreter/v1.10.4/docker-compose.{images,server}.yml code-interpreter/
cd code-interpreter
[ -f .env ] && cp .env .env.backup
cp .env.example .env
sed -i "s/^CODEAPI_BRIDGE_TOKEN=.*/CODEAPI_BRIDGE_TOKEN=$(openssl rand -hex 32)/" .env
cat >> .env <<'EOF'

# --- Path B: KVM ---
COMPOSE_PROJECT_NAME=code-interpreter
COMPOSE_FILE=docker-compose.yaml:docker-compose.images.yml:docker-compose.server.yml
EOF
```

If `~/code-interpreter` already existed, **ASK** before overwriting its `.env`
(the backup above keeps the old one).

Verify the configuration before starting:

```bash
docker compose config sandbox-runner | grep -E 'image:|/dev/kvm|KVM_ENABLED'
```

It must show the `code-interpreter-sandbox-runner` image (not `-direct`),
`/dev/kvm` and `KVM_ENABLED: "true"`.

Start and wait (first start can take a minute or two):

```bash
docker compose up -d
for i in $(seq 60); do   # up to 5 minutes
  [ "$(docker inspect -f '{{.State.Health.Status}}' sandbox-runner 2>/dev/null)" = healthy ] && break
  sleep 5
done
docker inspect -f '{{.State.Health.Status}}' sandbox-runner
docker compose ps
```

The second-to-last line must print `healthy`. If it doesn't, or
`sandbox-runner` keeps restarting, collect
`docker compose logs --tail 80 sandbox-runner`, show the user and stop.

Test:

```bash
curl -s localhost:3112/v1/health
curl -s localhost:3112/v1/exec -H 'Content-Type: application/json' \
  -d '{"lang":"py","code":"print(6*7)\nopen(\"/mnt/data/hello.txt\",\"w\").write(\"hi\")"}'
```

Success: `OK`, then JSON with `"stdout":"42\n"`, `"code":0` and a `files` entry
for `hello.txt`. Download it with the response's `session_id` and file `id`:

```bash
curl -s "localhost:3112/v1/download/<session_id>/<file id>?kind=user"   # prints: hi
```

If `code` is `255`, show `docker compose logs --tail 80 sandbox-runner` and
stop. If `curl` to `localhost` is refused from Ubuntu while `docker compose ps`
shows `api` up, see README "Troubleshooting".

## Phase 6: Connect LibreChat

Use answer 5. In every case, **ASK** before editing LibreChat's files, and
show the exact lines first.

| LibreChat runs | Lines for LibreChat's `.env` |
|---|---|
| Directly (`npm run backend`) | `LIBRECHAT_CODE_BASEURL=http://localhost:3112/v1` and `LIBRECHAT_CODE_API_KEY=local-no-auth` |
| In Docker (same Docker as the code interpreter) | `LIBRECHAT_CODE_BASEURL=http://code-interpreter-api:3112/v1` and `LIBRECHAT_CODE_API_KEY=local-no-auth` |

If either variable already exists in LibreChat's `.env`, replace it rather than
adding a duplicate, and tell the user the old value was replaced.

For **LibreChat in Docker**, it also needs to join the code interpreter's
network. In the LibreChat folder, `docker-compose.override.yml` needs:

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

If the file already exists, merge into it (each service name may appear only
once) and show the user the result before saving. Then **ASK** before
restarting LibreChat (`docker compose down && docker compose up -d` in its
folder). Check from inside LibreChat's container:

```bash
docker exec LibreChat sh -c 'wget -qO- http://code-interpreter-api:3112/v1/health || curl -s http://code-interpreter-api:3112/v1/health'
```

It must print `OK`. (`LibreChat` is the usual container name; check
`docker ps` if different.)

Finally, tell the user to enable the code interpreter on an agent in
LibreChat and try it.

## Phase 7: Finish

1. If the user said yes to answer 6, **ASK** once more, then:
   `rm -rf ~/Docker-files`. Tell them the stack does not need it (Compose uses
   the copies in `~/code-interpreter`) and they can re-clone to reload.
2. Report to the user:
   - what was done (the log from rule 6);
   - test results (health, `42`, file download, LibreChat check);
   - day-to-day commands, run in `~/code-interpreter`: start
     `docker compose up -d`, status `docker compose ps`, stop
     `docker compose down`, logs `docker compose logs -f sandbox-runner service-worker`;
   - after a reboot or Docker Desktop restart, run `docker compose up -d`
     again;
   - how to go back to no-KVM mode if Path A was set up before: add
     `docker-compose.direct.yml` back after `docker-compose.images.yml` in
     `COMPOSE_FILE` (or restore `.env.before-kvm`) and `docker compose up -d`.
3. Security reminder: the API runs with `LOCAL_MODE=true` (no authentication)
   and is only reachable on `127.0.0.1`; it must not be exposed to other
   machines.
