# Embedding and reranker models

Qwen3 text embedding models for **Ollama**, and Qwen3 reranker models for
**vLLM** (Ollama has no rerank API). All based on Qwen's Apache-2.0 models.

| Folder | Use | Format | Size |
|---|---|---|---|
| `ollama/qwen3-embedding-4b-q8_0` | Embedding, 2560-dim | Ollama model `qwen3-embedding:4b-q8_0` | 4.3 GB |
| `ollama/qwen3-embedding-8b-q8_0` | Embedding, 4096-dim | Ollama model `qwen3-embedding:8b-q8_0` | 8.0 GB |
| `vllm/Qwen3-Reranker-4B-FP8-Dynamic` | Reranking | FP8 safetensors for vLLM | 5.2 GB |
| `vllm/Qwen3-Reranker-8B-FP8` | Reranking | FP8 safetensors for vLLM | 9.4 GB |

All take up to 32K tokens of input and support 100+ languages. **4B or 8B?**
The 8B models are more accurate (Qwen3-Embedding-8B is among the top open
models on the MTEB leaderboard) but need about twice the memory and time.

Everything is stored with Git LFS. Don't use GitHub's **Download ZIP**; it
contains LFS pointers, not the files. Files over GitHub's 2 GB LFS limit are
split into `.part-00`, `.part-01`, …; the steps below join them.

## Embeddings with Ollama

Each folder holds the model exactly as Ollama's library ships it
(`ollama pull qwen3-embedding:4b-q8_0` / `:8b-q8_0`): its manifest and data
files, packed as a tar and split into parts. Q8_0 is Ollama's 8-bit format;
quality is practically the same as full precision.

**1. Download** (here the 4B; use `8b` for the other):

```bash
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "models/ollama/qwen3-embedding-4b-q8_0/**"
cd models/ollama/qwen3-embedding-4b-q8_0
cat *.tar.part-* | sha256sum      # must equal the hash in SHA256SUMS
```

**2. Restore into Ollama.** This joins the parts and unpacks them into
Ollama's model folder in one step. Pick the line for your setup:

```bash
# Ollama installed on Linux/macOS (default model folder; use $OLLAMA_MODELS if you set it)
cat *.tar.part-* | tar -xf - -C ~/.ollama/models

# Ollama in Docker (container named "ollama")
cat *.tar.part-* | docker exec -i ollama tar -xf - -C /root/.ollama/models

# Ollama installed as a Linux service (models owned by the "ollama" user)
cat *.tar.part-* | sudo tar -xf - -C /usr/share/ollama/.ollama/models --no-same-owner
sudo chown -R ollama:ollama /usr/share/ollama/.ollama/models
```

Windows PowerShell (Ollama for Windows, default folder):

```powershell
cmd /c copy /b ((Get-ChildItem *.tar.part-* | Sort-Object Name).FullName -join '+') model.tar
tar -xf model.tar -C "$env:USERPROFILE\.ollama\models"
Remove-Item model.tar
```

No restart is needed. `ollama list` now shows `qwen3-embedding:4b-q8_0`.

**3. Use it** through Ollama's embedding API:

```bash
curl -s http://localhost:11434/api/embed -d '{
  "model": "qwen3-embedding:4b-q8_0",
  "input": ["Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:What is the capital of China?",
            "The capital of China is Beijing."]
}'
```

Ollama's OpenAI-compatible endpoint (`/v1/embeddings`) works too. Vectors
come back normalised (length 1), so cosine similarity is a dot product.

Qwen's embedding models work best when **search queries** start with a
one-line task instruction in the form
`Instruct: <task>\nQuery:<the query>`, as above. Qwen reports a 1–5% gain.
Documents being indexed are sent as plain text, with no instruction.

## Reranking with vLLM

Ollama cannot serve rerankers, so these run on [vLLM](https://docs.vllm.ai),
which needs an **NVIDIA GPU**. FP8 runs natively on Ada and Hopper GPUs
(compute capability 8.9+: RTX 40-series, L4, L40S, H100). On Ampere (RTX
30-series, A100) vLLM still loads them with half the memory of bf16, but not
faster.

They are community FP8 conversions (Qwen publishes none), pinned to exact
revisions:

| Folder | Source on Hugging Face |
|---|---|
| `Qwen3-Reranker-4B-FP8-Dynamic` | [`DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic@d8c73748`](https://huggingface.co/DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic/tree/d8c73748705813c7ef6a3f69440e8d589db4164f) |
| `Qwen3-Reranker-8B-FP8` | [`Forturne/Qwen3-Reranker-8B-FP8@9ee78a3d`](https://huggingface.co/Forturne/Qwen3-Reranker-8B-FP8/tree/9ee78a3d809f9ce3bcef4ab35694459cd93e9369) |

Both were made with [llm-compressor](https://github.com/vllm-project/llm-compressor)
(`FP8_DYNAMIC`, `compressed-tensors` format; the output head stays bf16) and
contain no code. I copied in files from Qwen's official repositories where
the builds lacked them:

- 4B: `1_LogitScore/config.json`.
- 8B: the Sentence Transformers config, plus Qwen's reranker
  `chat_template.jinja` and `tokenizer_config.json`. The build had Qwen3's
  generic chat template instead of the reranker prompt.

Each folder's tokenizer and configuration files now match Qwen's official
ones, except `config.json` and the weight index, which describe the FP8
weights.

**1. Download and join** (inside each reranker folder you need):

```bash
git lfs pull --include "models/vllm/Qwen3-Reranker-4B-FP8-Dynamic/**"
cd models/vllm/Qwen3-Reranker-4B-FP8-Dynamic
for p in *.safetensors.part-00; do
  f="${p%.part-00}"; cat "$f".part-* > "$f" && rm "$f".part-*
done
sha256sum -c SHA256SUMS        # every line must say OK
```

**2. Serve** with [`vllm/docker-compose.yml`](vllm/docker-compose.yml), from
the `models/vllm` folder:

```bash
docker compose up -d && docker compose logs -f   # wait for "Application startup complete"
```

It needs the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
and serves the 4B reranker; for the 8B one, change the two `/models/...`
paths. The settings that matter:

- `--runner pooling` with
  `--hf-overrides '{"architectures": ["Qwen3ForSequenceClassification"], "classifier_from_token": ["no", "yes"], "is_original_qwen3_reranker": true}'`
  makes vLLM score each document by the model's `yes`/`no` answer.
- `--chat-template …/chat_template.jinja` is Qwen's reranker prompt.

**3. Use it:**

```bash
curl -s localhost:8002/v1/rerank -H 'Content-Type: application/json' -d '{
  "model": "qwen3-reranker",
  "query": "What is the capital of China?",
  "documents": ["The capital of China is Beijing.", "Gravity attracts bodies."]
}'
```

The Beijing document should get a `relevance_score` close to 1 and the other
close to 0.

## Checked

- **Ollama embeddings**, on Ollama 0.40.7 (CPU):
  - Each export was restored into an empty Ollama with the commands above
    (joined parts matched `SHA256SUMS`) and queried through `/api/embed`.
  - On the example above, cosine similarity for the matching / unrelated
    document: 4B 0.750 / 0.094 (full precision: 0.751 / 0.093), 8B
    0.748 / 0.078.
- **FP8 rerankers:**
  - Every file matches its source repository's SHA256, and the split parts
    rejoin exactly.
  - The 4B one, loaded on CPU with the weights expanded to bf16, scores
    6.19 / −12.4 against 6.38 / −11.8 for full precision. Its tokenizer gives
    the same token IDs as Qwen's.
  - **Not run on vLLM or a GPU** (none available), and the 8B one was not run
    at all (not enough memory). The vLLM flags follow vLLM's documentation for
    Qwen3 rerankers, and the Compose file is checked to parse.
