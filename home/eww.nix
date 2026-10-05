# Elkowar's Wacky Widgets — top bar for sway.
{
  config,
  osConfig,
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;
  eww = "${pkgs.eww}/bin/eww";

  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  # The bar scripts live in home/eww/, one Python file per command.
  script =
    name: file: runtimeInputs:
    pyScript name { inherit runtimeInputs; } file;

  # Emits the workspace list as JSON on every sway workspace event.
  workspaces = script "eww-sway-workspaces" ./eww/workspaces.py [ pkgs.sway ];

  # Emits the focused window's title whenever focus or titles change.
  title = script "eww-sway-title" ./eww/title.py [ pkgs.sway ];

  # Steam's launcher is only bound where its flatpak is installed (sway.nix).
  hasSteam = lib.any (p: (p.appId or p) == "com.valvesoftware.Steam") (
    osConfig.services.flatpak.packages or [ ]
  );

  # Key hints for sway's modes (home/sway.nix), shown while a mode is active.
  modeHints = {
    resize = "h/j/k/l resize · Shift = ×5 · Esc done";
    open =
      "b zen · f ranger · e nvim · t tmux · s btop · a audio · u bluetooth · n network · v nike · z zelus · g lutris"
      + lib.optionalString hasSteam " · G steam"
      + " · c element · l lm-studio";
    media = "j/k volume · m mute · M mic · h/l prev/next · p play · J/K brightness";
    system = "l lock · e exit · s suspend · r reboot · P poweroff";
  };

  # Emits {"name": …, "hint": …} whenever the sway binding mode changes.
  mode = pyScript "eww-sway-mode" {
    runtimeInputs = [ pkgs.sway ];
    replace."HINTS: dict = {}" =
      "HINTS: dict = json.loads(${builtins.toJSON (builtins.toJSON modeHints)})";
  } ./eww/mode.py;

  volume = script "eww-volume" ./eww/volume.py [
    pkgs.wireplumber
    pkgs.eww
  ];

  # CPU model, temperature and load average for the CPU tooltip.
  cpu = script "eww-cpu" ./eww/cpu.py [ ];

  # GPU load, temperature and VRAM from rocm-smi (modules/nixos/fans.nix).
  # ROCm is x86_64 only; elsewhere (e.g. an aarch64 Dionysus VM) the widget
  # just reports no GPU and hides itself.
  gpu = script "eww-gpu" ./eww/gpu.py (
    lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ pkgs.rocmPackages.rocm-smi ]
  );

  # Up/down rates of one interface for the bar, all of them for its panel.
  net = script "eww-net" ./eww/net.py [
    pkgs.iproute2
    pkgs.eww
  ];

  # The month grid with CalDAV event dots (synced by vdirsyncer, below).
  cal = pyScript "eww-cal" {
    libraries = with pkgs.python3Packages; [
      icalendar
      recurring-ical-events
    ];
    replace = {
      "COLORS = [\"#ff5faf\", \"#5fd7ff\", \"#ffd75f\"]" = "COLORS = [${
        lib.concatMapStringsSep ", " (c: ''"${c}"'') [
          p.pink
          p.cyan
          p.yellow
          p.purple
          p.green
          p.orange
          p.blue
        ]
      }]";
      "EWW = \"eww\"" = ''EWW = "${eww}"'';
    };
  } ./eww/cal.py;

  # "Wed Sep 30 14:16" in the time zone picked in the calendar panel.
  clock = script "eww-clock" ./eww/clock.py [
    pkgs.eww
    cal
  ];

  # Each display's saved resolution and position, and which one is primary
  # (has the bar).
  display = script "eww-display" ./eww/display.py [
    pkgs.sway
    pkgs.eww
  ];
  menu = "${display}/bin/eww-display menu";

  # The display settings window: layout, resolution, on/off and primary in
  # one place, opened from the bar's display button (or fuzzel).
  displaySettings = pyScript "display-settings" {
    runtimeInputs = [
      pkgs.sway
      display
    ];
    libraries = [ pkgs.python3Packages.pygobject3 ];
    wrapperArgs = [
      "--prefix"
      "GI_TYPELIB_PATH"
      ":"
      (lib.makeSearchPath "lib/girepository-1.0" (
        map lib.getLib (
          with pkgs;
          [
            gtk3
            pango
            gdk-pixbuf
            atk
            harfbuzz
            glib
            gobject-introspection
          ]
        )
      ))
      # Image loaders for the GTK theme's icons.
      "--set-default"
      "GDK_PIXBUF_MODULE_FILE"
      "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
    ];
    replace."COLORS = {\"bg\": \"#181825\", \"surface\": \"#313244\", \"fg\": \"#cdd6f4\", \"muted\": \"#7f849c\", \"pink\": \"#f472b6\", \"cyan\": \"#22d3ee\"}" =
      "COLORS = json.loads(${
        builtins.toJSON (
          builtins.toJSON {
            bg = p.bgAlt;
            surface = p.surface;
            fg = p.fg;
            muted = p.muted;
            pink = p.pink;
            cyan = p.cyan;
          }
        )
      })";
  } ./eww/display-settings.py;

  # Caffeine: stopping swayidle (home/sway.nix) turns off the lock and blank
  # timers until it is started again. The bar button toggles it.
  caffeine = script "eww-caffeine" ./eww/caffeine.py [
    pkgs.systemd
    pkgs.eww
  ];

  # VPNs (WireGuard and OpenVPN in NetworkManager, openfortivpn, see
  # modules/nixos/vpn.nix) for the network button's asterisks and its panel.
  vpn = pyScript "eww-vpn" {
    runtimeInputs = with pkgs; [
      networkmanager
      iproute2
      systemd
      eww
    ];
    replace."WG = \"wg\"" = ''WG = "${pkgs.wireguard-tools}/bin/wg"'';
  } ./eww/vpn.py;

  # Caps Lock / Num Lock state from the keyboard LEDs.
  locks = script "eww-locks" ./eww/locks.py [ ];

  # What's running: GameMode, Steam, LM Studio and its loaded models.
  activity = script "eww-activity" ./eww/activity.py (
    with pkgs;
    [
      flatpak
      gamemode
      procps
    ]
  );

  # Quit Steam the way its own menu does, Flathub or native.
  steamClose = script "eww-steam-close" ./eww/steam-close.py [ pkgs.flatpak ];

  # The microVMs (modules/nixos/nike.nix, zelus.nix): running or not, their
  # firewall mode, VPN and utilization, and switching the mode.
  microvm = script "eww-microvm" ./eww/microvm.py [
    pkgs.systemd
    pkgs.eww
  ];

  # The microVMs this host runs, taken from vm-firewall.nix. A host without
  # that module (e.g. Dionysus) has none, so the bar shows no VM widgets.
  vms = lib.attrNames (osConfig.harmonia.vmFirewall or { });
  hasVms = vms != [ ];

  # Each VM's firewall modes (modules/nixos/vm-firewall.nix), in order.
  vmModes = vm: osConfig.harmonia.vmFirewall.${vm}.modes;

  # A mode's label or short word from the VM's current mode, as a yuck
  # expression: nike.mode == "oscp" ? "OSCP" : (…).
  modeText =
    vm: field:
    lib.foldr (m: rest: ''(${vm}.mode == "${m.name}" ? "${m.${field}}" : ${rest})'') ''""'' (
      vmModes vm
    );

  # The same, padded to the VM's longest short word so the bar doesn't shift
  # when the mode changes (the bar font is monospaced).
  shortText =
    vm:
    let
      width = lib.foldl' lib.max 0 (map (m: lib.stringLength m.short) (vmModes vm));
      pad = t: t + lib.concatStrings (lib.replicate (width - lib.stringLength t) " ");
    in
    lib.foldr (m: rest: ''(${vm}.mode == "${m.name}" ? "${pad m.short}" : ${rest})'') ''"${pad ""}"'' (
      vmModes vm
    );

  # A VM's bar badge: the same server icon for each, in the VM's own colour
  # while it runs, and the firewall mode. Every part keeps its width, so the
  # bar never moves. Its VPN shows as an asterisk on the network button.
  vmBadge = vm: tooltip: ''
    (button :class "module vm ${vm} ''${${vm}.running ? "running" : "stopped"}"
      :tooltip ${tooltip}
      :onclick "${menu} ${vm}-menu"
      (box :orientation "h" :space-evenly false :spacing 2
        (label :class "icon" :text "󰒋")
        (label :class "vm-mode mode-''${${vm}.mode}" :xalign 0 :text "''${${shortText vm}}")))
  '';

  # A VM panel's start/stop button: Start while it is stopped, Stop while it
  # runs, and Starting…/Stopping… (disabled) until systemctl returns.
  powerButton = vm: ''
    (defvar ${vm}_busy "")
    (defwidget ${vm}-power []
      (button :class "vm-power ''${${vm}_busy != "" ? "busy" : (${vm}.running ? "stop" : "start")}"
        :active {${vm}_busy == ""}
        :tooltip "''${${vm}.running ? "Stop" : "Start"} microvm@${vm}"
        :onclick "${microvm}/bin/eww-microvm ${vm} ''${${vm}.running ? "stop" : "start"} &"
        (label :text "''${${vm}_busy == "start" ? "󰐊 Starting…" : (${vm}_busy == "stop" ? "󰓛 Stopping…" : (${vm}.running ? "󰓛 Stop" : "󰐊 Start"))}")))
  '';

  # The firewall dropdown in a VM's panel: the current mode, and the list of
  # modes when it is opened.
  firewallDropdown = vm: ''
    (defvar ${vm}_fw_open false)
    (defwidget ${vm}-firewall []
      (box :class "wg-tunnel vm-fw" :orientation "v" :space-evenly false :spacing 6
        (button :class "vm-fw-current" :onclick "${eww} update ${vm}_fw_open=''${!${vm}_fw_open}"
          (box :orientation "h" :space-evenly false
            (label :class "wg-name" :hexpand true :halign "start" :text "Firewall")
            (label :class "vm-fw-mode mode-''${${vm}.mode}" :text "''${${modeText vm "label"}} ''${${vm}_fw_open ? "▴" : "▾"}")))
        (revealer :reveal ${vm}_fw_open :transition "slidedown" :duration "150ms"
          (box :orientation "v" :space-evenly false :spacing 2
            ${
              lib.concatMapStrings (m: ''
                (button :class "vm-fw-item ''${${vm}.mode == "${m.name}" ? "active" : ""}"
                  :onclick "${microvm}/bin/eww-microvm ${vm} set ${m.name}"
                  (box :orientation "v" :space-evenly false :spacing 0
                    (label :class "vm-fw-label" :halign "start" :text "${m.label}")
                    (label :class "wg-detail" :halign "start" :xalign 0 :wrap true :text "${m.description}")))
              '') (vmModes vm)
            }))))
  '';

  # The status poll for each VM (home/eww/microvm.py).
  vmPoll = vm: ''
    (defpoll ${vm} :interval "3s"
      :initial "{\"running\":false,\"fresh\":false,\"mode\":\"\",\"cpu\":0,\"mem\":0,\"disk\":0,\"vpn\":{\"up\":false,\"via_vpn\":false}}"
      "${microvm}/bin/eww-microvm ${vm}")
  '';

  # What differs between the VMs' panels: `extra` goes above the System block
  # while the VM runs, `footer` says how to reach it.
  vmPanelInfo = {
    # Nike: where its traffic leaves (through the VPN or not).
    nike = {
      title = "Nike";
      extra = ''
        (box :class "wg-tunnel ''${nike.vpn.via_vpn ? "up" : "warn"}" :orientation "v" :space-evenly false :spacing 6
          (box :orientation "h" :space-evenly false
            (label :class "wg-name" :hexpand true :halign "start"
              :text "''${nike.vpn.via_vpn ? "●" : "○"} VPN outbound")
            (label :class "wg-detail" :text "via ''${nike.vpn.outbound}"))
          (label :class "wg-detail" :halign "start" :wrap true :text "''${nike.vpn.summary}")
          (label :class "wg-detail" :visible {nike.vpn.up} :halign "start"
            :text "Tunnel down ''${nike.vpn.rx_text} · up ''${nike.vpn.tx_text}"))
      '';
      footer = "ssh nike (k / k) · ~/nike-share is ~/share on Nike";
    };
    zelus = {
      title = "Zelus";
      footer = "ssh zelus (c, no password) · claude, opencode · ~/zelus-share is ~/share, ~/Projects is shared";
    };
  };

  # A VM's panel, opened from its badge: start/stop, its CPU, memory and disk
  # as its status service reports them from inside the VM, the firewall
  # dropdown and how to reach it.
  vmPanel =
    vm:
    let
      info = {
        title = vm;
        extra = "";
        footer = "ssh ${vm}";
      }
      // vmPanelInfo.${vm} or { };
    in
    ''
      ${powerButton vm}
      ${firewallDropdown vm}
      (defwidget ${vm}-panel []
        (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
          (box :orientation "h" :space-evenly false
            (label :class "wg-title ${vm}" :hexpand true :halign "start" :text "${info.title}")
            (${vm}-power)
            (button :class "wg-close" :onclick "${eww} close ${vm}-menu" "✕"))
          (label :class "wg-detail" :visible {!${vm}.running} :halign "start" :wrap true
            :text "${info.title} is stopped.")
          (label :class "wg-detail" :visible {${vm}.running && !${vm}.fresh} :halign "start" :wrap true
            :text "${info.title} is starting: no status from it yet.")
          (box :visible {${vm}.running && ${vm}.fresh} :orientation "v" :space-evenly false :spacing 10
            ${info.extra}
            (box :class "wg-tunnel" :orientation "v" :space-evenly false :spacing 6
              (label :class "wg-name" :halign "start" :text "System")
              (vm-meter :name "CPU" :value {${vm}.cpu} :text "''${${vm}.cpu_text}")
              (vm-meter :name "Memory" :value {${vm}.mem} :text "''${${vm}.mem_text}")
              (vm-meter :name "Disk (/home)" :value {${vm}.disk} :text "''${${vm}.disk_text}")
              (label :class "wg-detail" :halign "start" :text "Load ''${${vm}.load} · up ''${${vm}.uptime_text}")))
          (${vm}-firewall)
          (label :class "wg-detail" :halign "start" :wrap true
            :text "${info.footer}")))
    '';

  # A popup panel under the bar, opened by a bar button.
  menuWindow =
    {
      name,
      widget,
      width ? "360px",
      anchor ? "top right",
    }:
    ''
      (defwindow ${name}
        :monitor 0
        :stacking "overlay"
        :namespace "eww-menu"
        :geometry (geometry :x "8px" :y "34px" :width "${width}" :anchor "${anchor}")
        (${widget}))
    '';

  # The VPNs the network button can show an asterisk for, top to bottom:
  # kind is its CSS class (and colour), up a yuck condition, text its name in
  # the tooltip. The microVMs' come from their status (nike/status.py), and
  # only on hosts that run them.
  vpnStars = [
    {
      kind = "wireguard";
      up = "vpn.up.wireguard";
      text = "WireGuard";
    }
    {
      kind = "openvpn";
      up = "vpn.up.openvpn";
      text = "OpenVPN";
    }
    {
      kind = "forti";
      up = "vpn.up.forti";
      text = "openfortivpn";
    }
    {
      kind = "other";
      up = "vpn.up.other";
      text = "VPN";
    }
  ]
  ++ lib.optionals hasVms (
    map (vm: {
      kind = vm;
      up = "(${vm}.running && ${vm}.fresh && ${vm}.vpn.up)";
      text = "${lib.toUpper (lib.substring 0 1 vm)}${lib.substring 1 (-1) vm}'s VPN";
    }) vms
  );

  # The stack's labels, one per VPN, shown while it is up. At most four fit
  # the bar, so one shows only while fewer than four above it do; the
  # tooltip and the panel still name them all.
  maxStars = 4;
  vpnStarLabels = lib.concatStringsSep "\n                  " (
    lib.imap0 (
      i: s:
      let
        above = lib.concatMapStringsSep " + " (a: "(${a.up} ? 1 : 0)") (lib.take i vpnStars);
        fits = lib.optionalString (i >= maxStars) " && (${above}) < ${toString maxStars}";
      in
      ''(label :class "vpn-star ${s.kind}" :visible {${s.up}${fits}} :text "*")''
    ) vpnStars
  );

  # The tooltip's list of VPNs that are up, as a yuck string expression.
  vpnTooltip = lib.concatMapStrings (s: ''''${${s.up} ? " · ${s.text}" : ""}'') vpnStars;

  battery = script "eww-battery" ./eww/battery.py [ ];

  # Connected USB devices for the bar button and its panel, re-read whenever
  # udev sees one come or go.
  usb = pyScript "eww-usb" {
    runtimeInputs = [ pkgs.systemd ];
    replace."USB_IDS = \"/usr/share/hwdata/usb.ids\"" =
      ''USB_IDS = "${pkgs.hwdata}/share/hwdata/usb.ids"'';
  } ./eww/usb.py;
in
{
  # eww-display is also run by sway at startup (home/sway.nix), and
  # display-settings from fuzzel (the entry below).
  home.packages = [
    pkgs.eww
    display
    displaySettings
    pkgs.vdirsyncer
  ];

  xdg.desktopEntries.display-settings = {
    name = "Displays";
    comment = "Arrange displays, pick resolutions and the primary display";
    exec = "display-settings";
    icon = "preferences-desktop-display";
    categories = [ "Settings" ];
  };

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
        (defpoll cpuinfo :interval "5s" :initial "{\"model\":\"\",\"temp\":\"\",\"load\":\"\"}" "${cpu}/bin/eww-cpu")
        (defpoll gpu :interval "3s" :initial "{\"ok\":false,\"use\":0,\"temp\":0,\"vram\":0,\"vram_text\":\"\",\"text\":\"\"}"
          "${gpu}/bin/eww-gpu")
        (defpoll net :interval "2s"
          :initial "{\"auto\":true,\"default\":\"\",\"shown\":{\"name\":\"\",\"state\":\"down\",\"wireless\":false,\"down\":\"\",\"up\":\"\",\"address\":\"\"},\"ifaces\":[]}"
          "${net}/bin/eww-net")
        (deflisten displays :initial "{\"primary\":\"\",\"outputs\":[]}" "${display}/bin/eww-display watch")
        (defpoll vpn :interval "5s"
          :initial "{\"up\":{\"wireguard\":false,\"openvpn\":false,\"forti\":false,\"other\":false},\"active\":0,\"connections\":[]}"
          "${vpn}/bin/eww-vpn")
        (defpoll activity :interval "5s"
          :initial "{\"gamemode\":false,\"steam\":false,\"lmstudio\":{\"running\":false,\"serving\":false,\"first\":\"\",\"list\":\"\"}}"
          "${activity}/bin/eww-activity")
        ${lib.concatMapStrings vmPoll vms}
        (deflisten usb :initial "{\"count\":0,\"devices\":[]}" "${usb}/bin/eww-usb watch")
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
            (button :class "logo-button" :tooltip "Lock, log out or power off"
              :onclick "${menu} power-menu"
              (label :class "logo" :text ""))
            (workspaces)
            (box :class "mode" :visible {mode.name != "default"} :orientation "h" :space-evenly false :spacing 8
              (label :class "mode-name" :text "''${mode.name}")
              (label :class "mode-hint" :text "''${mode.hint}"))))

        (defwidget center []
          (label :class "title" :limit-width 80 :text title))

        (defwidget module [icon text ?class ?visible ?tooltip]
          (box :class "module ''${class}" :visible {visible ?: true} :tooltip {tooltip ?: ""}
            :orientation "h" :space-evenly false :spacing 6
            (label :class "icon" :text icon)
            ; unindent would strip the padding that keeps widths fixed.
            (label :unindent false :text text)))

        ; A percentage padded to "100%" so the bar doesn't shift (the font is monospace).
        (defwidget module-pct [icon value ?class ?tooltip]
          (module :class class :icon icon :tooltip tooltip
            :text "''${value < 10 ? "  " : (value < 100 ? " " : "")}''${value}%"))

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
${lib.optionalString hasVms ''
            ; The microVMs, always shown (vmBadge): grey while stopped,
            ; Nike orange and Zelus cyan while running.
            ${vmBadge "nike" ''
              {(!nike.running ? "Nike is stopped"
                : (!nike.fresh ? "Nike is starting"
                  : (nike.vpn.via_vpn ? "Nike: outbound through the VPN"
                    : (nike.vpn.up ? "Nike: VPN up, but outbound NOT through it" : "Nike: outbound NOT through a VPN"))))
                + " · firewall: ''${${modeText "nike" "label"}} (click for details)"}''}
            ${vmBadge "zelus" ''"Zelus is ''${zelus.running ? (zelus.fresh ? "running" : "starting") : "stopped"}''${zelus.running && zelus.fresh && zelus.vpn.up ? " · VPN up" : ""} · firewall: ''${${modeText "zelus" "label"}} (click for details)"''}
''}
            (button :class "module usb ''${usb.count > 0 ? "on" : ""}"
              :tooltip "''${usb.count} USB device''${usb.count == 1 ? "" : "s"}: click for the list"
              :onclick "${menu} usb-menu"
              (box :orientation "h" :space-evenly false :spacing 6
                (label :class "icon" :text "󰕓")
                (label :text "''${usb.count}")))
            (button :class "module display"
              :tooltip "''${arraylength(displays.outputs)} display''${arraylength(displays.outputs) == 1 ? "" : "s"}, primary ''${displays.primary}. Click for display settings"
              :onclick "${displaySettings}/bin/display-settings --toggle"
              (box :orientation "h" :space-evenly false :spacing 4
                (label :class "icon" :text "󰍹")
                (label :text "''${arraylength(displays.outputs)}")))
            (module-pct :class "cpu" :icon "" :value {round(EWW_CPU.avg, 0)}
              :tooltip "CPU ''${round(EWW_CPU.avg, 0)}%''${cpuinfo.temp} · ''${arraylength(EWW_CPU.cores)} threads · ''${round(EWW_CPU.cores[0].freq / 1000, 1)} GHz · load ''${cpuinfo.load}
    ''${cpuinfo.model}")
            (module-pct :class "mem" :icon "" :value {round(EWW_RAM.used_mem_perc, 0)}
              :tooltip "RAM ''${round(EWW_RAM.used_mem / 1073741824, 1)}/''${round(EWW_RAM.total_mem / 1073741824, 1)} GiB (''${round(EWW_RAM.used_mem_perc, 0)}%) · ''${round(EWW_RAM.available_mem / 1073741824, 1)} GiB available · swap ''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / 1073741824, 1)}/''${round(EWW_RAM.total_swap / 1073741824, 1)} GiB")
            (box :class "module gpu" :visible {gpu.ok} :orientation "h" :space-evenly false :spacing 6
              :tooltip "GPU ''${gpu.use}% · ''${gpu.temp}°C · VRAM ''${gpu.vram_text} (''${gpu.vram}%)"
              (label :class "icon" :text "󰢮")
              (label :unindent false :text "''${gpu.text}"))
            ; Network, with an asterisk per VPN that is up beside the icon,
            ; stacked and coloured by VPN (vpnStars).
            (button :class "module net ''${net.shown.state == "up" ? "" : "down"}"
              :tooltip "''${net.shown.name} ''${net.shown.address}${vpnTooltip}: click for interfaces and VPNs"
              :onclick "${menu} net-menu"
              (box :orientation "h" :space-evenly false :spacing 2
                (label :class "icon" :text {net.shown.wireless ? "󰖩" : "󰈀"})
                ; A space between the icon and the asterisks.
                (label :unindent false :text " ")
                (box :class "vpn-stars" :orientation "v" :valign "center" :space-evenly false
                  ${vpnStarLabels})
                (label :class "net-text" :text "''${net.shown.name} ↓''${net.shown.down} ↑''${net.shown.up}")))
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
                (label :unindent false :text "''${volume.text}")))
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

        ; Session: opened by the logo at the top left.
        (defwidget power-action [icon name onclick]
          (button :class "wg-toggle power-action" :onclick "${eww} close power-menu; ''${onclick}"
            (box :orientation "h" :space-evenly false :spacing 10
              (label :class "icon" :text icon)
              (label :halign "start" :text name))))

        (defwidget power-panel []
          (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
            (box :orientation "h" :space-evenly false
              (label :class "wg-title" :hexpand true :halign "start" :text "Session")
              (button :class "wg-close" :onclick "${eww} close power-menu" "✕"))
            (power-action :icon "󰌾" :name "Lock" :onclick "${pkgs.swaylock}/bin/swaylock -f")
            (power-action :icon "󰍃" :name "Log out" :onclick "${pkgs.sway}/bin/swaymsg exit")
            (power-action :icon "󰐥" :name "Power off" :onclick "${pkgs.systemd}/bin/systemctl poweroff")))

        ; Panels opened by the Steam and LM Studio buttons, laid out like the
        ; network panel.
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

        ; A meter in a VM's panel (vmPanel).
        (defwidget vm-meter [name value text]
          (box :orientation "v" :space-evenly false :spacing 2
            (box :orientation "h" :space-evenly false
              (label :class "wg-detail" :hexpand true :halign "start" :text name)
              (label :class "wg-detail" :text text))
            (progress :class "vm-meter ''${value >= 90 ? "high" : ""}" :orientation "h" :value value)))

        ${lib.concatMapStrings vmPanel vms}

        ; USB: every connected device, hubs included, in port order.
        (defwidget usb-panel []
          (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
            (box :orientation "h" :space-evenly false
              (label :class "wg-title" :hexpand true :halign "start" :text "USB")
              (button :class "wg-close" :onclick "${eww} close usb-menu" "✕"))
            (label :class "wg-detail" :visible {arraylength(usb.devices) == 0} :halign "start"
              :text "No USB devices connected")
            (for d in {usb.devices}
              (box :class "wg-tunnel usb-device ''${d.kind == "Hub" ? "hub" : ""}" :orientation "h" :space-evenly false :spacing 12
                (label :class "usb-icon" :valign "start" :text "''${d.icon}")
                (box :orientation "v" :space-evenly false :hexpand true :spacing 2
                  (label :class "wg-name" :halign "start" :limit-width 34 :text "''${d.name}")
                  (label :class "wg-detail" :visible {d.vendor != ""} :halign "start" :limit-width 34 :text "''${d.vendor}")
                  (label :class "wg-detail" :halign "start"
                    :text "''${d.kind}''${d.speed != "" ? " · ''${d.speed}" : ""}")
                  (label :class "wg-detail" :halign "start" :text "ID ''${d.id} · port ''${d.port}"))))))

        ; Network: the VPNs with Connect/Disconnect, then every interface's
        ; rates and which one the bar shows.
        (defwidget net-panel []
          (box :class "wg-panel" :orientation "v" :space-evenly false :spacing 10
            (box :orientation "h" :space-evenly false
              (label :class "wg-title" :hexpand true :halign "start" :text "Network")
              (button :class "wg-close" :onclick "${eww} close net-menu" "✕"))
            (label :class "wg-name" :halign "start" :text "VPN")
            (label :class "wg-detail" :visible {arraylength(vpn.connections) == 0} :halign "start" :wrap true
              :text "No VPNs yet. docs/vpn.md shows how to add WireGuard, OpenVPN and openfortivpn ones.")
            (for t in {vpn.connections}
              (box :class "wg-tunnel ''${t.active ? "up" : "down"}" :orientation "h" :space-evenly false :spacing 16
                (box :orientation "v" :space-evenly false :hexpand true :spacing 2
                  (box :orientation "h" :space-evenly false :spacing 6
                    (label :class "vpn-star ''${t.kind}" :text "''${t.active ? "*" : " "}")
                    (label :class "wg-name" :halign "start" :limit-width 30 :text "''${t.name}"))
                  (label :class "wg-detail" :halign "start"
                    :text "''${t.label}''${t.device != "" ? " · ''${t.device}" : ""}''${t.address != "" ? " · ''${t.address}" : ""}")
                  (label :class "wg-detail" :visible {t.active && (t.endpoint != "" || t.handshake != "")} :halign "start"
                    :text "''${t.endpoint != "" ? t.endpoint : "no peer endpoint"}''${t.handshake != "" ? " · handshake ''${t.handshake}" : ""}")
                  (label :class "wg-detail" :visible {t.active && t.rx != ""} :halign "start" :text "↓ ''${t.rx}  ↑ ''${t.tx}"))
                (button :class "wg-toggle" :valign "center" :visible {t.managed}
                  :onclick "${vpn}/bin/eww-vpn toggle ''${t.kind} \"''${t.name}\" &"
                  "''${t.active ? "Disconnect" : "Connect"}")))
            (label :class "wg-name" :halign "start" :text "Interfaces")
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

        ${menuWindow { name = "power-menu"; widget = "power-panel"; width = "220px"; anchor = "top left"; }}

        ${menuWindow { name = "net-menu"; widget = "net-panel"; }}

        ${menuWindow { name = "vol-menu"; widget = "vol-panel"; }}

        ${menuWindow { name = "cal-menu"; widget = "cal-panel"; }}

        ${menuWindow { name = "usb-menu"; widget = "usb-panel"; width = "440px"; }}

        ${lib.concatMapStrings (vm: menuWindow { name = "${vm}-menu"; widget = "${vm}-panel"; }) vms}

        ${menuWindow { name = "steam-menu"; widget = "steam-menu"; }}

        ${menuWindow { name = "lms-menu"; widget = "lms-menu"; }}

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
    .logo-button:hover .logo { color: $pink; }

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
      &.steam, &.lmstudio, &.vm { &:hover { background-color: $surface; } }
      &.lmstudio .icon { color: $muted; }
      &.lmstudio.serving .icon { color: $pink; }
      &.vm .icon { color: $muted; }
      &.nike.running .icon { color: $orange; }
      &.zelus.running .icon { color: $cyan; }
      // Firewall modes: open is the plain one, lockdown red, the
      // restricted ones (OSCP, Hack The Box, local inference) purple.
      .vm-mode { color: $purple; }
      .vm-mode.mode-permissive { color: $muted; }
      .vm-mode.mode-lockdown { color: $red; }
      &.caffeine { color: $muted; &:hover { background-color: $surface; } }
      &.caffeine.on { color: $orange; }
      &.gpu .icon { color: $red; }
      &.net .icon { color: $blue; }
      &.net.down { color: $muted; }
      // One small asterisk per VPN that is up, stacked in a column that
      // always keeps its width, so the bar doesn't shift.
      .vpn-stars { min-width: 6px; }
      .vpn-stars .vpn-star {
        font-size: 8pt;
        margin: -6px 0;
      }
      &.vol.muted { color: $muted; .icon { color: $muted; } }
      &.display .icon { color: $pink; }
      &.usb { color: $muted; }
      &.usb.on { color: $fg; .icon { color: $yellow; } }
      &.display, &.usb, &.net, &.vol, &.clock { &:hover { background-color: $surface; } }
      .tz { color: $muted; }
    }

    // Each VPN's asterisk colour, on the bar and in the network panel.
    .vpn-star {
      &.wireguard { color: $green; }
      &.openvpn { color: $yellow; }
      &.forti { color: $purple; }
      &.other { color: $blue; }
      &.nike { color: $orange; }
      &.zelus { color: $cyan; }
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
      .wg-tunnel.warn .wg-name { color: $orange; }
      .wg-title.nike { color: $orange; }
      .wg-title.zelus { color: $cyan; }
      .vm-power {
        padding: 0 8px;
        margin-right: 6px;
        background-color: $surface;
        &.start { color: $green; &:hover { color: $bg; background-color: $green; } }
        &.stop { color: $red; &:hover { color: $bg; background-color: $red; } }
        &.busy { color: $muted; }
      }
      .vm-fw-current { padding: 0; &:hover .wg-name { color: $fg; } }
      .vm-fw-mode { color: $purple; }
      .vm-fw-mode.mode-permissive { color: $fg; }
      .vm-fw-mode.mode-lockdown { color: $red; }
      .vm-fw-item {
        padding: 4px 8px;
        &:hover { background-color: $surface; }
        &.active { background-color: $surface; .vm-fw-label { color: $cyan; } }
      }
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

      .vm-meter {
        trough { background-color: $surface; min-height: 6px; min-width: 300px; }
        progress { background-color: $cyan; min-height: 6px; }
        &.high progress { background-color: $orange; }
      }

      .power-action { padding: 8px 12px; }

      .usb-device .wg-name { color: $fg; }
      .usb-device.hub .wg-name { color: $muted; }
      .usb-icon { color: $yellow; font-size: ${toString (p.font.size + 4)}pt; min-width: 24px; }
      .usb-device.hub .usb-icon { color: $muted; }

    }
  '';
}
