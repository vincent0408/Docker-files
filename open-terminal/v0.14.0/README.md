# Open Terminal v0.14.0 image

`docker save` archive (gzipped) of the default `linux/amd64` image of
[open-webui/open-terminal](https://github.com/open-webui/open-terminal)
release [v0.14.0](https://github.com/open-webui/open-terminal/releases/tag/v0.14.0).

| File | Image | Size |
|---|---|---|
| `open-terminal.tar.gz` | `ghcr.io/open-webui/open-terminal:0.14.0` | 1.4 GB (5.7 GB loaded) |

Image ID `sha256:81a5394b3cd4ae32adb600f2135f09ee124de37f26b0a780e2f5692472c0fc5c`
(the same digest GHCR serves for the `0.14.0` tag).

Open Terminal is a self-hosted terminal that gives AI agents a sandboxed place
to run commands, manage files and execute code over a REST API. This is the
full variant upstream calls `latest` (AI agent sandbox): Python, Node.js, gcc,
ffmpeg, LibreOffice, LaTeX, Docker CLI and data science libraries, with `sudo`
for installing packages at runtime. The smaller `slim`, `alpine` and
`openshift` variants are not included.

## Download and load

The archive is stored with Git LFS. To fetch only this image:

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "open-terminal/**"
cd open-terminal/v0.14.0
sha256sum -c SHA256SUMS            # must print: open-terminal.tar.gz: OK
docker load -i open-terminal.tar.gz
```

`docker load` reads the gzipped file directly and prints
`Loaded image: ghcr.io/open-webui/open-terminal:0.14.0`. A ~134-byte
`open-terminal.tar.gz` is still an LFS pointer: run the `git lfs pull` again.

After loading, the clone is not needed to run the container (it holds the
archive twice, in the folder and in `.git/lfs`); delete it to free about
2.8 GB.

## Run

Upstream's command, pinned to this version and bound to `localhost` only:

```bash
docker run -d --name open-terminal --restart unless-stopped \
  -p 127.0.0.1:8000:8000 \
  -v open-terminal:/home/user \
  -e OPEN_TERMINAL_API_KEY="$(openssl rand -hex 32)" \
  ghcr.io/open-webui/open-terminal:0.14.0
docker logs open-terminal     # startup output; shows a generated key if you set none
```

Keep the API key somewhere safe: every API call needs it. Leave out `127.0.0.1:`
only if other machines must reach it, because anyone with the key can run
commands in the container.

## Check it works

```bash
KEY=<your api key>
curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:8000/execute \
  -H 'Content-Type: application/json' -d '{"command":"echo hi"}'          # 401 without the key
curl -s -X POST "localhost:8000/execute?wait=10" \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"command":"python3 -c \"print(6*7)\" && whoami && node --version"}'
```

The second request returns JSON with `"status":"done"`, `"exit_code":0` and
output `42`, `user`, `v22.23.2`. Interactive API docs:
<http://localhost:8000/docs>.

To use it from Open WebUI, see upstream's
[Using with Open WebUI](https://github.com/open-webui/open-terminal#using-with-open-webui)
section; configuration (config file, environment variables, extra packages,
Docker socket access and its risks) is in the
[upstream README](https://github.com/open-webui/open-terminal/blob/v0.14.0/README.md).

## Update

Newer versions are not in this archive. To move to one, pull it from GHCR
(`docker pull ghcr.io/open-webui/open-terminal:<version>`), or ask for it to be
added here as a new folder.
