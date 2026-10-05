# LM Studio (local LLMs) from Flathub, run inside a locked-down flatpak
# sandbox, with GPU inference. See docs/lmstudio.md.
{
  # Flathub's LM Studio already has no host or home access: models, chats and
  # settings live in ~/.var/app/ai.lmstudio.lm-studio/.lmstudio. On top of
  # that it is Wayland only, like Element (modules/nixos/flatpak.nix):
  harmonia.apps."ai.lmstudio.lm-studio" = {
    name = "lm-studio";
    key = "l";
    wayland = true;
    sandbox = {
      Context = {
        sockets = [ "pulseaudio" ];
        # No shared IPC namespace (only X11 needs it).
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
  };
}
