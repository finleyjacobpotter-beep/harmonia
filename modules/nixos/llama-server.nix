# harmonia only: the local model, Ornith 1.5 9B (Q4_K_M, with its MTP head
# for multi-token prediction), served as "ai" by llama.cpp's llama-server in
# a podman container, on the AMD GPU through Vulkan. An OpenAI-compatible API
# on 127.0.0.1:1235; the bar starts and stops it. See docs/llama-server.md.
#
# Not vLLM: vLLM's MTP doesn't run on AMD GPUs yet, its experimental GGUF
# loader can't read Ornith's qwen35 architecture, and on AMD it needs ROCm
# (/dev/kfd) on a short list of cards. llama.cpp reads the GGUF, drafts with
# the MTP head (--spec-type draft-mtp) and needs only /dev/dri.
{ ... }:
let
  # Also in home/eww/activity.py (the bar) and modules/nixos/zelus.nix.
  port = 1235;
  # The quants with the MTP head built in; Q4_K_M is one file of them.
  model = "protoLabsAI/Ornith-1.5-9B-MTP-GGUF:Q4_K_M";
  # draft-mtp needs a recent llama.cpp (it's in b11515).
  image = "ghcr.io/ggml-org/llama.cpp:server-vulkan-b11515";
  # Downloaded on the first start, not at build time: ~6 GB of GGUF plus
  # the image projector (mmproj), kept here between restarts.
  cache = "/var/lib/llama-server";
  unit = "podman-llama-server.service";
  # The RX 9070's render node, named by udev below: the container sees only
  # this GPU, never the RX 5600 XT, whatever order the kernel finds them in.
  gpu = "/dev/dri/llm-gpu";
in
{
  systemd.tmpfiles.rules = [ "d ${cache} 0755 root root -" ];

  # PCI device 0x7550 is Navi 48: the RX 9070 (and 9070 XT). The 5600 XT is
  # Navi 10 (0x731f) and gets no link. With another card, change the ID
  # (`cat /sys/class/drm/renderD*/device/device`).
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="renderD*", ATTRS{vendor}=="0x1002", ATTRS{device}=="0x7550", SYMLINK+="dri/llm-gpu"
  '';

  virtualisation.oci-containers = {
    backend = "podman";
    containers.llama-server = {
      inherit image;
      # Started from the bar (or `sudo systemctl start podman-llama-server`),
      # so it only holds the GPU's memory while you want it.
      autoStart = false;
      ports = [ "127.0.0.1:${toString port}:8080" ];
      volumes = [ "${cache}:/models" ];
      environment.LLAMA_CACHE = "/models";
      extraOptions = [ "--device=${gpu}:/dev/dri/renderD128" ];
      cmd = [
        # Fetches the GGUF and its mmproj from Hugging Face into
        # LLAMA_CACHE, or uses the copies already there.
        "-hf"
        model
        # The name clients ask for.
        "--alias"
        "ai"
        "--host"
        "0.0.0.0"
        "--port"
        "8080"
        # Every layer on the GPU, and no automatic fitting: MTP slows down
        # as soon as a layer lands on the CPU.
        "--n-gpu-layers"
        "999"
        "--fit"
        "off"
        # One GPU: the container only has the 9070 (above).
        "--split-mode"
        "none"
        # Multi-token prediction: the model's own MTP head drafts up to 3
        # tokens ahead, and the model checks them in one pass.
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "3"
        # 4 requests at once, each with half of Ornith's native 262144
        # context: 131072 apiece, 524288 in all (opencode's agents,
        # home/gamedev.nix).
        "--ctx-size"
        "524288"
        "--parallel"
        "4"
        # Fixed limits: each slot has its own 131072 tokens of cache and can
        # never take another's (a unified cache would let one grow).
        "--no-kv-unified"
        # What makes that fit in the 9070's 16 GiB: only 8 of Ornith's 32
        # layers (plus the MTP head's one) keep a KV cache, 4 KV heads of
        # 256, and the cache is quantised to 4 bits (flash attention needs
        # to be on for that). ~5 GiB of cache + ~5.4 GiB of weights + ~1 GiB
        # mmproj + compute buffers is ~12.5 GiB; q8_0 for K instead would be
        # ~15 GiB, too close to 16 with the desktop on the same card.
        "--flash-attn"
        "on"
        "--cache-type-k"
        "q4_0"
        "--cache-type-v"
        "q4_0"
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

  # Wheel users may start, stop and restart the server without a password,
  # as the bar's button does; nothing else.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${unit}" &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
