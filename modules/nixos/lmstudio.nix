# LM Studio (local LLMs) from Flathub, run inside a locked-down flatpak
# sandbox, with GPU inference. See docs/lmstudio.md.
{ ... }:
let
  lmstudio = "ai.lmstudio.lm-studio";
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = [
    {
      appId = lmstudio;
      origin = "flathub";
    }
  ];

  # Flathub's LM Studio already has no host or home access: models, chats and
  # settings live in ~/.var/app/ai.lmstudio.lm-studio/.lmstudio. On top of that:
  services.flatpak.overrides.${lmstudio} = {
    Context = {
      # Wayland only, like Element: no X11 socket and no shared IPC namespace.
      sockets = [
        "wayland"
        "pulseaudio"
        "!x11"
        "!fallback-x11"
      ];
      shared = [
        "network"
        "!ipc"
      ];
      # The GPU is all inference needs: /dev/dri for the Vulkan llama.cpp
      # runtime (AMD, Intel, NVIDIA), and on NVIDIA /dev/nvidia* for CUDA.
      # AMD's ROCm runtime also needs /dev/kfd, which flatpak can only grant
      # as "all" (see docs/lmstudio.md).
      devices = [ "dri" ];
    };
    Environment = {
      # Run Electron as a native Wayland client (there is no X11 to fall back to).
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
