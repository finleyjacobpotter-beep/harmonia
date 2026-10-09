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
in
{
  systemd.tmpfiles.rules = [ "d ${cache} 0755 root root -" ];

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
      extraOptions = [ "--device=/dev/dri" ];
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
        # One GPU (Vulkan device 0, or --main-gpu N): splitting onto a
        # second, slower card only slows it down.
        "--split-mode"
        "none"
        # Multi-token prediction: the model's own MTP head drafts up to 3
        # tokens ahead, and the model checks them in one pass.
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "3"
        # Ornith's native context, shared by 4 parallel requests (65536
        # each), for opencode's agents (home/gamedev.nix).
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
