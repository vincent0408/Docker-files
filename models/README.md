# Embedding and reranker models (FP8, for vLLM)

FP8 builds of Qwen's Qwen3 text embedding and reranking models, for RAG (for
example Open WebUI's document search) served with
[vLLM](https://docs.vllm.ai) on an NVIDIA GPU.

| Folder | Use | Size | Source (Hugging Face, pinned revision) | Base model |
|---|---|---|---|---|
| `Qwen3-Embedding-4B-FP8-Dynamic` | Embedding, 2560-dim | 4.4 GB | [`DCC-BS/Qwen3-Embedding-4B-FP8-Dynamic@70cb7033`](https://huggingface.co/DCC-BS/Qwen3-Embedding-4B-FP8-Dynamic/tree/70cb7033c83c32021a6fc57f8121d8fafdb7a42f) | Qwen/Qwen3-Embedding-4B |
| `Qwen3-Reranker-4B-FP8-Dynamic` | Reranking | 5.2 GB | [`DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic@d8c73748`](https://huggingface.co/DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic/tree/d8c73748705813c7ef6a3f69440e8d589db4164f) | Qwen/Qwen3-Reranker-4B |
| `Qwen3-Embedding-8B-FP8-DYNAMIC` | Embedding, 4096-dim | 8.2 GB | [`alexliap/Qwen3-Embedding-8B-FP8-DYNAMIC@3407c74e`](https://huggingface.co/alexliap/Qwen3-Embedding-8B-FP8-DYNAMIC/tree/3407c74e1c9933b2878e8ec3e8deb4065bc02d8d) | Qwen/Qwen3-Embedding-8B |
| `Qwen3-Reranker-8B-FP8` | Reranking | 9.4 GB | [`Forturne/Qwen3-Reranker-8B-FP8@9ee78a3d`](https://huggingface.co/Forturne/Qwen3-Reranker-8B-FP8/tree/9ee78a3d809f9ce3bcef4ab35694459cd93e9369) | Qwen/Qwen3-Reranker-8B |

All take up to 32K tokens of input and support 100+ languages. The base models
are Apache-2.0. Qwen publishes no official FP8 builds of these models, so
these are **community conversions** made with
[llm-compressor](https://github.com/vllm-project/llm-compressor) (scheme
`FP8_DYNAMIC`, `compressed-tensors` format: FP8 weights per channel, FP8
activations computed per token at run time; the reranker's output head stays
bf16). They contain no code, only weights and configuration.

**4B or 8B?** The 8B pair is more accurate (Qwen3-Embedding-8B is among the
top open models on the MTEB leaderboard) but needs about twice the GPU memory
and time. In FP8 the weights take about 4–5 GB per 4B model and 8–9 GB per
8B model, plus room for vLLM's cache.

## Requirements

- **An NVIDIA GPU and vLLM.** FP8 math runs natively on Ada and Hopper GPUs
  (compute capability 8.9+, for example RTX 40-series, L4, L40S, H100). On
  Ampere (RTX 30-series, A100) vLLM runs them through its Marlin kernels:
  memory use still halves, speed stays about the same as bf16.
- **Not for CPU, and not for Open WebUI's built-in model loader.** Open WebUI's
  local (Sentence Transformers) loader cannot run these files on a CPU, and
  even when they are expanded back to bf16 at load time they use more memory
  than the full-precision model. Serve them with vLLM and point Open WebUI at
  it, as below.

## Changes made here

Each folder is the source repository at the revision above, minus its own
`.gitattributes`, plus these files copied from Qwen's official repository
where the FP8 build lacked them or had a different version:

- `Qwen3-Reranker-4B-FP8-Dynamic`: `1_LogitScore/config.json` (from
  Qwen3-Reranker-4B@22e68366). Without it the model fails to load as a
  reranker in Sentence Transformers.
- `Qwen3-Embedding-8B-FP8-DYNAMIC`: `modules.json`, `1_Pooling/config.json`,
  `config_sentence_transformers.json` (from Qwen3-Embedding-8B@1d8ad4ca), which
  set last-token pooling, normalisation and the query prompt.
- `Qwen3-Reranker-8B-FP8`: `modules.json`, `1_LogitScore/config.json`,
  `config_sentence_transformers.json`, `sentence_bert_config.json`,
  `chat_template.jinja` and `tokenizer_config.json` (from
  Qwen3-Reranker-8B@77d193c7). The build had Qwen3's generic chat template
  instead of the reranker's prompt template.

After these changes every tokenizer and configuration file matches Qwen's
official one, except `config.json` and the weight index, which describe the
FP8 weights.

## Download

The weights are stored with Git LFS. To fetch one model folder:

```bash
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "models/Qwen3-Embedding-4B-FP8-Dynamic/**"
```

Repeat the last command with each folder you need. Don't use GitHub's
**Download ZIP**; it contains LFS pointers, not the weights.

## Join the split files

GitHub's LFS limit is 2 GB per file, so each weight file larger than that is
stored as `*.safetensors.part-00`, `part-01`, … Join them before use, inside
each model folder:

Linux / macOS:

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

## Serve with vLLM and use from Open WebUI

[`docker-compose.vllm.yml`](docker-compose.vllm.yml) runs three containers:
an embedding server, a reranker server (both vLLM, sharing one GPU) and
Open WebUI wired to them. From this `models` folder, after joining:

```bash
docker compose -f docker-compose.vllm.yml up -d
docker compose -f docker-compose.vllm.yml logs -f embed rerank   # wait for "Application startup complete"
```

It needs the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).
It uses the 4B pair; for the 8B pair, change the `--model` and
`--chat-template` paths. The settings that matter:

- **Embedding server:** `--runner pooling`. Older vLLM versions use
  `--task embed` instead.
- **Reranker server:** `--runner pooling` plus
  `--hf-overrides '{"architectures": ["Qwen3ForSequenceClassification"], "classifier_from_token": ["no", "yes"], "is_original_qwen3_reranker": true}'`,
  which tells vLLM to score with the model's `yes`/`no` answer, and
  `--chat-template …/chat_template.jinja`, Qwen's reranker prompt.
- **`--gpu-memory-utilization 0.35` each.** vLLM reserves this share of GPU
  memory per server. Raise it if each model has its own GPU.
- **Open WebUI:**
  - Embeddings use its OpenAI engine (`RAG_EMBEDDING_ENGINE=openai`) against
    vLLM's `/v1/embeddings`.
  - Reranking uses its external engine (`RAG_RERANKING_ENGINE=external`)
    against vLLM's `/v1/rerank`. Reranking runs only with hybrid search on.
  - `RAG_EMBEDDING_QUERY_PREFIX` adds the instruction Qwen's embedding models
    expect in front of search queries (Qwen reports a 1–5% gain).
- **First start only.** Open WebUI reads the `RAG_*` variables only on its
  first start and then keeps the values in its database. For an existing
  install, set them in **Admin Panel → Settings → Documents** instead:
  - Embedding engine *OpenAI*, URL `http://embed:8000/v1`, model
    `qwen3-embedding`.
  - Reranking engine *External*, URL `http://rerank:8000/v1/rerank`, model
    `qwen3-reranker`.
- Changing the embedding model means documents already uploaded must be
  re-indexed.

Quick checks once the servers are up:

```bash
curl -s localhost:8001/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-embedding","input":["hello"]}' | head -c 200
curl -s localhost:8002/v1/rerank -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-reranker","query":"What is the capital of China?","documents":["The capital of China is Beijing.","Gravity attracts bodies."]}'
```

The rerank answer should give the Beijing document a `relevance_score` close
to 1 and the other close to 0.

## Checked

- Every file matches the SHA256 its source repository publishes at the pinned
  revision, and rejoining the split parts reproduces it exactly.
- The tokenizers produce the same token IDs as Qwen's official ones (4B builds,
  tested on mixed-language, code and prompt text; the 8B builds' tokenizer
  files are byte-identical to Qwen's).
- The 4B pair, loaded on CPU with the weights expanded to bf16, gives results
  close to the full-precision models on Qwen's example:
  - embedding similarity 0.752 vs 0.751 for the matching document, and 0.103
    vs 0.093 for the unrelated one;
  - reranker score 6.19 vs 6.38 for the match, and −12.4 vs −11.8 for the
    unrelated one.

  The 4B builds' authors also report MTEB Wikipedia retrieval/reranking scores
  within about ±0.001 of bf16.
- **Not tested here:** the 8B models (too large for the test machine's memory)
  and anything on vLLM or a GPU. `docker-compose.vllm.yml` is checked to parse
  with Docker Compose; the vLLM flags follow vLLM's documentation for Qwen3
  rerankers, and the Open WebUI settings are checked against its 0.12.x source.
