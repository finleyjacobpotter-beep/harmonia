# Elkowar's Wacky Widgets — top bar for sway.
{
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;

  # Emits the workspace list as JSON on every sway workspace event.
  workspaces = pkgs.writeShellApplication {
    name = "eww-sway-workspaces";
    runtimeInputs = with pkgs; [
      sway
      jq
    ];
    text = ''
      emit() {
        swaymsg -t get_workspaces | jq -c 'sort_by(.num) | map({name, focused, urgent})'
      }
      emit
      swaymsg -t subscribe -m '["workspace", "output"]' | while read -r _; do emit; done
    '';
  };

  # Emits the focused window's title whenever focus or titles change.
  title = pkgs.writeShellApplication {
    name = "eww-sway-title";
    runtimeInputs = with pkgs; [
      sway
      jq
    ];
    text = ''
      emit() {
        swaymsg -t get_tree | jq -r '[.. | objects | select(.focused? == true) | .name // ""][0] // ""' | cut -c1-80
      }
      emit
      swaymsg -t subscribe -m '["window", "workspace"]' | while read -r _; do emit; done
    '';
  };

  # Key hints for sway's modes (home/sway.nix), shown while a mode is active.
  modeHints = {
    resize = "h/j/k/l resize · Shift = ×5 · Esc done";
    open = "b zen · f ranger · e nvim · t tmux · s btop · a audio · u bluetooth · n network · v virt-manager";
    media = "j/k volume · m mute · M mic · h/l prev/next · p play · J/K brightness";
    system = "l lock · e exit · s suspend · r reboot · P poweroff";
  };

  # Emits {"name": …, "hint": …} whenever the sway binding mode changes.
  mode = pkgs.writeShellApplication {
    name = "eww-sway-mode";
    runtimeInputs = with pkgs; [
      sway
      jq
    ];
    text = ''
      hints=${lib.escapeShellArg (builtins.toJSON modeHints)}
      echo '{"name":"default","hint":""}'
      swaymsg -t subscribe -m '["mode"]' \
        | jq --unbuffered -c --argjson h "$hints" '{name: .change, hint: ($h[.change] // "")}'
    '';
  };

  volume = pkgs.writeShellApplication {
    name = "eww-volume";
    runtimeInputs = with pkgs; [
      wireplumber
      gawk
    ];
    text = ''
      out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0")
      case "$out" in
        *MUTED*) echo "muted" ;;
        *) echo "$out" | awk '{ printf "%d%%\n", $2 * 100 }' ;;
      esac
    '';
  };

  # Caffeine: stopping swayidle (home/sway.nix) turns off the lock and blank
  # timers until it is started again. The bar button toggles it.
  caffeine = pkgs.writeShellApplication {
    name = "eww-caffeine";
    runtimeInputs = with pkgs; [
      systemd
      eww
    ];
    text = ''
      state() {
        if systemctl --user is-active --quiet swayidle.service; then echo off; else echo on; fi
      }
      if [ "''${1:-}" = toggle ]; then
        if [ "$(state)" = off ]; then
          systemctl --user stop swayidle.service
        else
          systemctl --user start swayidle.service
        fi
        eww update caffeine="$(state)"
      else
        state
      fi
    '';
  };

  battery = pkgs.writeShellApplication {
    name = "eww-battery";
    text = ''
      for b in /sys/class/power_supply/BAT*; do
        [ -r "$b/capacity" ] && { cat "$b/capacity"; exit 0; }
      done
      echo ""
    '';
  };
in
{
  home.packages = [ pkgs.eww ];

  xdg.configFile."eww/eww.yuck".text = ''
    (deflisten workspaces :initial "[]" "${workspaces}/bin/eww-sway-workspaces")
    (deflisten title :initial "" "${title}/bin/eww-sway-title")
    (deflisten mode :initial "{\"name\":\"default\",\"hint\":\"\"}" "${mode}/bin/eww-sway-mode")
    (defpoll volume :interval "2s" "${volume}/bin/eww-volume")
    (defpoll caffeine :interval "10s" "${caffeine}/bin/eww-caffeine")
    (defpoll battery :interval "30s" "${battery}/bin/eww-battery")
    (defpoll time :interval "10s" "date '+%a %d %b  %H:%M'")

    (defwidget workspaces []
      (box :class "workspaces" :orientation "h" :space-evenly false :spacing 2
        (for ws in workspaces
          (button
            :class "ws ''${ws.focused ? "focused" : ""} ''${ws.urgent ? "urgent" : ""}"
            :onclick "${pkgs.sway}/bin/swaymsg workspace ''${ws.name}"
            "''${ws.name}"))))

    (defwidget left []
      (box :orientation "h" :space-evenly false :halign "start" :spacing 12
        (label :class "logo" :text "")
        (workspaces)
        (box :class "mode" :visible {mode.name != "default"} :orientation "h" :space-evenly false :spacing 8
          (label :class "mode-name" :text "''${mode.name}")
          (label :class "mode-hint" :text "''${mode.hint}"))))

    (defwidget center []
      (label :class "title" :limit-width 80 :text title))

    (defwidget module [icon text ?class ?visible]
      (box :class "module ''${class}" :visible {visible ?: true} :orientation "h" :space-evenly false :spacing 6
        (label :class "icon" :text icon)
        (label :text text)))

    (defwidget right []
      (box :orientation "h" :space-evenly false :halign "end" :spacing 4
        (module :class "cpu" :icon "" :text "''${round(EWW_CPU.avg, 0)}%")
        (module :class "mem" :icon "" :text "''${round(EWW_RAM.used_mem_perc, 0)}%")
        (button
          :class "module caffeine ''${caffeine}"
          :tooltip "Caffeine ''${caffeine}: click to ''${caffeine == "on" ? "allow" : "stop"} locking and screen blanking"
          :onclick "${caffeine}/bin/eww-caffeine toggle"
          (label :class "icon" :text {caffeine == "on" ? "󰅶" : "󰛊"}))
        (module :class "vol" :icon "󰕾" :text volume)
        (module :class "bat" :icon "󰁹" :text "''${battery}%" :visible {battery != ""})
        (module :class "clock" :icon "󰥔" :text time)))

    (defwidget bar []
      (centerbox :class "bar" :orientation "h"
        (left)
        (center)
        (right)))

    (defwindow bar
      :monitor 0
      :exclusive true
      :stacking "fg"
      :namespace "eww-bar"
      :geometry (geometry :x "0%" :y "0px" :width "100%" :height "28px" :anchor "top center")
      (bar))
  '';

  xdg.configFile."eww/eww.scss".text = ''
    $bg: ${p.bgDark};
    $bg-alt: ${p.bgAlt};
    $surface: ${p.surface};
    $fg: ${p.fg};
    $muted: ${p.muted};
    $pink: ${p.pink};
    $cyan: ${p.cyan};
    $yellow: ${p.yellow};
    $purple: ${p.purple};
    $blue: ${p.blue};
    $green: ${p.green};
    $orange: ${p.orange};
    $red: ${p.redBright};

    * {
      all: unset;
      font-family: "${p.font.name}";
      font-size: ${toString p.font.size}pt;
    }

    .bar {
      background-color: $bg;
      color: $fg;
      padding: 0 10px;
      border-bottom: 2px solid $surface;
    }

    .logo {
      color: $cyan;
      font-size: ${toString (p.font.size + 3)}pt;
      padding: 0 6px;
    }

    .ws {
      padding: 0 8px;
      color: $muted;
      &:hover { color: $fg; background-color: $surface; }
      &.focused { color: $bg; background-color: $pink; }
      &.urgent { color: $bg; background-color: $red; }
    }

    .title { color: $fg; }

    .mode {
      padding: 0 8px;
      .mode-name { color: $bg; background-color: $cyan; padding: 0 8px; }
      .mode-hint { color: $yellow; }
    }

    .module {
      padding: 0 8px;
      .icon { font-size: ${toString (p.font.size + 1)}pt; }
      &.cpu .icon { color: $green; }
      &.mem .icon { color: $purple; }
      &.vol .icon { color: $cyan; }
      &.bat .icon { color: $yellow; }
      &.clock .icon { color: $pink; }
      &.caffeine { color: $muted; &:hover { background-color: $surface; } }
      &.caffeine.on { color: $orange; }
    }
  '';
}
