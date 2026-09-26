{
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;
  mod = "Mod4";
in
{
  wayland.windowManager.sway = {
    enable = true;
    # sway itself is installed by the NixOS module (modules/nixos/desktop.nix)
    package = null;
    checkConfig = false;
    systemd.enable = true;
    wrapperFeatures.gtk = true;

    config = {
      modifier = mod;
      terminal = "alacritty";
      menu = "fuzzel";

      fonts = {
        names = [ p.font.name ];
        size = p.font.size + 0.0;
      };

      # The bar is eww (home/eww.nix).
      bars = [ ];

      gaps = {
        inner = 6;
        outer = 2;
        smartBorders = "on";
      };
      window = {
        border = 2;
        titlebar = false;
      };
      floating = {
        border = 2;
        titlebar = false;
      };

      colors = {
        background = p.bg;
        focused = {
          border = p.pink;
          background = p.pink;
          text = p.bgDark;
          indicator = p.cyan;
          childBorder = p.pink;
        };
        focusedInactive = {
          border = p.surfaceHi;
          background = p.surface;
          text = p.fg;
          indicator = p.surfaceHi;
          childBorder = p.surfaceHi;
        };
        unfocused = {
          border = p.surface;
          background = p.bgAlt;
          text = p.fgDim;
          indicator = p.surface;
          childBorder = p.surface;
        };
        urgent = {
          border = p.redBright;
          background = p.redBright;
          text = p.white;
          indicator = p.redBright;
          childBorder = p.redBright;
        };
        placeholder = {
          border = p.bgDark;
          background = p.bg;
          text = p.fg;
          indicator = p.bgDark;
          childBorder = p.bgDark;
        };
      };

      output."*".bg = "${p.bg} solid_color";

      input."type:touchpad" = {
        tap = "enabled";
        natural_scroll = "enabled";
      };

      startup = [
        # `eww open` starts the daemon if needed
        { command = "eww open bar"; }
      ];

      keybindings = lib.mkOptionDefault {
        "${mod}+b" = "exec flatpak run app.zen_browser.zen";
        "${mod}+e" = "exec alacritty -e ranger";
        "${mod}+Shift+x" = "exec swaylock -f";
        "${mod}+Shift+b" = "exec eww open --toggle bar";

        "Print" = ''exec grim -g "$(slurp)" - | wl-copy'';
        "Shift+Print" = "exec grim - | wl-copy";

        "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
        "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
      };
    };

    extraConfig = ''
      for_window [app_id="pavucontrol"] floating enable
      for_window [app_id="blueman-manager"] floating enable
      for_window [app_id="app.zen_browser.zen" title="^Picture-in-Picture$"] floating enable, sticky enable
    '';
  };

  # Launcher
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "${p.font.name}:size=${toString p.font.size}";
        terminal = "alacritty -e";
        prompt = ''"❯ "'';
        icons-enabled = false;
        width = 40;
        lines = 12;
        horizontal-pad = 16;
        vertical-pad = 12;
      };
      border = {
        width = 2;
        radius = 0;
      };
      colors = {
        background = "${p.strip p.bg}f2";
        text = "${p.strip p.fg}ff";
        prompt = "${p.strip p.pink}ff";
        input = "${p.strip p.fg}ff";
        match = "${p.strip p.cyan}ff";
        selection = "${p.strip p.surface}ff";
        selection-text = "${p.strip p.fg}ff";
        selection-match = "${p.strip p.pink}ff";
        border = "${p.strip p.pink}ff";
      };
    };
  };

  # Notifications
  services.mako = {
    enable = true;
    settings = {
      font = "${p.font.name} ${toString p.font.size}";
      background-color = p.bgAlt;
      text-color = p.fg;
      border-color = p.pink;
      progress-color = "over ${p.surfaceHi}";
      border-size = 2;
      border-radius = 0;
      padding = "10";
      default-timeout = 6000;
      "urgency=high" = {
        border-color = p.redBright;
      };
      "urgency=low" = {
        border-color = p.surfaceHi;
      };
    };
  };

  programs.swaylock = {
    enable = true;
    settings = {
      font = p.font.name;
      color = p.strip p.bg;
      indicator-radius = 90;
      indicator-thickness = 8;
      show-failed-attempts = true;
      ring-color = p.strip p.surface;
      inside-color = p.strip p.bgDark;
      line-color = p.strip p.bg;
      separator-color = "00000000";
      text-color = p.strip p.fg;
      key-hl-color = p.strip p.pink;
      bs-hl-color = p.strip p.orange;
      ring-ver-color = p.strip p.cyan;
      inside-ver-color = p.strip p.bgDark;
      text-ver-color = p.strip p.cyan;
      ring-wrong-color = p.strip p.redBright;
      inside-wrong-color = p.strip p.bgDark;
      text-wrong-color = p.strip p.redBright;
      ring-clear-color = p.strip p.yellow;
      inside-clear-color = p.strip p.bgDark;
      text-clear-color = p.strip p.yellow;
    };
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        timeout = 900;
        command = ''${pkgs.sway}/bin/swaymsg "output * power off"'';
        resumeCommand = ''${pkgs.sway}/bin/swaymsg "output * power on"'';
      }
    ];
    events.before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
  };
}
