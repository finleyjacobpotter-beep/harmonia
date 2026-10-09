# llama.cpp server

On harmonia (not cadmus), [`modules/nixos/llama-server.nix`](../modules/nixos/llama-server.nix)
runs [llama.cpp](https://github.com/ggml-org/llama.cpp)'s `llama-server` in a
podman container, serving Ornith 1.5 9B at Q4_K_M
([`bartowski/Ornith-1.5-9B-GGUF`](https://huggingface.co/bartowski/Ornith-1.5-9B-GGUF))
on the AMD GPU through Vulkan. It's an OpenAI-compatible API, like LM
Studio's, with the model's image projector loaded, so it reads images too.

| | |
| --- | --- |
| API | `http://127.0.0.1:1235/v1` (LM Studio keeps `1234`) |
| Model name | `ornith-1.5-9b` |
| Context | 262144 tokens, 4 requests at once (65536 each) |
| Image | `ghcr.io/ggml-org/llama.cpp:server-vulkan-b11515` |
| Model files | `/var/lib/llama-server` |

## Running it

It doesn't start at boot, so it isn't holding GPU memory while LM Studio has
the same model loaded:

```sh
sudo systemctl start podman-llama-server
journalctl -fu podman-llama-server     # the first start downloads ~6 GB
curl http://127.0.0.1:1235/v1/models
sudo systemctl stop podman-llama-server
```

The first start pulls the image and downloads the GGUF and its mmproj from
Hugging Face into `/var/lib/llama-server`; later starts reuse them. The
server's own web chat is at <http://127.0.0.1:1235>.

To start it at boot, set `autoStart = true;` in the module and rebuild.

## Why llama.cpp and not vLLM

Ornith is a `qwen35` (Qwen 3.5) model. vLLM's GGUF support is experimental
and can't load that architecture from a GGUF, and vLLM on AMD needs ROCm,
which needs `/dev/kfd` and supports only a short list of cards. llama.cpp
reads the GGUF natively, and its Vulkan build needs only `/dev/dri`, the
same as LM Studio's Vulkan runtime ([LM Studio](lmstudio.md)).

## Using it from opencode

opencode in [game dev](gamedev.md) still talks to LM Studio. To use this
server instead, point the `lmstudio` provider's `baseURL` in
`home/gamedev.nix` at `http://127.0.0.1:1235/v1`; the model name is the same.
