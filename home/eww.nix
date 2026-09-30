# Elkowar's Wacky Widgets — top bar for sway.
{
  config,
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;
  eww = "${pkgs.eww}/bin/eww";

  # The longer bar scripts live in home/eww/.
  script =
    name: file: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile file;
    };

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

  volume = script "eww-volume" ./eww/volume.sh (
    with pkgs;
    [
      wireplumber
      gawk
      gnused
      jq
      eww
    ]
  );

  # GPU load, temperature and VRAM from rocm-smi (modules/nixos/fans.nix).
  gpu = script "eww-gpu" ./eww/gpu.sh [
    pkgs.rocmPackages.rocm-smi
    pkgs.jq
  ];

  # Up/down rates of one interface for the bar, all of them for its panel.
  net = script "eww-net" ./eww/net.sh (
    with pkgs;
    [
      iproute2
      gawk
      jq
      coreutils
      eww
    ]
  );

  # The month grid with CalDAV event dots (synced by vdirsyncer, below).
  cal =
    pkgs.writers.writePython3Bin "eww-cal"
      {
        libraries = with pkgs.python3Packages; [
          icalendar
          recurring-ical-events
        ];
        flakeIgnore = [ "E501" ];
      }
      (
        builtins.replaceStrings
          [ ''COLORS = ["#ff5faf", "#5fd7ff", "#ffd75f"]'' ''EWW = "eww"'' ]
          [
            "COLORS = [${
              lib.concatMapStringsSep ", " (c: ''"${c}"'') [
                p.pink
                p.cyan
                p.yellow
                p.purple
                p.green
                p.orange
                p.blue
              ]
            }]"
            ''EWW = "${eww}"''
          ]
          (builtins.readFile ./eww/cal.py)
      );

  # "Wed Sep 30 14:16" in the time zone picked in the calendar panel.
  clock = script "eww-clock" ./eww/clock.sh [
    pkgs.coreutils
    pkgs.jq
    pkgs.eww
    cal
  ];

  # One icon per display, its resolution, and which one is primary (has the bar).
  display = script "eww-display" ./eww/display.sh (
    with pkgs;
    [
      sway
      jq
      gnugrep
      coreutils
      eww
    ]
  );
  menu = "${display}/bin/eww-display menu";

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

  # Quit Steam the way its own menu does (steam -shutdown), for whichever
  # install is running: Flathub or native.
  steamClose = pkgs.writeShellApplication {
    name = "eww-steam-close";
    runtimeInputs = with pkgs; [
      flatpak
      gnugrep
    ];
    text = ''
      if flatpak ps --columns=application 2>/dev/null | grep -qx com.valvesoftware.Steam; then
        flatpak run com.valvesoftware.Steam -shutdown
      elif command -v steam >/dev/null; then
        steam -shutdown
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
  # eww-display is also run by sway at startup (home/sway.nix).
  home.packages = [
    pkgs.eww
    display
    pkgs.vdirsyncer
  ];

  # CalDAV sync for the calendar panel: vdirsyncer with your own config in
  # ~/.config/vdirsyncer/config (docs/calendar.md), every 15 minutes. It
  # does nothing until that file exists.
  systemd.user.services.vdirsyncer = {
    Unit = {
      Description = "Sync calendars for the eww calendar (vdirsyncer)";
      ConditionPathExists = "%h/.config/vdirsyncer/config";
    };
    Service = {
      Type = "oneshot";
      # pass (for password.fetch) looks for the store here, as in home/secrets.nix.
      Environment = [ "PASSWORD_STORE_DIR=${config.xdg.dataHome}/password-store" ];
      ExecStart = [
        "-${pkgs.vdirsyncer}/bin/vdirsyncer metasync"
        "${pkgs.vdirsyncer}/bin/vdirsyncer sync"
      ];
      ExecStartPost = "-${cal}/bin/eww-cal refresh";
    };
  };
  systemd.user.timers.vdirsyncer = {
    Unit.Description = "Sync calendars every 15 minutes";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.configFile."eww/eww.yuck".text = ''
    (deflisten workspaces :initial "[]" "${workspaces}/bin/eww-sway-workspaces")
    (deflisten title :initial "" "${title}/bin/eww-sway-title")
    (deflisten mode :initial "{\"name\":\"default\",\"hint\":\"\"}" "${mode}/bin/eww-sway-mode")
    (defpoll volume :interval "2s" :initial "{\"pct\":0,\"muted\":false,\"sink\":\"\",\"text\":\"\"}"
      "${volume}/bin/eww-volume")
    (defpoll gpu :interval "3s" :initial "{\"ok\":false,\"use\":0,\"temp\":0,\"vram\":0,\"vram_text\":\"\"}"
      "${gpu}/bin/eww-gpu")
    (defpoll net :interval "2s"
      :initial "{\"auto\":true,\"default\":\"\",\"shown\":{\"name\":\"\",\"state\":\"down\",\"wireless\":false,\"down\":\"\",\"up\":\"\",\"address\":\"\"},\"ifaces\":[]}"
      "${net}/bin/eww-net")
    (deflisten displays :initial "{\"primary\":\"\",\"outputs\":[],\"selected\":[]}" "${display}/bin/eww-display watch")
    (defvar display_modes_open false)
    (defpoll wg :interval "5s" :initial "{\"active\":0,\"tunnels\":[]}" "${wireguard}/bin/eww-wg")
    (defpoll activity :interval "5s"
      :initial "{\"gamemode\":false,\"steam\":false,\"lmstudio\":{\"running\":false,\"serving\":false,\"first\":\"\",\"list\":\"\"},\"vms\":{\"count\":0,\"list\":\"\"}}"
      "${activity}/bin/eww-activity")
    (defpoll locks :interval "500ms" :initial "{\"caps\":false,\"num\":false}" "${locks}/bin/eww-locks")
    (defpoll caffeine :interval "10s" "${caffeine}/bin/eww-caffeine")
    (defpoll battery :interval "30s" "${battery}/bin/eww-battery")
    (defpoll time :interval "10s" :initial "{\"text\":\"\",\"abbr\":\"\",\"zone\":\"local\"}"
      "${clock}/bin/eww-clock")
    (defpoll cal :interval "60s"
      :initial "{\"title\":\"\",\"zone\":\"\",\"calendars\":[],\"weeks\":[],\"selected\":{\"label\":\"\",\"events\":[]}}"
      "${cal}/bin/eww-cal")

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
        (button :class "module steam" :visible {activity.steam}
          :tooltip "Steam is running: click for options"
          :onclick "${menu} steam-menu"
          (label :class "icon" :text "󰓓"))
        (button :class "module lmstudio ''${activity.lmstudio.serving ? "serving" : ""}"
          :visible {activity.lmstudio.running}
          :tooltip {activity.lmstudio.serving
            ? "LM Studio is serving: ''${activity.lmstudio.list} (click for options)"
            : "LM Studio is running, no model loaded (click for options)"}
          :onclick "${menu} lms-menu"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text "󰚩")
            (label :visible {activity.lmstudio.serving} :limit-width 24 :text "''${activity.lmstudio.first}")))
        (box :class "module vms" :visible {activity.vms.count > 0} :orientation "h" :space-evenly false :spacing 6
          :tooltip "VMs running: ''${activity.vms.list}"
          (label :class "icon" :text "󰒋")
          (label :text "''${activity.vms.count}"))
        ; In its own box: eww adds a for loop's new children at the end of its parent.
        (box :orientation "h" :space-evenly false :spacing 4
          (for o in {displays.outputs}
            (button :class "module display ''${o.primary ? "primary" : ""} ''${o.active ? "" : "off"}"
              :tooltip "Display ''${o.number}: ''${o.name} ''${o.title}, ''${o.current}''${o.primary ? ", primary (has the bar)" : ""}. Click to change"
              :onclick "${display}/bin/eww-display select ''${o.name}"
              (box :orientation "h" :space-evenly false :spacing 4
                (label :class "icon" :text "󰍹")
                (label :text "''${o.number}")
                (label :class "star" :visible {o.primary} :text "󰓎")))))
        (module :class "cpu" :icon "" :text "''${round(EWW_CPU.avg, 0)}%")
        (module :class "mem" :icon "" :text "''${round(EWW_RAM.used_mem_perc, 0)}%")
        (box :class "module gpu" :visible {gpu.ok} :orientation "h" :space-evenly false :spacing 6
          :tooltip "GPU ''${gpu.use}% · ''${gpu.temp}°C · VRAM ''${gpu.vram_text} (''${gpu.vram}%)"
          (label :class "icon" :text "󰢮")
          (label :text "''${gpu.use}% ''${gpu.temp}°"))
        (button :class "module net ''${net.shown.state == "up" ? "" : "down"}"
          :tooltip "''${net.shown.name} ''${net.shown.address}: click for all interfaces"
          :onclick "${menu} net-menu"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text {net.shown.wireless ? "󰖩" : "󰈀"})
            (label :text "''${net.shown.name} ↓''${net.shown.down} ↑''${net.shown.up}")))
        (button
          :class "module wg ''${wg.active > 0 ? "on" : ""}"
          :tooltip "WireGuard: click for tunnels"
          :onclick "${menu} wg"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text "󰖂")
            (label :text "''${wg.active}")))
        (button
          :class "module caffeine ''${caffeine}"
          :tooltip "Caffeine ''${caffeine}: click to ''${caffeine == "on" ? "allow" : "stop"} locking and screen blanking"
          :onclick "${caffeine}/bin/eww-caffeine toggle"
          (label :class "icon" :text {caffeine == "on" ? "󰅶" : "󰛊"}))
        (eventbox :class "module vol ''${volume.muted ? "muted" : ""}"
          :tooltip "''${volume.sink}: click for volume, scroll to change"
          :onclick "${menu} vol-menu"
          :onscroll "${volume}/bin/eww-volume {}"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text {volume.muted ? "󰖁" : "󰕾"})
            (label :text "''${volume.text}")))
        (module :class "bat" :icon "󰁹" :text "''${battery}%" :visible {battery != ""})
        (button :class "module clock" :tooltip "''${time.zone}: click for the calendar and time zones"
          :onclick "${cal}/bin/eww-cal today; ${menu} cal-menu"
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text "󰥔")
            (label :text "''${time.text}")
            (label :class "tz" :text "''${time.abbr}")))))

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

    ; Panels opened by the Steam and LM Studio buttons, laid out like the
    ; WireGuard panel.
    (defwidget app-panel [title name status action onclose onaction]
      (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
        (box :orientation "h" :space-evenly false
          (label :class "wg-title" :hexpand true :halign "start" :text title)
          (button :class "wg-close" :onclick onclose "✕"))
        (box :class "wg-tunnel up" :orientation "h" :space-evenly false :spacing 16
          (box :orientation "v" :space-evenly false :hexpand true :spacing 2
            (label :class "wg-name" :halign "start" :text "● ''${name}")
            (label :class "wg-detail" :halign "start" :wrap true :text status))
          (button :class "wg-toggle" :valign "center" :onclick onaction action))))

    (defwidget lms-menu []
      (app-panel
        :title "LM Studio"
        :name "LM Studio"
        :status {activity.lmstudio.serving
          ? "Serving: ''${activity.lmstudio.list}"
          : "Running, no model loaded"}
        :action "Close"
        :onclose "${pkgs.eww}/bin/eww close lms-menu"
        :onaction "${pkgs.eww}/bin/eww close lms-menu; ${pkgs.flatpak}/bin/flatpak kill ai.lmstudio.lm-studio"))

    (defwidget steam-menu []
      (app-panel
        :title "Steam"
        :name "Steam"
        :status "Running"
        :action "Close"
        :onclose "${pkgs.eww}/bin/eww close steam-menu"
        :onaction "${pkgs.eww}/bin/eww close steam-menu; ${steamClose}/bin/eww-steam-close"))

    ; Network: every interface's rates, and which one the bar shows.
    (defwidget net-panel []
      (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
        (box :orientation "h" :space-evenly false
          (label :class "wg-title" :hexpand true :halign "start" :text "Network")
          (button :class "wg-close" :onclick "${eww} close net-menu" "✕"))
        (box :class "wg-tunnel ''${net.auto ? "up" : "down"}" :orientation "h" :space-evenly false :spacing 16
          (box :orientation "v" :space-evenly false :hexpand true :spacing 2
            (label :class "wg-name" :halign "start" :text "''${net.auto ? "●" : "○"} Automatic")
            (label :class "wg-detail" :halign "start"
              :text "Default route: ''${net.default != "" ? net.default : "none"}"))
          (button :class "wg-toggle ''${net.auto ? "active" : ""}" :valign "center"
            :onclick "${net}/bin/eww-net show auto"
            "''${net.auto ? "Shown" : "Show"}"))
        (for i in {net.ifaces}
          (box :class "wg-tunnel ''${i.state == "up" ? "up" : "down"}" :orientation "h" :space-evenly false :spacing 16
            (box :orientation "v" :space-evenly false :hexpand true :spacing 2
              (label :class "wg-name" :halign "start"
                :text "''${i.state == "up" ? "●" : "○"} ''${i.name}''${i.default ? " (default route)" : ""}")
              (label :class "wg-detail" :halign "start" :text "''${i.state} ''${i.address}")
              (label :class "wg-detail" :halign "start" :text "↓ ''${i.down}  ↑ ''${i.up}"))
            (button :class "wg-toggle ''${i.shown && !net.auto ? "active" : ""}" :valign "center"
              :onclick "${net}/bin/eww-net show ''${i.name}"
              "''${i.shown && !net.auto ? "Shown" : "Show"}")))))

    ; Volume of the default output: slider, ±5% and mute.
    (defwidget vol-panel []
      (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
        (box :orientation "h" :space-evenly false
          (label :class "wg-title" :hexpand true :halign "start" :text "Volume")
          (button :class "wg-close" :onclick "${eww} close vol-menu" "✕"))
        (box :class "wg-tunnel ''${volume.muted ? "down" : "up"}" :orientation "v" :space-evenly false :spacing 10
          (box :orientation "h" :space-evenly false :spacing 8
            (label :class "wg-name" :hexpand true :halign "start" :limit-width 28
              :text "''${volume.muted ? "○" : "●"} ''${volume.sink != "" ? volume.sink : "Default output"}")
            (label :class "wg-detail" :text "''${volume.text}"))
          (scale :class "vol-scale" :min 0 :max 101 :value {volume.pct}
            :onchange "${volume}/bin/eww-volume set {}")
          (box :orientation "h" :space-evenly true :spacing 8
            (button :class "wg-toggle" :onclick "${volume}/bin/eww-volume down" "− 5%")
            (button :class "wg-toggle" :onclick "${volume}/bin/eww-volume mute"
              "''${volume.muted ? "Unmute" : "Mute"}")
            (button :class "wg-toggle" :onclick "${volume}/bin/eww-volume up" "+ 5%")))))

    ; Calendar: time zone, month grid with a dot per calendar with events
    ; that day (docs/calendar.md), and the picked day's events.
    (defwidget tz-button [zone name]
      (button :class "wg-toggle ''${time.zone == zone ? "active" : ""}"
        :onclick "${clock}/bin/eww-clock tz ''${zone}" name))

    (defwidget cal-panel []
      (box :class "wg-panel cal-panel" :orientation "v" :space-evenly false :spacing 10
        (box :orientation "h" :space-evenly false
          (label :class "wg-title" :hexpand true :halign "start" :text "''${time.text} ''${time.abbr}")
          (button :class "wg-close" :onclick "${eww} close cal-menu" "✕"))
        (box :orientation "h" :space-evenly true :spacing 6
          (tz-button :zone "America/New_York" :name "Eastern")
          (tz-button :zone "America/Los_Angeles" :name "Pacific")
          (tz-button :zone "UTC" :name "UTC"))
        (box :orientation "h" :space-evenly false :spacing 6
          (button :class "cal-nav" :onclick "${cal}/bin/eww-cal prev" "‹")
          (label :class "cal-title" :hexpand true :text "''${cal.title}")
          (button :class "cal-nav" :onclick "${cal}/bin/eww-cal today" "Today")
          (button :class "cal-nav" :onclick "${cal}/bin/eww-cal next" "›"))
        (box :class "cal-grid" :orientation "v" :space-evenly false :spacing 2
          (box :class "cal-head" :orientation "h" :space-evenly true
            (label :text "Su") (label :text "Mo") (label :text "Tu") (label :text "We")
            (label :text "Th") (label :text "Fr") (label :text "Sa"))
          (for week in {cal.weeks}
            (box :orientation "h" :space-evenly true :spacing 2
              (for d in week
                (button
                  :class "cal-day ''${d.other ? "other" : ""} ''${d.today ? "today" : ""} ''${d.selected ? "selected" : ""}"
                  :onclick "${cal}/bin/eww-cal day ''${d.date}"
                  (box :orientation "v" :space-evenly false
                    (label :class "cal-num" :text "''${d.day}")
                    (box :class "cal-dots" :orientation "h" :halign "center" :space-evenly false :spacing 1
                      (for c in {d.dots}
                        (label :class "cal-dot" :style "color: ''${c};" :text "󰝥")))))))))
        (label :class "wg-name cal-day-title" :halign "start" :text "''${cal.selected.label}")
        (label :class "wg-detail" :visible {arraylength(cal.selected.events) == 0} :halign "start" :wrap true
          :text {arraylength(cal.calendars) == 0
            ? "No calendars synced yet. See docs/calendar.md to set up vdirsyncer."
            : "No events"})
        (for e in {cal.selected.events}
          (box :class "cal-event" :orientation "h" :space-evenly false :spacing 8
            (label :class "cal-dot" :style "color: ''${e.color};" :text "󰝥")
            (label :class "wg-detail" :text "''${e.time}")
            (label :hexpand true :halign "start" :limit-width 36 :text "''${e.summary}")))))

    ; Display: primary (has the bar), on/off, and a resolution dropdown, for
    ; the display whose bar icon was clicked.
    (defwidget display-panel []
      (box :class "wg-panel" :orientation "v" :space-evenly false
        (for o in {displays.selected}
          (box :orientation "v" :space-evenly false :spacing 10
            (box :orientation "h" :space-evenly false
              (label :class "wg-title" :hexpand true :halign "start" :text "Display ''${o.number}")
              (button :class "wg-close" :onclick "${eww} close display-menu" "✕"))
            (box :class "wg-tunnel ''${o.active ? "up" : "down"}" :orientation "h" :space-evenly false :spacing 16
              (box :orientation "v" :space-evenly false :hexpand true :spacing 2
                (label :class "wg-name" :halign "start"
                  :text "''${o.active ? "●" : "○"} ''${o.name}''${o.primary ? " · primary" : ""}")
                (label :class "wg-detail" :halign "start" :visible {o.title != ""} :text "''${o.title}")
                (label :class "wg-detail" :halign "start"
                  :text {o.primary ? "Has the bar" : (o.active ? "No bar" : "Off")}))
              (box :orientation "v" :space-evenly false :valign "center" :spacing 6
                (button :class "wg-toggle" :visible {!o.primary && o.active}
                  :onclick "${display}/bin/eww-display primary ''${o.name}" "Make primary")
                (button :class "wg-toggle" :visible {!o.primary}
                  :onclick "${display}/bin/eww-display power ''${o.name} ''${o.active ? "off" : "on"}"
                  "''${o.active ? "Turn off" : "Turn on"}")))
            (box :visible {o.active} :orientation "v" :space-evenly false :spacing 4
              (label :class "wg-detail" :halign "start" :text "Resolution")
              (button :class "display-drop"
                :onclick "${display}/bin/eww-display dropdown"
                (box :orientation "h" :space-evenly false
                  (label :hexpand true :halign "start" :text "''${o.current}")
                  (label :text {display_modes_open ? "󰅃" : "󰅀"})))
              (box :orientation "v" :space-evenly false
                (scroll :vscroll true :hscroll false
                  :height {display_modes_open ? min(240, arraylength(o.modes) * 30) : 0}
                  (box :orientation "v" :space-evenly false
                    ; Built only while open: GTK windows grow but never shrink, so
                    ; hidden rows would still take up room.
                    (for m in {display_modes_open ? o.modes : []}
                      (button :class "display-mode ''${m.id == o.current_id ? "current" : ""}"
                        :onclick "${display}/bin/eww-display mode ''${o.name} ''${m.id}"
                        (label :halign "start" :text "''${m.label}")))))))))))

    (defwindow net-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (net-panel))

    (defwindow vol-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (vol-panel))

    (defwindow cal-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (cal-panel))

    (defwindow display-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (display-panel))

    (defwindow steam-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
      (steam-menu))

    (defwindow lms-menu
      :monitor 0
      :stacking "overlay"
      :namespace "eww-menu"
      :geometry (geometry :x "8px" :y "34px" :width "360px" :anchor "top right")
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
      &.steam, &.lmstudio { &:hover { background-color: $surface; } }
      &.lmstudio .icon { color: $muted; }
      &.lmstudio.serving .icon { color: $pink; }
      &.vms .icon { color: $orange; }
      &.wg { color: $muted; &:hover { background-color: $surface; } }
      &.wg.on { color: $cyan; }
      &.caffeine { color: $muted; &:hover { background-color: $surface; } }
      &.caffeine.on { color: $orange; }
      &.gpu .icon { color: $red; }
      &.net .icon { color: $blue; }
      &.net.down { color: $muted; }
      &.vol.muted { color: $muted; .icon { color: $muted; } }
      &.display .icon { color: $muted; }
      &.display.primary .icon, .star { color: $pink; }
      &.display.off { color: $muted; }
      &.display, &.net, &.vol, &.clock { &:hover { background-color: $surface; } }
      .tz { color: $muted; }
    }

    .lock {
      padding: 0 8px;
      color: $bg;
      font-weight: bold;
      &.caps { background-color: $yellow; }
      &.num { background-color: $purple; }
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
        &.active { color: $bg; background-color: $cyan; }
      }

      .vol-scale {
        trough { background-color: $surface; min-height: 6px; min-width: 300px; }
        highlight { background-color: $cyan; }
        slider { background-color: $pink; min-width: 14px; min-height: 14px; margin: -4px 0; }
      }

      .cal-nav { padding: 2px 10px; color: $muted; &:hover { color: $fg; background-color: $surface; } }
      .cal-title { color: $fg; font-weight: bold; }
      .cal-head { color: $muted; }
      .cal-day {
        padding: 2px 0;
        &:hover { background-color: $surface; }
        &.other .cal-num { color: $muted; }
        &.today .cal-num { color: $pink; font-weight: bold; }
        &.selected { background-color: $bg-alt; }
      }
      .cal-dots { min-height: 8px; }
      .cal-dot { font-size: ${toString (p.font.size - 4)}pt; }
      .cal-day-title { color: $cyan; }
      .cal-event { background-color: $bg-alt; padding: 4px 8px; }

      .display-drop {
        background-color: $bg-alt;
        padding: 6px 10px;
        &:hover { background-color: $surface; }
      }
      .display-mode {
        padding: 4px 10px;
        &:hover { background-color: $surface; }
        &.current { color: $cyan; }
      }
    }
  '';
}
