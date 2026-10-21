---
base_model: Qwen/Qwen3-Reranker-4B
base_model_relation: quantized
library_name: transformers
tags:
- fp8
- compressed-tensors
- llm-compressor
- vllm
- reranker
---

# Qwen3-Reranker-4B-FP8-Dynamic

[Qwen/Qwen3-Reranker-4B](https://huggingface.co/Qwen/Qwen3-Reranker-4B) quantised to FP8 with [llm-compressor](https://github.com/vllm-project/llm-compressor),
for serving with vLLM.

## What was done

| | |
|---|---|
| Scheme | `FP8_DYNAMIC` — weights static per-channel FP8, activations dynamic per-token FP8 |
| Calibration | none needed; dynamic activation scales are computed at inference time |
| Left in bf16 | `lm_head`, and the token embeddings |
| Weights before | 7.49 GiB |
| Weights after | 4.83 GiB (35% smaller) |

The score is read from the `yes`/`no` logits of the model head, which is left in bf16. Quantising it would put error directly into the number documents are ranked by.

## Quality gate

[`WikipediaRerankingMultilingual`](https://huggingface.co/datasets/mteb/WikipediaRerankingMultilingual) from MTEB — reranking Wikipedia passages in 16 languages, scored by `map_at_1000`.

| language | bf16 | FP8 | Δ |
|---|---|---|---|
| de | 0.9600 | 0.9594 | -0.0006 |
| en | 0.9715 | 0.9726 | +0.0011 |
| it | 0.9710 | 0.9702 | -0.0008 |
| **mean** | **0.9675** | **0.9674** | **-0.0001** |

Languages evaluated: de, en, it. Tolerance: 0.0100 map_at_1000 per language.

**PASSED — no language lost more than 0.0100 map_at_1000.**

## Why

Serving [Qwen/Qwen3-Reranker-4B](https://huggingface.co/Qwen/Qwen3-Reranker-4B) in bf16 leaves little room for KV cache on a small GPU: the weights take
what the cache needs, and the context length has to be cut until it fits. Halving the weights
gives that memory back — the same card serves a longer context without any other change.

## Serving

```bash
vllm serve DCC-BS/Qwen3-Reranker-4B-FP8-Dynamic \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85
```

The checkpoint is in `compressed-tensors` format, so vLLM detects the quantisation from
`config.json`; no extra flag is required.

FP8 arithmetic is native on Ada and Hopper (compute capability 8.9+). On Ampere it runs through
Marlin: the memory saving still applies, the speed is roughly unchanged.
