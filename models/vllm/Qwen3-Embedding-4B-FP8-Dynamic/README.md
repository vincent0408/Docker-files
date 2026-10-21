---
base_model: Qwen/Qwen3-Embedding-4B
base_model_relation: quantized
library_name: transformers
tags:
- fp8
- compressed-tensors
- llm-compressor
- vllm
- embedding
---

# Qwen3-Embedding-4B-FP8-Dynamic

[Qwen/Qwen3-Embedding-4B](https://huggingface.co/Qwen/Qwen3-Embedding-4B) quantised to FP8 with [llm-compressor](https://github.com/vllm-project/llm-compressor),
for serving with vLLM.

## What was done

| | |
|---|---|
| Scheme | `FP8_DYNAMIC` — weights static per-channel FP8, activations dynamic per-token FP8 |
| Calibration | none needed; dynamic activation scales are computed at inference time |
| Left in bf16 | `lm_head`, and the token embeddings |
| Weights before | 7.49 GiB |
| Weights after | 4.11 GiB (45% smaller) |

Embeddings are the pooled last hidden state; the head is unused and left unquantised. Cosine similarity is scale-sensitive, so compare rankings rather than raw distances when validating this checkpoint.

## Quality gate

[`WikipediaRetrievalMultilingual`](https://huggingface.co/datasets/mteb/WikipediaRetrievalMultilingual) from MTEB — retrieval over Wikipedia in 16 languages, scored by `ndcg_at_10`.

| language | bf16 | FP8 | Δ |
|---|---|---|---|
| de | 0.9066 | 0.9065 | -0.0001 |
| en | 0.9344 | 0.9353 | +0.0009 |
| it | 0.8993 | 0.8994 | +0.0002 |
| **mean** | **0.9134** | **0.9138** | **+0.0003** |


## Why

Serving [Qwen/Qwen3-Embedding-4B](https://huggingface.co/Qwen/Qwen3-Embedding-4B) in bf16 leaves little room for KV cache on a small GPU: the weights take
what the cache needs, and the context length has to be cut until it fits. Halving the weights
gives that memory back — the same card serves a longer context without any other change.

## Serving

```bash
vllm serve DCC-BS/Qwen3-Embedding-4B-FP8-Dynamic \
  --task embed \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85
```

The checkpoint is in `compressed-tensors` format, so vLLM detects the quantisation from
`config.json`; no extra flag is required.
