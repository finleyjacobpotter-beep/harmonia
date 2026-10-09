# Sway's open mode (Super+o, then a key): what each key opens, in key order
# (as the bar's hint lists them). home/sway.nix binds them and home/eww.nix shows
# the hint. The Flathub apps, native programs and the microVMs come from the
# host's config (harmonia.apps and harmonia.launchers,
# modules/nixos/flatpak.nix; harmonia.microvms,
# modules/nixos/microvms.nix), so a host only gets keys for what it has.
#
#   [ { key = "b"; name = "firefox"; exec = "flatpak run org.mozilla.firefox"; } ... ]
#
# `hint` is the key as the bar shows it: "Shift+g" is "G".
{ lib, osConfig }:
let
  term = app: "alacritty --class ${app} -e ${app}";
  hint = key: if lib.hasPrefix "Shift+" key then lib.toUpper (lib.removePrefix "Shift+" key) else key;
  appKeys = lib.mapAttrsToList (appId: app: {
    inherit (app) key name;
    exec = "flatpak run ${appId}";
  }) (lib.filterAttrs (_: app: app.key != null) (osConfig.harmonia.apps or { }));
  launcherKeys = lib.mapAttrsToList (name: l: {
    inherit name;
    inherit (l) key exec;
  }) (osConfig.harmonia.launchers or { });
  vmKeys = lib.mapAttrsToList (name: vm: {
    inherit (vm) key;
    inherit name;
    exec = "alacritty --class ${name} -e ssh ${name}";
  }) (lib.filterAttrs (_: vm: vm.key != null) (osConfig.harmonia.microvms or { }));
  # Alphabetically by key, b before B.
  order = key: lib.toLower (hint key) + (if lib.hasPrefix "Shift+" key then "1" else "0");
  sorted = lib.sort (a: b: order a.key < order b.key);
in
map (k: k // { hint = hint k.key; }) (
  sorted (
    appKeys
    ++ launcherKeys
    ++ [
      {
        key = "f";
        name = "ranger";
        exec = term "ranger";
      }
      {
        key = "e";
        name = "nvim";
        exec = term "nvim";
      }
      {
        key = "t";
        name = "tmux";
        exec = "alacritty -e tmux new-session -A -s main";
      }
      {
        key = "s";
        name = "btop";
        exec = term "btop";
      }
      {
        key = "a";
        name = "audio";
        exec = term "pulsemixer";
      }
      {
        key = "u";
        name = "bluetooth";
        exec = term "bluetuith";
      }
      {
        key = "n";
        name = "network";
        exec = term "nmtui";
      }
    ]
    ++ vmKeys
  )
)
