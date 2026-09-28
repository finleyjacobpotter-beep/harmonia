# Enforces the keyboard contract from keys.nix at evaluation time, so a new
# binding that would make two layers fight fails `nixos-rebuild` instead of
# silently shadowing a key.
{
  config,
  lib,
  keys,
  ...
}:
let
  sway = config.wayland.windowManager.sway.config;
  tmux = config.programs.tmux;
  alacritty = config.programs.alacritty.settings.keyboard.bindings or [ ];

  # Hardware keys nothing else can use are fine without Super.
  isHardwareKey = k: lib.hasPrefix "XF86" k || k == "Print" || k == "Shift+Print";
  straySway = lib.filter (k: !(lib.hasPrefix "${keys.sway}+" k || isHardwareKey k)) (
    lib.attrNames sway.keybindings
  );

  # Anything alacritty binds must be Ctrl+Shift, or explicitly pass through.
  strayAlacritty = lib.filter (
    b: b.mods or "" != keys.terminalMods && b.action or "" != "ReceiveChar"
  ) alacritty;

  # Alt belongs to i3 in the Kali VM: neovim, tmux and alacritty keep off it.
  nvimAlt = builtins.match ".*<[MA]-.*" (
    builtins.replaceStrings [ "\n" ] [ " " ] config.programs.neovim.initLua
  );
  tmuxAlt = builtins.match ".*bind(-key)? +(-[a-zA-Z]+ +)*M-.*" (
    builtins.replaceStrings [ "\n" ] [ " " ] tmux.extraConfig
  );
  alacrittyAlt = lib.filter (b: lib.hasInfix "Alt" (b.mods or "")) alacritty;

  # tmux: no root-table bindings (`bind -n` / `bind -T root`).
  rootTable = builtins.match ".*(bind(-key)? +(-[a-zA-Z]+ +)*(-n|-T +root)).*" (
    builtins.replaceStrings [ "\n" ] [ " " ] tmux.extraConfig
  );
in
{
  assertions = [
    {
      assertion = straySway == [ ];
      message = "keys.nix: sway bindings must use ${keys.sway}: ${toString straySway}";
    }
    {
      assertion = sway.modifier == keys.sway;
      message = "keys.nix: sway modifier must be ${keys.sway}";
    }
    {
      assertion = tmux.prefix == keys.tmuxPrefix;
      message = "keys.nix: tmux prefix must be ${keys.tmuxPrefix}";
    }
    {
      assertion = rootTable == null;
      message = "keys.nix: tmux must not bind keys in the root table (bind -n)";
    }
    {
      assertion = strayAlacritty == [ ];
      message = "keys.nix: alacritty bindings must use ${keys.terminalMods}: ${
        toString (map (b: b.key) strayAlacritty)
      }";
    }
    {
      assertion = nvimAlt == null && tmuxAlt == null && alacrittyAlt == [ ];
      message = "keys.nix: Alt is reserved for i3 in the Kali VM; neovim, tmux and alacritty must not bind it";
    }
  ];
}
