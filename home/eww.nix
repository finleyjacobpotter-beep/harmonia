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
    open = "b zen · f ranger · e nvim · t tmux · s btop · a audio · u bluetooth · n network · v virt-manager · g lutris · G steam · c element · l lm-studio";
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

  # WireGuard tunnels (NetworkManager connections of type wireguard, see
  # modules/nixos/wireguard.nix) for the bar button and its panel.
  wireguard = pkgs.writeShellApplication {
    name = "eww-wg";
    runtimeInputs = with pkgs; [
      networkmanager
      iproute2
      jq
      gawk
      coreutils
      eww
    ];
    text = ''
      # Usage: eww-wg            JSON for the bar: {"active": N, "tunnels": [...]}
      #        eww-wg toggle NAME  bring a NetworkManager WireGuard connection up/down
      wg_show() { # wg_show endpoints|latest-handshakes: "iface<TAB>peer<TAB>value" lines, or nothing
        /run/wrappers/bin/sudo -n ${pkgs.wireguard-tools}/bin/wg show all "$1" 2>/dev/null || true
      }

      list() {
        endpoints=$(wg_show endpoints)
        handshakes=$(wg_show latest-handshakes)
        now=$(date +%s)
        nmcli -t -f NAME,TYPE,DEVICE connection show |
          while IFS=: read -r name type dev; do
            [ "$type" = wireguard ] || continue
            address=$(nmcli -g ipv4.addresses connection show "$name" | cut -d, -f1)
            rx=""; tx=""; endpoint=""; handshake=""
            if [ -n "$dev" ]; then
              read -r rx tx < <(ip -j -s link show dev "$dev" | jq -r '.[0].stats64 | "\(.rx.bytes) \(.tx.bytes)"')
              rx=$(numfmt --to=iec-i --suffix=B "$rx"); tx=$(numfmt --to=iec-i --suffix=B "$tx")
              endpoint=$(awk -v d="$dev" '$1 == d { print $3; exit }' <<<"$endpoints")
              last=$(awk -v d="$dev" '$1 == d { print $3; exit }' <<<"$handshakes")
              if [ -z "$last" ]; then handshake="unknown"
              elif [ "$last" -eq 0 ]; then handshake="never"
              else
                ago=$((now - last))
                if [ "$ago" -lt 120 ]; then handshake="''${ago}s ago"; else handshake="$((ago / 60))m ago"; fi
              fi
            fi
            jq -nc --arg name "$name" --arg dev "$dev" --arg address "$address" \
              --arg endpoint "$endpoint" --arg rx "$rx" --arg tx "$tx" --arg handshake "$handshake" \
              '{name: $name, active: ($dev != ""), device: $dev, address: $address,
                endpoint: $endpoint, rx: $rx, tx: $tx, handshake: $handshake}'
          done |
          jq -sc '{active: (map(select(.active)) | length), tunnels: .}'
      }

      case "''${1:-}" in
        toggle)
          name=$2
          if [ -n "$(nmcli -g GENERAL.STATE connection show --active "$name" 2>/dev/null)" ]; then
            nmcli connection down id "$name" >/dev/null
          else
            nmcli connection up id "$name" >/dev/null
          fi
          eww update wg="$(list)"
          ;;
        *) list ;;
      esac
    '';
  };

  # Caps Lock / Num Lock state from the keyboard LEDs (world-readable), as
  # {"caps": bool, "num": bool}. Any keyboard with the LED lit counts.
  locks = pkgs.writeShellApplication {
    name = "eww-locks";
    text = ''
      lit() {
        for led in /sys/class/leds/*::"$1"/brightness; do
          [ -r "$led" ] && [ "$(cat "$led")" != 0 ] && { echo true; return; }
        done
        echo false
      }
      printf '{"caps":%s,"num":%s}\n' "$(lit capslock)" "$(lit numlock)"
    '';
  };

  # What's running: GameMode, Steam (Flathub or native), LM Studio and the
  # models it has loaded (its API on localhost:1234, docs/lmstudio.md), and
  # the libvirt VMs.
  activity = pkgs.writeShellApplication {
    name = "eww-activity";
    runtimeInputs = with pkgs; [
      flatpak
      gamemode
      procps
      curl
      jq
      libvirt
      gnugrep
    ];
    text = ''
      # JSON for the bar's activity badges:
      # {"gamemode": bool, "steam": bool,
      #  "lmstudio": {"running": bool, "serving": bool, "first": id, "list": "id, id"},
      #  "vms": {"count": n, "list": "name, name"}}   (running libvirt domains)
      apps=$(flatpak ps --columns=application 2>/dev/null || true)
      running() { grep -qx "$1" <<<"$apps"; }

      gamemode=false
      gamemoded -s 2>/dev/null | grep -q 'is active' && gamemode=true

      steam=false
      if running com.valvesoftware.Steam || pgrep -x steam >/dev/null; then steam=true; fi

      lms=false
      models='[]'
      if running ai.lmstudio.lm-studio; then
        lms=true
        # LM Studio's own REST API lists every model with its load state.
        models=$(curl -fsS -m 1 http://127.0.0.1:1234/api/v0/models 2>/dev/null |
          jq -c '[.data[]? | select(.state == "loaded") | .id]' 2>/dev/null) || models='[]'
        [ -n "$models" ] || models='[]'
      fi

      vms=$(virsh -c qemu:///system list --name 2>/dev/null | jq -Rsc 'split("\n") | map(select(. != ""))') || vms='[]'

      jq -nc --argjson gamemode "$gamemode" --argjson steam "$steam" --argjson lms "$lms" \
        --argjson models "$models" --argjson vms "$vms" \
        '{gamemode: $gamemode, steam: $steam,
          lmstudio: {running: $lms, serving: ($models | length > 0),
                     first: ($models[0] // ""), list: ($models | join(", "))},
          vms: {count: ($vms | length), list: ($vms | join(", "))}}'
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
    (defpoll wg :interval "5s" :initial "{\"active\":0,\"tunnels\":[]}" "${wireguard}/bin/eww-wg")
    (defpoll activity :interval "5s"
      :initial "{\"gamemode\":false,\"steam\":false,\"lmstudio\":{\"running\":false,\"serving\":false,\"first\":\"\",\"list\":\"\"},\"vms\":{\"count\":0,\"list\":\"\"}}"
      "${activity}/bin/eww-activity")
    (defpoll locks :interval "500ms" :initial "{\"caps\":false,\"num\":false}" "${locks}/bin/eww-locks")
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
        (label :class "lock caps" :visible {locks.caps} :text "CAPS")
        (label :class "lock num" :visible {locks.num} :text "NUM")
        (box :class "module gamemode" :visible {activity.gamemode} :tooltip "GameMode is on"
          (label :class "icon" :text "󰊗"))
        (box :class "module steam" :visible {activity.steam} :tooltip "Steam is running"
          (label :class "icon" :text "󰓓"))
        (eventbox :visible {activity.lmstudio.running}
          :onrightclick "${pkgs.eww}/bin/eww open --toggle lms-menu"
          (box :class "module lmstudio ''${activity.lmstudio.serving ? "serving" : ""}"
            :orientation "h" :space-evenly false :spacing 6
            :tooltip {activity.lmstudio.serving
              ? "LM Studio is serving: ''${activity.lmstudio.list} (right-click for options)"
              : "LM Studio is running, no model loaded (right-click for options)"}
            (label :class "icon" :text "󰚩")
            (label :visible {activity.lmstudio.serving} :limit-width 24 :text "''${activity.lmstudio.first}")))
        (box :class "module vms" :visible {activity.vms.count > 0} :orientation "h" :space-evenly false :spacing 6
          :tooltip "VMs running: ''${activity.vms.list}"
          (label :class "icon" :text "󰒋")
          (label :text "''${activity.vms.count}"))
        (module :class "cpu" :icon "" :text "''${round(EWW_CPU.avg, 0)}%")
        (module :class "mem" :icon "" :text "''${round(EWW_RAM.used_mem_perc, 0)}%")
        (button
          :class "module wg ''${wg.active > 0 ? "on" : ""}"
          :tooltip "WireGuard: click for tunnels"
          :onclick "${pkgs.eww}/bin/eww open --toggle wg"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text "󰖂")
            (label :text "''${wg.active}")))
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

    (defwidget wg-panel []
      (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
        (box :orientation "h" :space-evenly false
          (label :class "wg-title" :hexpand true :halign "start" :text "WireGuard")
          (button :class "wg-close" :onclick "${pkgs.eww}/bin/eww close wg" "✕"))
        (label :class "wg-detail" :visible {arraylength(wg.tunnels) == 0} :halign "start" :wrap true
          :text "No tunnels yet. Import one with: nmcli connection import type wireguard file wg0.conf")
        (for t in {wg.tunnels}
          (box :class "wg-tunnel ''${t.active ? "up" : "down"}" :orientation "h" :space-evenly false :spacing 16
            (box :orientation "v" :space-evenly false :hexpand true :spacing 2
              (label :class "wg-name" :halign "start" :text "''${t.active ? "●" : "○"} ''${t.name}")
              (label :class "wg-detail" :halign "start" :text "''${t.address}")
              (label :class "wg-detail" :visible {t.active} :halign "start"
                :text "''${t.endpoint != "" ? t.endpoint : "no peer endpoint"} · handshake ''${t.handshake}")
              (label :class "wg-detail" :visible {t.active} :halign "start" :text "↓ ''${t.rx}  ↑ ''${t.tx}"))
            (button :class "wg-toggle" :valign "center"
              :onclick "${wireguard}/bin/eww-wg toggle \"''${t.name}\""
              "''${t.active ? "Disconnect" : "Connect"}")))))

    ; Right-click menu for the LM Studio icon.
    (defwidget lms-menu []
      (box :class "menu" :orientation "v" :space-evenly false :spacing 4
        (button :class "menu-item danger"
          :onclick "${pkgs.eww}/bin/eww close lms-menu; ${pkgs.flatpak}/bin/flatpak kill ai.lmstudio.lm-studio"
          "Close LM Studio")
        (button :class "menu-item" :onclick "${pkgs.eww}/bin/eww close lms-menu" "Cancel")))

    (defwindow lms-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :anchor "top right")
      (lms-menu))

    (defwindow wg
      :monitor 0
      :stacking "overlay"
      :namespace "eww-wg"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (wg-panel))

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
      &.gamemode .icon { color: $green; }
      &.steam .icon { color: $blue; }
      &.lmstudio .icon { color: $muted; }
      &.lmstudio.serving .icon { color: $pink; }
      &.vms .icon { color: $orange; }
      &.wg { color: $muted; &:hover { background-color: $surface; } }
      &.wg.on { color: $cyan; }
      &.caffeine { color: $muted; &:hover { background-color: $surface; } }
      &.caffeine.on { color: $orange; }
    }

    .lock {
      padding: 0 8px;
      color: $bg;
      font-weight: bold;
      &.caps { background-color: $yellow; }
      &.num { background-color: $purple; }
    }

    .menu {
      background-color: $bg;
      color: $fg;
      border: 2px solid $surface;
      padding: 6px;
      .menu-item {
        padding: 4px 12px;
        &:hover { background-color: $surface; }
        &.danger:hover { color: $bg; background-color: $red; }
      }
    }

    .wg-panel {
      background-color: $bg;
      color: $fg;
      border: 2px solid $surface;
      padding: 12px;
      .wg-title { color: $cyan; font-weight: bold; }
      .wg-close { color: $muted; padding: 0 4px; &:hover { color: $fg; } }
      .wg-tunnel { background-color: $bg-alt; padding: 8px 10px; }
      .wg-tunnel.up .wg-name { color: $green; }
      .wg-tunnel.down .wg-name { color: $muted; }
      .wg-detail { color: $muted; }
      .wg-toggle {
        padding: 4px 10px;
        background-color: $surface;
        &:hover { color: $bg; background-color: $pink; }
      }
    }
  '';
}
