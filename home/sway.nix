{
  pkgs,
  lib,
  palette,
  keys,
  ...
}:
let
  p = palette;
  mod = keys.sway;
  volUp = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
  volDown = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
  volMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
  micMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";

  # Already recoloured to Miami Wind (lutgen) with its outer margin filled
  # with p.bg, so it blends into the background. `fit` scales it to the
  # screen height and centres it (plain `center` would crop a 1468px-tall
  # image on a 1080p screen).
  wallpaper = ../assets/wallpaper.png;
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

      output."*".bg = "${wallpaper} fit ${p.bg}";

      # Hide the pointer as soon as a key is pressed; it comes back when the
      # mouse moves.
      seat."*".hide_cursor = "when-typing enable";

      input."type:touchpad" = {
        tap = "enabled";
        natural_scroll = "enabled";
      };

      startup = [
        # Reapplies the resolutions picked on the bar and opens the bar on the
        # primary display (home/eww/display.sh); `eww open` starts the daemon.
        { command = "eww-display start"; }
      ];

      # Complete keymap (sway's defaults are *replaced*, not merged): every
      # binding is Super+…, apart from dedicated hardware keys. See keys.nix.
      keybindings =
        let
          ws = n: key: {
            "${mod}+${key}" = "workspace number ${toString n}";
            "${mod}+Shift+${key}" = "move container to workspace number ${toString n}";
          };
          workspaces = lib.foldl' (acc: n: acc // ws n (toString (lib.mod n 10))) { } (lib.range 1 10);
        in
        workspaces
        // {
          # focus / move — vim directions
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";
          "${mod}+a" = "focus parent";
          "${mod}+Shift+a" = "focus child";

          # outputs
          "${mod}+Ctrl+h" = "focus output left";
          "${mod}+Ctrl+l" = "focus output right";
          "${mod}+Ctrl+Shift+h" = "move workspace to output left";
          "${mod}+Ctrl+Shift+l" = "move workspace to output right";

          # workspaces
          "${mod}+Tab" = "workspace back_and_forth";
          "${mod}+bracketleft" = "workspace prev_on_output";
          "${mod}+bracketright" = "workspace next_on_output";

          # layout — split names follow vim (:split = below, :vsplit = beside)
          "${mod}+s" = "splitv";
          "${mod}+v" = "splith";
          "${mod}+t" = "layout tabbed";
          "${mod}+Shift+t" = "layout stacking";
          "${mod}+e" = "layout toggle split";
          "${mod}+f" = "fullscreen toggle";
          "${mod}+Shift+space" = "floating toggle";
          "${mod}+space" = "focus mode_toggle";
          "${mod}+minus" = "scratchpad show";
          "${mod}+Shift+minus" = "move scratchpad";

          # windows / session
          "${mod}+q" = "kill";
          "${mod}+Return" = "exec alacritty";
          "${mod}+d" = "exec fuzzel";
          "${mod}+Shift+c" = "reload";
          "${mod}+Shift+x" = "exec swaylock -f";
          "${mod}+Shift+b" = "exec eww-display toggle-bar";

          # notifications (mako)
          "${mod}+n" = "exec makoctl dismiss";
          "${mod}+Shift+n" = "exec makoctl dismiss --all";
          "${mod}+Ctrl+n" = "exec makoctl restore";
          "${mod}+i" = "exec makoctl invoke";

          # screenshots → clipboard
          "${mod}+Shift+s" = ''exec grim -g "$(slurp)" - | wl-copy'';
          "${mod}+Ctrl+s" = "exec grim - | wl-copy";

          # modes (vim-style "leader" layers; Escape/Return leave)
          "${mod}+r" = ''mode "resize"'';
          "${mod}+o" = ''mode "open"'';
          "${mod}+m" = ''mode "media"'';
          "${mod}+Shift+e" = ''mode "system"'';

          # dedicated hardware keys
          "Print" = ''exec grim -g "$(slurp)" - | wl-copy'';
          "Shift+Print" = "exec grim - | wl-copy";
          "XF86AudioRaiseVolume" = "exec ${volUp}";
          "XF86AudioLowerVolume" = "exec ${volDown}";
          "XF86AudioMute" = "exec ${volMute}";
          "XF86AudioMicMute" = "exec ${micMute}";
          "XF86AudioPlay" = "exec playerctl play-pause";
          "XF86AudioNext" = "exec playerctl next";
          "XF86AudioPrev" = "exec playerctl previous";
          "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        };

      # Inside a mode sway grabs the whole keyboard, so bare keys are safe here.
      # The eww bar shows the active mode and its keys.
      modes =
        let
          leave = {
            Escape = "mode default";
            Return = "mode default";
          };
          # run a command, then drop back to the default mode
          run = cmd: "exec ${cmd}, mode default";
          term = app: run "alacritty --class ${app} -e ${app}";
        in
        {
          resize = leave // {
            h = "resize shrink width 20 px";
            j = "resize grow height 20 px";
            k = "resize shrink height 20 px";
            l = "resize grow width 20 px";
            "Shift+h" = "resize shrink width 100 px";
            "Shift+j" = "resize grow height 100 px";
            "Shift+k" = "resize shrink height 100 px";
            "Shift+l" = "resize grow width 100 px";
          };
          open = leave // {
            b = run "flatpak run app.zen_browser.zen";
            f = term "ranger";
            e = term "nvim";
            t = run "alacritty -e tmux new-session -A -s main";
            s = term "btop";
            a = term "pulsemixer";
            u = term "bluetuith";
            n = term "nmtui";
            v = run "virt-manager";
            g = run "flatpak run net.lutris.Lutris";
            "Shift+g" = run "flatpak run com.valvesoftware.Steam";
            c = run "flatpak run im.riot.Riot";
            l = run "flatpak run ai.lmstudio.lm-studio";
          };
          media = leave // {
            k = "exec ${volUp}";
            j = "exec ${volDown}";
            m = "exec ${volMute}";
            "Shift+m" = "exec ${micMute}";
            h = "exec playerctl previous";
            l = "exec playerctl next";
            p = "exec playerctl play-pause";
            "Shift+k" = "exec brightnessctl set 5%+";
            "Shift+j" = "exec brightnessctl set 5%-";
          };
          system = leave // {
            l = run "swaylock -f";
            e = "exit";
            s = run "systemctl suspend";
            r = run "systemctl reboot";
            "Shift+p" = run "systemctl poweroff";
          };
        };
    };

    extraConfig = ''
      for_window [app_id="pavucontrol"] floating enable
      for_window [app_id="blueman-manager"] floating enable
      for_window [app_id="^(btop|pulsemixer|bluetuith|nmtui)$"] floating enable, resize set 60 ppt 60 ppt, move position center
      for_window [app_id="app.zen_browser.zen" title="^Picture-in-Picture$"] floating enable, sticky enable
      for_window [class=".*"] inhibit_idle fullscreen
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
        icons-enabled = true;
        icon-theme = "Tulasi";
        width = 40;
        lines = 12;
        horizontal-pad = 16;
        vertical-pad = 12;
      };
      border = {
        width = 2;
        radius = 0;
      };
      # Ctrl+j/k move through results (Ctrl+n/p and arrows still work).
      key-bindings = {
        next = "Down Control+n Control+j";
        prev = "Up Control+p Control+k";
        delete-line-forward = "none";
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
