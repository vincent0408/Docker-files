# Embedding and reranker models (FP8, for vLLM)

FP8 builds of Qwen's Qwen3 text embedding and reranking models, served with
[vLLM](https://docs.vllm.ai) on an NVIDIA GPU. All based on Qwen's Apache-2.0
models.

| Folder (in `vllm/`) | Use | Size | Source on Hugging Face (pinned revision) |
|---|---|---|---|
| `Qwen3-Embedding-4B-FP8-Dynamic` | Embedding, 2560-dim | 4.4 GB | [`DCC-BS/Qwen3-Embedding-4B-FP8-Dynamic@70cb7033`](https://huggingface.co/DCC-BS/Qwen3-Embedding-4B-FP8-Dynamic/tree/70cb7033c83c32021a6fc57f8121d8fafdb7a42f) |
| `Qwen3-Reranker-4B-FP8-Dynamic` | Reranking | 5.2 GB | [`DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic@d8c73748`](https://huggingface.co/DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic/tree/d8c73748705813c7ef6a3f69440e8d589db4164f) |
| `Qwen3-Embedding-8B-FP8-DYNAMIC` | Embedding, 4096-dim | 8.2 GB | [`alexliap/Qwen3-Embedding-8B-FP8-DYNAMIC@3407c74e`](https://huggingface.co/alexliap/Qwen3-Embedding-8B-FP8-DYNAMIC/tree/3407c74e1c9933b2878e8ec3e8deb4065bc02d8d) |
| `Qwen3-Reranker-8B-FP8` | Reranking | 9.4 GB | [`Forturne/Qwen3-Reranker-8B-FP8@9ee78a3d`](https://huggingface.co/Forturne/Qwen3-Reranker-8B-FP8/tree/9ee78a3d809f9ce3bcef4ab35694459cd93e9369) |

All take up to 32K tokens of input and support 100+ languages.

**4B or 8B?** The 8B pair is more accurate (Qwen3-Embedding-8B is among the
top open models on the MTEB leaderboard) but needs about twice the GPU memory
and time: weights of about 4–5 GB per 4B model and 8–9 GB per 8B model, plus
vLLM's cache.

## Requirements

An NVIDIA GPU with vLLM. FP8 runs natively on Ada and Hopper GPUs (compute
capability 8.9+: RTX 40-series, L4, L40S, H100). On Ampere (RTX 30-series,
A100) vLLM still loads them with half the memory of bf16, but not faster.
They are not meant for CPU use.

## About these builds

Qwen publishes no FP8 versions, so these are **community conversions** made
with [llm-compressor](https://github.com/vllm-project/llm-compressor) (scheme
`FP8_DYNAMIC`, `compressed-tensors` format: FP8 weights per channel, FP8
activations computed per token at run time; rerankers keep their output head
in bf16). They contain no code, only weights and configuration.

Each folder is the source repository at the revision above, minus its own
`.gitattributes`, plus these files copied from Qwen's official repository
where the build lacked them or had a different version:

- `Qwen3-Reranker-4B-FP8-Dynamic`: `1_LogitScore/config.json`.
- `Qwen3-Embedding-8B-FP8-DYNAMIC`: `modules.json`, `1_Pooling/config.json`,
  `config_sentence_transformers.json` (last-token pooling, normalisation,
  query prompt).
- `Qwen3-Reranker-8B-FP8`: the Sentence Transformers config, plus Qwen's
  reranker `chat_template.jinja` and `tokenizer_config.json`. The build had
  Qwen3's generic chat template instead of the reranker prompt.

Now every tokenizer and configuration file matches Qwen's official one,
except `config.json` and the weight index, which describe the FP8 weights.

## Download and join

The weights are stored with Git LFS. To fetch one model folder:

```bash
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "models/vllm/Qwen3-Embedding-4B-FP8-Dynamic/**"
```

Repeat the last command for each folder you need. Don't use GitHub's
**Download ZIP**; it contains LFS pointers, not the weights.

GitHub's LFS limit is 2 GB per file, so larger weight files are stored as
`*.safetensors.part-00`, `part-01`, … Join them inside each model folder:

```bash
for p in *.safetensors.part-00; do
  f="${p%.part-00}"; cat "$f".part-* > "$f" && rm "$f".part-*
done
sha256sum -c SHA256SUMS        # every line must say OK  (macOS: shasum -a 256 -c SHA256SUMS)
```

Windows PowerShell:

```powershell
Get-ChildItem *.safetensors.part-00 | ForEach-Object {
  $f = $_.FullName -replace '\.part-00$', ''
  cmd /c copy /b ((Get-ChildItem "$f.part-*" | Sort-Object Name).FullName -join '+') "$f"
  Remove-Item "$f.part-*"
}
```

Then compare `Get-FileHash *.safetensors` with the hashes in `SHA256SUMS`.

## Serve with vLLM

[`vllm/docker-compose.yml`](vllm/docker-compose.yml) runs an embedding server
and a reranker server on one GPU. From the `models/vllm` folder, after
joining:

```bash
docker compose up -d
docker compose logs -f     # wait for "Application startup complete" from both
```

It needs the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
It serves the 4B pair; for the 8B pair, change the `/models/...` paths.

| Server | Port | Model name | Endpoint |
|---|---|---|---|
| Embedding | 8001 | `qwen3-embedding` | `/v1/embeddings` (OpenAI-compatible) |
| Reranker | 8002 | `qwen3-reranker` | `/v1/rerank` (Jina/Cohere-style) |

The settings that matter:

- **Both servers:** `--runner pooling`. Older vLLM versions use `--task embed`
  instead for the embedding server.
- **Reranker:**
  - `--hf-overrides '{"architectures": ["Qwen3ForSequenceClassification"], "classifier_from_token": ["no", "yes"], "is_original_qwen3_reranker": true}'`
    makes vLLM score each document by the model's `yes`/`no` answer.
  - `--chat-template …/chat_template.jinja` is Qwen's reranker prompt.
- **`--gpu-memory-utilization 0.35` each.** vLLM reserves this share of GPU
  memory per server. Raise it if each model has its own GPU.
- **`--max-model-len 8192`** limits input length to save memory. The models
  accept up to 32768.

To run without Docker, the same flags work with `vllm serve`:

```bash
vllm serve ./Qwen3-Embedding-4B-FP8-Dynamic --served-model-name qwen3-embedding \
  --runner pooling --max-model-len 8192 --port 8001
```

## Use

```bash
curl -s localhost:8001/v1/embeddings -H 'Content-Type: application/json' -d '{
  "model": "qwen3-embedding",
  "input": ["Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:What is the capital of China?",
            "The capital of China is Beijing."]
}'

curl -s localhost:8002/v1/rerank -H 'Content-Type: application/json' -d '{
  "model": "qwen3-reranker",
  "query": "What is the capital of China?",
  "documents": ["The capital of China is Beijing.", "Gravity attracts bodies."]
}'
```

- **Embedding queries:** Qwen's embedding models work best when search
  queries (not the documents being indexed) start with a one-line task
  instruction, `Instruct: <task>\nQuery:<the query>`, as above. Qwen reports
  a 1–5% gain.
- **Reranker:** it takes the plain query and documents. The Beijing document
  should get a `relevance_score` close to 1, and the other close to 0.

## Checked

- Every file matches the SHA256 its source repository publishes at the pinned
  revision, and rejoining the split parts reproduces it exactly.
- The tokenizers produce the same token IDs as Qwen's official ones. For the
  4B builds this was tested on mixed-language, code and prompt text; the 8B
  builds' tokenizer files are byte-identical to Qwen's.
- The 4B pair, loaded on CPU with the weights expanded to bf16, gives results
  close to the full-precision models on Qwen's example:
  - embedding similarity 0.752 vs 0.751 for the matching document, and 0.103
    vs 0.093 for the unrelated one;
  - reranker score 6.19 vs 6.38 for the match, and −12.4 vs −11.8 for the
    unrelated one.

  The 4B builds' authors also report MTEB Wikipedia retrieval/reranking scores
  within about ±0.001 of bf16.
- **Not tested here:** the 8B models (too large for the test machine's memory)
  and anything on vLLM or a GPU. `docker-compose.yml` is checked to parse with
  Docker Compose, and the vLLM flags follow vLLM's documentation for Qwen3
  models.
