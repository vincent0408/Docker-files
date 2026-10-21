# Embedding and reranker models

Qwen3 text embedding and reranking models from Hugging Face, for RAG
(for example Open WebUI's document search). All Apache-2.0.

| Folder | Use | Hugging Face revision | Size | Output |
|---|---|---|---|---|
| `Qwen3-Embedding-4B` | Embedding | [`5cf2132a`](https://huggingface.co/Qwen/Qwen3-Embedding-4B/tree/5cf2132abc99cad020ac570b19d031efec650f2b) | 8.1 GB | 2560-dim vectors |
| `Qwen3-Reranker-4B` | Reranking | [`22e68366`](https://huggingface.co/Qwen/Qwen3-Reranker-4B/tree/22e683669bc0f0bd69640a1354a6d0aebcfeede5) | 8.1 GB | relevance score |
| `Qwen3-Embedding-8B` | Embedding | [`1d8ad4ca`](https://huggingface.co/Qwen/Qwen3-Embedding-8B/tree/1d8ad4ca9b3dd8059ad90a75d4983776a23d44af) | 15.2 GB | 4096-dim vectors |
| `Qwen3-Reranker-8B` | Reranking | [`77d193c7`](https://huggingface.co/Qwen/Qwen3-Reranker-8B/tree/77d193c791ed757ca307ee72715aa132723da912) | 16.4 GB | relevance score |

All take up to 32K tokens of input and support 100+ languages. Each folder
also holds Qwen's own model card (`README.md`) with full usage details.

**4B or 8B?** The 8B pair is the most accurate open, permissively licensed
option in this family (Qwen3-Embedding-8B is among the top open models on the
MTEB leaderboard). It needs about twice the memory and is roughly twice as slow:
about 16 GB per model in bf16, so in practice a GPU. The 4B pair is the
practical choice for a CPU server or a smaller GPU, at about 8 GB per model.
Use an embedding model and a reranker of the same size, or mix (for example
an 8B embedding with a 4B reranker) to fit your memory.

## Download

The weights are stored with Git LFS. To fetch one model folder (here the
embedding model; change the name for another):

```bash
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "models/Qwen3-Embedding-4B/**"
```

Don't use GitHub's **Download ZIP**; it contains LFS pointers, not the weights.

## Join the split files

GitHub's LFS limit is 2 GB per file, so each weight file larger than that is
stored as `*.safetensors.part-00`, `part-01`, … Join them before use, inside
the model folder:

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

Then check the result in PowerShell with
`Get-FileHash *.safetensors` against the hashes in `SHA256SUMS`.

After joining, the folder is a normal Hugging Face model folder: load it by
path anywhere you would use `Qwen/Qwen3-Embedding-4B` or
`Qwen/Qwen3-Reranker-4B`.

## Use with Open WebUI

Open WebUI loads both kinds of model with Sentence Transformers and accepts a
local folder path. Mount the joined folders into the container and point
Open WebUI at them:

```bash
docker run -d --name open-webui -p 127.0.0.1:3000:8080 \
  -v open-webui:/app/backend/data \
  -v "$PWD/models:/models:ro" \
  -e RAG_EMBEDDING_MODEL=/models/Qwen3-Embedding-4B \
  -e RAG_RERANKING_MODEL=/models/Qwen3-Reranker-4B \
  -e ENABLE_RAG_HYBRID_SEARCH=true \
  -e SENTENCE_TRANSFORMERS_MODEL_KWARGS='{"torch_dtype":"bfloat16"}' \
  -e SENTENCE_TRANSFORMERS_CROSS_ENCODER_MODEL_KWARGS='{"torch_dtype":"bfloat16"}' \
  ghcr.io/open-webui/open-webui:0.12.3
```

- The two `..._MODEL_KWARGS` lines load the models in bf16, which needs about
  half the memory of the default (about 8 GB per 4B model instead of 16 GB).
- Reranking runs only with hybrid search on (`ENABLE_RAG_HYBRID_SEARCH`).
  Open WebUI turns reranker scores into 0–1 by default, so its relevance
  threshold setting works with this model.
- Open WebUI reads the `RAG_*` and `ENABLE_RAG_*` variables only on its first
  start and then keeps the values in its database. For an existing install,
  set both models in **Admin Panel → Settings → Documents** instead by typing
  the same `/models/...` paths; the `..._MODEL_KWARGS` variables apply on every
  start.
- Changing the embedding model means documents already uploaded must be
  re-indexed: their old vectors don't match the new model.

## Use from Python

```python
from sentence_transformers import SentenceTransformer, CrossEncoder

emb = SentenceTransformer("models/Qwen3-Embedding-4B", model_kwargs={"torch_dtype": "bfloat16"})
q = emb.encode(["What is the capital of China?"], prompt_name="query")   # queries use the "query" prompt
d = emb.encode(["The capital of China is Beijing."])
print(emb.similarity(q, d))

rr = CrossEncoder("models/Qwen3-Reranker-4B", model_kwargs={"torch_dtype": "bfloat16"})
print(rr.predict([("What is the capital of China?", "The capital of China is Beijing.")]))
```

Requires `sentence-transformers>=5` and `transformers>=4.51`.

## Checked

For each model:

- Every file matches the SHA256 Hugging Face publishes for it at the pinned
  revision.
- Rejoining the split parts reproduces those files exactly.
- 4B models only: the joined folder loads with Sentence Transformers (also
  with Open WebUI's bf16 setting, using about 8.4 GB of RAM) and gives the
  scores shown in Qwen's model cards. On the example above, the embedding
  similarity is 0.751 for the matching document and 0.093 for an unrelated
  one, and the reranker scores 0.998 for the match and ~0 otherwise. The 8B
  models were not run, for lack of memory on the test machine; their files
  are byte-identical to Hugging Face's.
