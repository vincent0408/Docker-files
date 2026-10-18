# Open WebUI v0.12.3 image

`docker save` archive (gzipped) of the default `linux/amd64` image of
[open-webui/open-webui](https://github.com/open-webui/open-webui)
release [v0.12.3](https://github.com/open-webui/open-webui/releases/tag/v0.12.3),
the newest release when this was added.

| File | Image | Size |
|---|---|---|
| `open-webui.tar.gz` | `ghcr.io/open-webui/open-webui:0.12.3` | 1.6 GB (6.4 GB loaded) |

Image ID `sha256:a537bbe1e6b428820f52ed4a029d7fff97062e24d5cf32c365fba36fd0542def`
(the same digest GHCR serves for the `0.12.3` tag). Built from upstream commit
`91ea4e3421d1d8069f13d4a463fcb5986d94ea60`.

This is the standard image (upstream's `main`/`latest` flavour, pinned to the
release): no bundled Ollama and no CUDA. The `:ollama`, `:cuda` and `slim`
variants are not included. Note that upstream's floating `latest` tag tracks
the `main` branch build, so it can differ from this release.

## Download and load

The archive is stored with Git LFS. To fetch only this image:

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "open-webui/**"
cd open-webui/v0.12.3
sha256sum -c SHA256SUMS            # must print: open-webui.tar.gz: OK
docker load -i open-webui.tar.gz
```

`docker load` reads the gzipped file directly and prints
`Loaded image: ghcr.io/open-webui/open-webui:0.12.3`. A ~134-byte
`open-webui.tar.gz` is still an LFS pointer: run the `git lfs pull` again.

After loading, the clone is not needed to run the container (it holds the
archive twice, in the folder and in `.git/lfs`); delete it to free about
3.2 GB.

## Run

Upstream's command, pinned to this version and bound to `localhost` only:

```bash
docker run -d --name open-webui --restart always \
  -p 127.0.0.1:3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:0.12.3
```

Open <http://localhost:3000>; the first account you create becomes the admin.
All data (users, chats, settings, the generated `WEBUI_SECRET_KEY`) lives in
the `open-webui` volume, so keep it when replacing the container. Leave out
`127.0.0.1:` only if other machines must reach it.

To point it at an Ollama running on the host, add
`-e OLLAMA_BASE_URL=http://host.docker.internal:11434`; for an OpenAI-compatible
API, add `-e OPENAI_API_KEY=...` (both can also be set later in the admin
settings). Other options are in the
[upstream docs](https://docs.openwebui.com/getting-started/env-configuration).

## Check it works

```bash
curl -s localhost:3000/health          # {"status":true}
curl -s localhost:3000/api/version     # {"version":"0.12.3",...}
```

The server takes about 30 seconds to start on first boot (database
migrations); `docker logs open-webui` shows progress.

## Update

Newer versions are not in this archive. To move to one, pull it from GHCR
(`docker pull ghcr.io/open-webui/open-webui:<version>`) and recreate the
container with the same volume, or ask for it to be added here as a new folder.
