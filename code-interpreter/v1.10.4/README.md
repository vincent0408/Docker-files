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

## Load

The files are stored with Git LFS; run `git lfs pull` after cloning.

```bash
sha256sum -c SHA256SUMS
for f in *.tar.gz; do docker load -i "$f"; done
```

Then follow the "Prebuilt images" section of the code-interpreter README with
`CODEAPI_IMAGE_TAG=sha-a62d69e05a4541ac9a20722ac7ff3fcfecb6ed24`, checking out
the `v1.10.4` tag so the Compose files match the images.
