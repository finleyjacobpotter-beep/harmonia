# The local model (llama.cpp server)

On harmonia (not cadmus), [`modules/nixos/llama-server.nix`](../modules/nixos/llama-server.nix)
runs [llama.cpp](https://github.com/ggml-org/llama.cpp)'s `llama-server` in a
podman container and serves
[Ornith 1.5 9B](https://huggingface.co/ornith-ai/Ornith-1.5-9B) as `ai`: the
Q4_K_M quant from
[`protoLabsAI/Ornith-1.5-9B-MTP-GGUF`](https://huggingface.co/protoLabsAI/Ornith-1.5-9B-MTP-GGUF),
which keeps the model's multi-token prediction (MTP) head, on the AMD GPU
through Vulkan. It's an OpenAI-compatible API, and the image projector
(mmproj) is loaded too, so it reads images. It replaces LM Studio.

| | |
| --- | --- |
| API | `http://127.0.0.1:1235/v1` |
| Model name | `ai` |
| Context | 4 requests at once, 131072 tokens each (half of Ornith's 262144); 524288 in all |
| KV cache | 4-bit (`q4_0` for K and V), flash attention on |
| Speculative decoding | MTP (`--spec-type draft-mtp`), up to 3 drafted tokens |
| Image | `ghcr.io/ggml-org/llama.cpp:server-vulkan-b11515` |
| Model files | `/var/lib/llama-server` |

## Starting and stopping

The robot icon on the bar is the server: grey while stopped, yellow while it
starts or loads the model, pink while it serves. Click it for a panel with
**Start** or **Stop**. It doesn't start at boot, so it only holds GPU memory
while you want it. From a terminal:

```sh
systemctl start podman-llama-server    # wheel users need no sudo (polkit)
journalctl -fu podman-llama-server     # the first start downloads ~6 GB
curl http://127.0.0.1:1235/v1/models
systemctl stop podman-llama-server
```

The first start pulls the image and downloads the GGUF and its mmproj from
Hugging Face into `/var/lib/llama-server`; later starts reuse them. The
server's own web chat is at <http://127.0.0.1:1235>. To start it at boot,
set `autoStart = true;` in the module and rebuild.

## Tuning

- **GPU**: the container gets only the RX 9070's render node, so the model
  never touches the RX 5600 XT. A udev rule links the card with PCI ID
  `0x7550` (Navi 48, the 9070) to `/dev/dri/llm-gpu`; if that link is
  missing, the server won't start. The log names the GPU at start
  (`ggml_vulkan: 0 = …`). For another card, change the ID in the module
  (`cat /sys/class/drm/renderD*/device/device`).
- **Memory**: 4 × 131072 tokens fit in the 9070's 16 GiB because only 8 of
  Ornith's 32 layers (plus the MTP head's one) keep a KV cache (4 KV heads
  × 256), about 10 KiB per token at 4 bits: ~5 GiB of cache, plus ~5.4 GiB
  of weights, ~1 GiB of mmproj and the compute buffers, ~12.5 GiB in all.
  At f16 the cache alone would be ~18 GiB, at q8_0 ~9.6 GiB (~17 GiB in
  all). With room to spare (check `rocm-smi` or the bar's VRAM), try
  `--cache-type-k q8_0` (~15 GiB). Without images, `--no-mmproj` saves
  ~1 GiB. If you change `--ctx-size` or `--parallel`, change `slotContext`
  and `parallel` in `home/gamedev.nix` to match.
- **MTP**: `--spec-draft-n-max` is how many tokens the head drafts; the
  model card measured Q4_K_M's gain as small on prose and larger on code.
  Drop the two `--spec-*` arguments to turn it off.

## Why llama.cpp and not vLLM

vLLM's MTP doesn't run on AMD GPUs yet ("under development" in its Qwen 3.5
recipe), its GGUF support is experimental and can't load Ornith's `qwen35`
architecture, and on AMD it needs ROCm, which needs `/dev/kfd` and supports
only a short list of cards. llama.cpp reads the GGUF, drafts with the MTP
head baked into it and needs only `/dev/dri`.

## Who uses it

- opencode on harmonia ([game dev](gamedev.md)): every agent, and it's the
  only provider opencode offers.
