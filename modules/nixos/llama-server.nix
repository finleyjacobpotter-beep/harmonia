# harmonia only: Ornith 1.5 9B (Q4_K_M) served by llama.cpp's llama-server
# in a podman container, on the AMD GPU through Vulkan. An OpenAI-compatible
# API on 127.0.0.1:1235, next to LM Studio's 1234. See docs/llama-server.md.
#
# Not vLLM: Ornith is a qwen35 (Qwen 3.5) GGUF, which vLLM's experimental
# GGUF loader can't read, and vLLM on AMD needs ROCm (/dev/kfd) on a short
# list of cards. llama.cpp reads the GGUF natively and needs only /dev/dri.
{ ... }:
let
  port = 1235;
  # The model's API name, the same as LM Studio's identifier for it.
  alias = "ornith-1.5-9b";
  # The quants need llama.cpp b10472 or newer (bartowski's model card).
  image = "ghcr.io/ggml-org/llama.cpp:server-vulkan-b11515";
  # Downloaded on the first start, not at build time: ~6 GB of GGUF plus
  # the image projector (mmproj), kept here between restarts.
  cache = "/var/lib/llama-server";
in
{
  systemd.tmpfiles.rules = [ "d ${cache} 0755 root root -" ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers.llama-server = {
      inherit image;
      # Started by hand (`sudo systemctl start podman-llama-server`), so it
      # doesn't hold the GPU's memory while LM Studio has the same model.
      autoStart = false;
      ports = [ "127.0.0.1:${toString port}:8080" ];
      volumes = [ "${cache}:/models" ];
      environment.LLAMA_CACHE = "/models";
      extraOptions = [ "--device=/dev/dri" ];
      cmd = [
        # Fetches the Q4_K_M file and its mmproj from Hugging Face into
        # LLAMA_CACHE, or uses the copies already there.
        "-hf"
        "bartowski/Ornith-1.5-9B-GGUF:Q4_K_M"
        "--alias"
        alias
        "--host"
        "0.0.0.0"
        "--port"
        "8080"
        # Every layer on the GPU.
        "--n-gpu-layers"
        "999"
        # Ornith's native context, shared by 4 parallel requests (65536
        # each), as LM Studio serves it to opencode (home/gamedev.nix).
        "--ctx-size"
        "262144"
        "--parallel"
        "4"
        # The model's own chat template, for tool calls.
        "--jinja"
        # Ornith's recommended sampling for coding (its model card).
        "--temp"
        "0.6"
        "--top-p"
        "0.95"
        "--top-k"
        "20"
        "--min-p"
        "0"
      ];
    };
  };
}
