# LM Studio

[LM Studio](https://lmstudio.ai/) runs local LLMs. It comes from Flathub
(`ai.lmstudio.lm-studio`) and runs in a locked-down Flatpak sandbox. Start it
with `Super+o l` or from fuzzel.

## The jail

Flathub's LM Studio already has no access to the host or your home directory.
Models, chats and settings all live in
`~/.var/app/ai.lmstudio.lm-studio/.lmstudio`. On top of that,
[`modules/nixos/lmstudio.nix`](../modules/nixos/lmstudio.nix) revokes the X11
socket and the shared IPC namespace, so it runs as a native Wayland app and
can't see other windows. Its only device is the GPU.

It keeps network access, to download models from Hugging Face. The local API
server (*Developer* tab) listens on `localhost:1234` by default; don't switch
it to "serve on local network" unless you mean to.

Check the effective permissions with
`flatpak info --show-permissions ai.lmstudio.lm-studio`.

## GPU inference

Pick the runtime in LM Studio's runtime settings, then set GPU offload to max
when loading a model.

| GPU | Runtime | Works in the jail |
| --- | --- | --- |
| AMD, Intel, NVIDIA | **Vulkan** llama.cpp | yes, through `/dev/dri` |
| NVIDIA | **CUDA** llama.cpp | yes: Flatpak installs the `org.freedesktop.Platform.GL.nvidia-*` extension that matches your host driver |
| AMD | **ROCm** llama.cpp | no, see below |

Vulkan is the default choice. ROCm needs `/dev/kfd`, which Flatpak can only grant along with every other
device (webcams, USB, input devices). If you want it anyway, change
`devices = [ "dri" ];` to `devices = [ "all" ];` in `lmstudio.nix` and
rebuild.

The host side needs nothing extra: `hardware.graphics.enable` is already on,
and on NVIDIA you also need the usual `services.xserver.videoDrivers = [ "nvidia" ];`
(the driver is unfree, so add its packages to the allow-list in
`hosts/harmonia/default.nix`).

## Models on another drive

Models are large. To keep them elsewhere, grant that directory back and point
LM Studio's models folder (in *My Models*) at it:

```nix
services.flatpak.overrides."ai.lmstudio.lm-studio".Context.filesystems = [ "/mnt/models" ];
```

## On the bar

While LM Studio is running, a robot icon sits on the eww bar. It's grey
until a model is loaded, then pink with the model's name, and hovering it
lists every loaded model. This reads LM Studio's API on `localhost:1234`, so
the name only shows while the local server (*Developer* tab) is running.
