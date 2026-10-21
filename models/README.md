# Embedding and reranker models (GGUF, for llama.cpp)

Qwen3 text embedding and reranking models in Q8_0 GGUF format, for
[llama.cpp](https://github.com/ggml-org/llama.cpp)'s `llama-server`. It runs
natively on Windows with CUDA, including on V100 GPUs. All are based on
Qwen's Apache-2.0 models.

| Folder | Use | Size | Source |
|---|---|---|---|
| `Qwen3-Embedding-4B-Q8_0` | Embedding, 2560-dim | 4.3 GB | Qwen's official GGUF, [`Qwen/Qwen3-Embedding-4B-GGUF@f4602530`](https://huggingface.co/Qwen/Qwen3-Embedding-4B-GGUF/tree/f4602530db1d980e16da9d7d3a70294cf5c190be) |
| `Qwen3-Reranker-4B-Q8_0` | Reranking | 4.3 GB | Converted from [`Qwen/Qwen3-Reranker-4B@22e68366`](https://huggingface.co/Qwen/Qwen3-Reranker-4B/tree/22e683669bc0f0bd69640a1354a6d0aebcfeede5) |
| `Qwen3-Embedding-8B-Q8_0` | Embedding, 4096-dim | 8.0 GB | Qwen's official GGUF, [`Qwen/Qwen3-Embedding-8B-GGUF@69d0e58a`](https://huggingface.co/Qwen/Qwen3-Embedding-8B-GGUF/tree/69d0e58a13e463cd99a9b83e3f5fee7c10265fab) |
| `Qwen3-Reranker-8B-Q8_0` | Reranking | 8.0 GB | Converted from [`Qwen/Qwen3-Reranker-8B@77d193c7`](https://huggingface.co/Qwen/Qwen3-Reranker-8B/tree/77d193c791ed757ca307ee72715aa132723da912) |

- **Q8_0** is llama.cpp's 8-bit format; quality is practically the same as
  full precision (see *Checked* below).
- **Embedding files** are exactly Qwen's published Q8_0 files. They are also
  the same files Ollama ships as `qwen3-embedding:4b-q8_0` / `:8b-q8_0`.
- **Rerankers:** Qwen publishes no GGUF of them, so I converted the official
  models with llama.cpp's own converter (release b11796,
  `convert_hf_to_gguf.py --outtype q8_0`). It builds the yes/no scoring head
  the reranker uses.
- **4B or 8B?** The 8B models are more accurate (Qwen3-Embedding-8B is among
  the top open models on the MTEB leaderboard), but need about twice the
  memory and time.

### Fitting on a V100

GPU memory per server with `-c 8192 -ub 8192`. These are llama.cpp's own
buffer sizes, plus a few hundred MB per process for CUDA itself:

| Model | Weights | Context cache | Working buffer | Total, about |
|---|---|---|---|---|
| 4B (embedding or reranker) | 4.0 GiB | 1.1 GiB | 0.35 GiB | 5.5 GiB |
| 8B (embedding or reranker) | 7.7 GiB | 1.1 GiB | 0.47 GiB | 9.3 GiB |

| V100 | What fits |
|---|---|
| 16 GB | the 4B pair (about 11 GiB), or one 8B model plus one 4B model |
| 32 GB | the 8B pair (about 19 GiB) |

`-c 4096 -ub 4096` saves about 0.6 GiB per server. The V100 (Volta) can't
use FP8 or bf16, but llama.cpp runs Q8_0 on it in fp16.

## 1. Install llama.cpp on Windows

From the [llama.cpp releases page](https://github.com/ggml-org/llama.cpp/releases),
download the **Windows CUDA 12** build. The models were tested with release
**b11796**, so prefer that one or newer. You need two zips:

- `llama-<release>-bin-win-cuda-12.x-x64.zip`: the programs.
- `cudart-llama-bin-win-cuda-12.x-x64.zip`: the CUDA runtime DLLs.

Unzip both into one folder, for example `C:\llama.cpp`.

- **Use CUDA 12, not CUDA 13.** CUDA 13 dropped support for Volta GPUs like
  the V100.
- **Driver:** you need an NVIDIA driver that supports CUDA 12. Check with
  `nvidia-smi`.

## 2. Download the models

Each model is split into pieces under 2 GB (GitHub's limit) with
llama.cpp's `gguf-split`. **llama-server loads them directly from the first
piece**, so there is nothing to join. With Git LFS, in PowerShell:

```powershell
git lfs install
$env:GIT_LFS_SKIP_SMUDGE = 1
git clone https://github.com/vincent0408/Docker-files.git
Remove-Item Env:GIT_LFS_SKIP_SMUDGE
cd Docker-files
git lfs pull --include "models/Qwen3-Embedding-4B-Q8_0/**"
git lfs pull --include "models/Qwen3-Reranker-4B-Q8_0/**"
```

Or download each `.gguf` piece in a browser from the model folder on GitHub
(open the file, then **Download raw file**), keeping all pieces of a model in
one folder. Don't use **Download ZIP**; it contains LFS pointers, not the
weights.

To check the files, compare `Get-FileHash *.gguf` with the hashes in each
folder's `SHA256SUMS`. A ~134-byte `.gguf` is still an LFS pointer; run the
`git lfs pull` again.

## 3. Start the servers

One server per model, in two PowerShell windows. Point `-m` at the
**first piece**:

```powershell
# Embedding server, port 8001
C:\llama.cpp\llama-server.exe -m models\Qwen3-Embedding-4B-Q8_0\Qwen3-Embedding-4B-Q8_0-00001-of-00003.gguf `
  --embedding --pooling last -ngl 99 -c 8192 -ub 8192 --host 127.0.0.1 --port 8001

# Reranker server, port 8002
C:\llama.cpp\llama-server.exe -m models\Qwen3-Reranker-4B-Q8_0\Qwen3-Reranker-4B-Q8_0-00001-of-00003.gguf `
  --reranking -ngl 99 -c 8192 -ub 8192 --host 127.0.0.1 --port 8002
```

For the 8B models the first pieces are
`Qwen3-Embedding-8B-Q8_0-00001-of-00005.gguf` and
`Qwen3-Reranker-8B-Q8_0-00001-of-00005.gguf`.

| Flag | What it does |
|---|---|
| `--embedding --pooling last` | Serve embeddings, using the last token's vector. That is how Qwen3-Embedding is meant to be used. |
| `--reranking` | Enables `/v1/rerank`. The reranker's GGUF already tells llama-server to score with its yes/no head. |
| `-ngl 99` | Puts the whole model on the GPU. |
| `-c 8192 -ub 8192` | Longest input, in tokens. For embeddings and reranking a whole input must fit in one batch, so keep `-ub` equal to `-c`. The models accept up to 32768 if memory allows. |
| `--host 0.0.0.0` | Use this instead of `127.0.0.1` to let other machines reach the server. Also allow the port in Windows Firewall. |

## 4. Use them

PowerShell (works in Windows PowerShell 5 and PowerShell 7):

```powershell
# Embeddings: one query (with the instruction, see below) and one document
$query = "Instruct: Given a web search query, retrieve relevant passages that answer the query`nQuery:What is the capital of China?"
$body  = @{ input = @($query, "The capital of China is Beijing.") } | ConvertTo-Json
$r = Invoke-RestMethod http://localhost:8001/v1/embeddings -Method Post -ContentType "application/json" -Body $body
$r.data | ForEach-Object { "vector $($_.index): $($_.embedding.Count) numbers" }

# Reranking
$body = @{ query = "What is the capital of China?"; documents = @("The capital of China is Beijing.", "Gravity attracts bodies.") } | ConvertTo-Json
(Invoke-RestMethod http://localhost:8002/v1/rerank -Method Post -ContentType "application/json" -Body $body).results
```

From Linux/macOS or Git Bash:

```bash
curl -s localhost:8002/v1/rerank -H 'Content-Type: application/json' \
  -d '{"query":"What is the capital of China?","documents":["The capital of China is Beijing.","Gravity attracts bodies."]}'
```

- **Embeddings:** `/v1/embeddings` is OpenAI-compatible. The `model` field is
  optional, since each server has one model. Vectors come back normalised
  (length 1).
- **Embedding queries:** Qwen's embedding models work best when **search
  queries** (not the documents being indexed) start with a task instruction,
  `Instruct: <task>\nQuery:<the query>`, as above. Qwen reports a 1–5% gain.
- **Reranking:** `/v1/rerank` takes `query` and `documents` and returns
  `results` with `index` and `relevance_score` (Jina/Cohere-style). The
  Beijing document should score close to 1 and the other close to 0.

## Checked

All with llama-server built from llama.cpp **b11796** on Linux (CPU), loading
each model from its first split piece:

- **Embedding** similarity for a query and two documents (matching /
  unrelated):

  | Model | Q8_0 | Full precision |
  |---|---|---|
  | 4B | 0.748 / 0.094 | 0.751 / 0.093 |
  | 8B | 0.751 / 0.080 | — |

- **Reranker** `relevance_score` for "What is the capital of China?":

  | Document | 4B | 8B |
  |---|---|---|
  | "The capital of China is Beijing." | 0.9985 (full precision: 0.9983) | 0.994 |
  | A paraphrase about Beijing | 0.955 | 0.977 |
  | Gravity sentence | 0.000 | 0.000 |
  | "Paris is the capital of France." | 0.000 | 0.000 |

- The embedding files' SHA256s match Qwen's published ones.
- **Not tested here:** the Windows build and running on a GPU (none
  available). These are the same llama.cpp release and model files, but CUDA
  offload on a V100 has not been tried.
