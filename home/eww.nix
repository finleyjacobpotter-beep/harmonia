# Elkowar's Wacky Widgets — the top bar and the dash (workspace 10) for sway.
# The layout is home/eww/eww.yuck and the styles home/eww/eww.scss; the
# scripts behind the widgets are home/eww/*.py, packaged together as
# harmonia-bar. This file fills in what depends on the host: store paths, the
# palette, the wallpaper, the key hints, and the microVMs' widgets
# (modules/nixos/microvms.nix).
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
  pyApp = import ../lib/python-app.nix { inherit pkgs lib; };

  # The dash's own keys, in sway's dash mode (home/sway.nix, home/eww/dash.py).
  dashHint = "h/j/k/l move · e expand · Esc collapse · c m f g n p v y u a d s t open a tile · Super+Tab back";

  # The dash shows the wallpaper beside its tiles; sway's background is a
  # solid colour (home/sway.nix).
  wallpaper = ../assets/wallpaper.png;

  # Reminders of the main keys, under the dash: sway's (home/sway.nix),
  # tmux's (home/tmux.nix) and neovim's (home/neovim.nix). docs/keyboard.md
  # has them all.
  keyHintColumns = [
    {
      title = "sway  Super+…";
      keys = [
        [
          "Return / d"
          "terminal / launcher"
        ]
        [
          "q"
          "close window"
        ]
        [
          "h j k l"
          "focus (Shift: move)"
        ]
        [
          "1…9"
          "workspace (Shift: send)"
        ]
        [
          "Ctrl+h / l"
          "other display"
        ]
        [
          "s / v"
          "split below / beside"
        ]
        [
          "t / e"
          "tabbed / toggle split"
        ]
        [
          "f"
          "fullscreen"
        ]
        [
          "Shift+space"
          "float"
        ]
        [
          "r o m"
          "resize · open · media"
        ]
        [
          "Shift+e"
          "lock, exit, power"
        ]
      ];
    }
    {
      title = "tmux  Ctrl+Space, then";
      keys = [
        [
          "s / v"
          "split below / beside"
        ]
        [
          "h j k l"
          "pane (H J K L resize)"
        ]
        [
          "z"
          "zoom pane"
        ]
        [
          "c / n / p"
          "new / next / prev window"
        ]
        [
          "q / Q"
          "kill pane / window"
        ]
        [
          "w / S"
          "pick window / session"
        ]
        [
          "Esc"
          "copy: v select, y yank"
        ]
        [
          "P"
          "paste"
        ]
        [
          "d"
          "detach"
        ]
      ];
    }
    {
      title = "neovim  Space = leader";
      keys = [
        [
          "Space ff / fg"
          "find files / grep"
        ]
        [
          "Space fb"
          "buffers"
        ]
        [
          "Space e"
          "file explorer"
        ]
        [
          "Space s / v"
          "split below / beside"
        ]
        [
          "Ctrl+w h j k l"
          "between windows"
        ]
        [
          "Space q"
          "close window"
        ]
        [
          "[b / ]b"
          "prev / next buffer"
        ]
        [
          "Space j"
          "JSON / YAML"
        ]
        [
          "Space fk"
          "every key"
        ]
      ];
    }
  ];
  keyHints = lib.concatMapStrings (c: ''
    (box :class "hint-col" :orientation "v" :space-evenly false :spacing 1
      (label :class "hint-title" :halign "start" :text "${c.title}")
      ${
        lib.concatMapStrings (k: ''
          (box :orientation "h" :space-evenly false :spacing 6
            (label :class "hint-key" :text "${lib.elemAt k 0}")
            (label :class "hint-what" :halign "start" :limit-width 24 :text "${lib.elemAt k 1}"))
        '') c.keys
      })
  '') keyHintColumns;

  # Key hints for sway's modes (home/sway.nix), shown while a mode is active.
  modeHints = {
    dash = dashHint;
    resize = "h/j/k/l resize · Shift = ×5 · Esc done";
    open = lib.concatMapStringsSep " · " (k: "${k.hint} ${k.name}") (
      import ./open-mode.nix { inherit lib osConfig; }
    );
    media = "j/k volume · m mute · M mic · h/l prev/next · p play · J/K brightness";
    system = "l lock · e exit · s suspend · r reboot · P poweroff";
  };

  # What the scripts read through home/eww/common.py.
  # The flake's direct inputs and when each pinned commit was made, for the
  # system tile (home/eww/system.py), read from flake.lock at build time.
  flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
  pins = lib.mapAttrsToList (input: node: {
    name = input;
    # An input that follows another one names a path instead of a node.
    modified = if builtins.isString node then flakeLock.nodes.${node}.locked.lastModified or 0 else 0;
  }) flakeLock.nodes.${flakeLock.root}.inputs;

  barConfig = pkgs.writeText "harmonia-bar.json" (
    builtins.toJSON {
      hints = modeHints;
      inherit pins;
      # The calendars' dots (cal.py), one colour per calendar in turn.
      calColors = with p; [
        pink
        cyan
        yellow
        purple
        green
        orange
        blue
      ];
      usbIds = "${pkgs.hwdata}/share/hwdata/usb.ids";
      # The GPUs' names in the GPU panel (gpu.py).
      pciIds = "${pkgs.hwdata}/share/hwdata/pci.ids";
      # The exact path sudo allows (modules/nixos/vpn.nix).
      wg = "${pkgs.wireguard-tools}/bin/wg";
      # The same for root's containers (modules/nixos/podman.nix).
      podman = "${osConfig.virtualisation.podman.package}/bin/podman";
    }
  );

  # Every bar script, under the command name the bar runs it by. eww-dash
  # is also run by sway at startup and by the dash's keys (home/sway.nix),
  # and from fuzzel (the Displays entry below).
  bar = pyApp {
    name = "harmonia-bar";
    src = ./eww;
    commands = {
      eww-sway-workspaces = "workspaces";
      eww-sway-title = "title";
      eww-sway-mode = "mode";
      eww-volume = "volume";
      eww-cpu = "cpu";
      eww-mem = "mem";
      eww-disk = "disk";
      eww-notify = "notify";
      eww-secrets = "secrets";
      eww-mic = "mic";
      eww-bt = "bt";
      eww-system = "system";
      eww-dash = "dash";
      eww-gpu = "gpu";
      eww-net = "net";
      eww-cal = "cal";
      eww-clock = "clock";
      eww-display = "display";
      eww-display-edit = "display-edit";
      eww-caffeine = "caffeine";
      eww-vpn = "vpn";
      eww-locks = "locks";
      eww-activity = "activity";
      eww-steam-close = "steam-close";
      eww-microvm = "microvm";
      eww-battery = "battery";
      eww-usb = "usb";
      eww-pods = "pods";
    };
    libraries = with pkgs.python3Packages; [
      icalendar
      recurring-ical-events
    ];
    runtimeInputs =
      with pkgs;
      [
        sway
        eww
        wireplumber
        iproute2
        systemd
        networkmanager
        flatpak
        gamemode
        procps
        # The sound tile's microphone, cameras and Bluetooth (mic.py, bt.py).
        pipewire
        bluez
        # The notifications tile (notify.py).
        mako
        # The secrets tile (secrets.py, home/secrets.nix).
        openssh
        gnupg
        bitwarden-cli
        # The system tile's garbage collection (system.py).
        nix
      ]
      # GPU load, temperature and VRAM (modules/nixos/fans.nix). ROCm is
      # x86_64 only; elsewhere (e.g. an aarch64 Dionysus VM) the widget just
      # reports no GPU and hides itself.
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [ rocmPackages.rocm-smi ];
    wrapperArgs = [
      "--set"
      "HARMONIA_BAR_CONFIG"
      "${barConfig}"
    ];
  };
  bin = "${bar}/bin";
  eww = "${pkgs.eww}/bin/eww";

  # The microVMs this host runs (modules/nixos/microvms.nix). A host without
  # them (e.g. Dionysus) shows no VM widgets.
  vms = osConfig.harmonia.microvms or { };
  vmNames = lib.attrNames vms;

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

  # A VM's line in the dash's microVM tile: the same server icon for each,
  # in the VM's own colour while it runs, its name and the firewall mode.
  # Its VPN shows as an asterisk on the network tile.
  vmBadge =
    vm:
    let
      v = vms.${vm};
      firewall = "firewall: \${${modeText vm "label"}}";
      # Whether it runs and, with panel.vpn (Nike), where its traffic leaves.
      tooltip =
        if v.panel.vpn then
          ''
            {(!${vm}.running ? "${v.title} is stopped"
              : (!${vm}.fresh ? "${v.title} is starting"
                : (${vm}.vpn.via_vpn ? "${v.title}: outbound through the VPN"
                  : (${vm}.vpn.up ? "${v.title}: VPN up, but outbound NOT through it" : "${v.title}: outbound NOT through a VPN"))))
              + " · ${firewall}"}''
        else
          ''"${v.title} is ''${${vm}.running ? (${vm}.fresh ? "running" : "starting") : "stopped"}''${${vm}.running && ${vm}.fresh && ${vm}.vpn.up ? " · VPN up" : ""} · ${firewall}"'';
    in
    ''
      (box :class "module vm ${vm} ''${${vm}.running ? "running" : "stopped"}" :tooltip ${tooltip}
        :orientation "h" :space-evenly false :spacing 6
        (label :class "icon" :text "󰒋")
        (label :text "${v.title}")
        (label :class "vm-mode mode-''${${vm}.mode}" :xalign 0 :text "''${${shortText vm}}"))
    '';

  # A VM panel's start/stop button: Start while it is stopped, Stop while it
  # runs, and Starting…/Stopping… (disabled) until systemctl returns.
  powerButton = vm: ''
    (defvar ${vm}_busy "")
    (defwidget ${vm}-power []
      (button :class "vm-power ''${${vm}_busy != "" ? "busy" : (${vm}.running ? "stop" : "start")}"
        :active {${vm}_busy == ""}
        :tooltip "''${${vm}.running ? "Stop" : "Start"} microvm@${vm}"
        :onclick "${bin}/eww-microvm ${vm} ''${${vm}.running ? "stop" : "start"} &"
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
                  :onclick "${bin}/eww-microvm ${vm} set ${m.name}"
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
      "${bin}/eww-microvm ${vm}")
  '';

  # Nike's panel shows where its traffic leaves (through the VPN or not),
  # from what nike/status.py reports; so does any VM with panel.vpn.
  vpnBlock = vm: ''
    (box :class "wg-tunnel ''${${vm}.vpn.via_vpn ? "up" : "warn"}" :orientation "v" :space-evenly false :spacing 6
      (box :orientation "h" :space-evenly false
        (label :class "wg-name" :hexpand true :halign "start"
          :text "''${${vm}.vpn.via_vpn ? "●" : "○"} VPN outbound")
        (label :class "wg-detail" :text "via ''${${vm}.vpn.outbound}"))
      (label :class "wg-detail" :halign "start" :wrap true :text "''${${vm}.vpn.summary}")
      (label :class "wg-detail" :visible {${vm}.vpn.up} :halign "start"
        :text "Tunnel down ''${${vm}.vpn.rx_text} · up ''${${vm}.vpn.tx_text}"))
  '';

  # A VM's part of the open microVM tile: start/stop, its CPU, memory and
  # disk as its status service reports them from inside the VM, the
  # firewall dropdown and how to reach it.
  vmPanel =
    vm:
    let
      info = vms.${vm};
    in
    ''
      ${powerButton vm}
      ${firewallDropdown vm}
      (defwidget ${vm}-panel []
        (box :orientation "v" :space-evenly false :spacing 10
          (box :orientation "h" :space-evenly false
            (label :class "wg-title ${vm}" :hexpand true :halign "start" :text "${info.title}")
            (${vm}-power))
          (label :class "wg-detail" :visible {!${vm}.running} :halign "start" :wrap true
            :text "${info.title} is stopped.")
          (label :class "wg-detail" :visible {${vm}.running && !${vm}.fresh} :halign "start" :wrap true
            :text "${info.title} is starting: no status from it yet.")
          (box :visible {${vm}.running && ${vm}.fresh} :orientation "v" :space-evenly false :spacing 10
            ${lib.optionalString info.panel.vpn (vpnBlock vm)}
            (box :class "wg-tunnel" :orientation "v" :space-evenly false :spacing 6
              (label :class "wg-name" :halign "start" :text "System")
              (meter :name "CPU" :value {${vm}.cpu} :text "''${${vm}.cpu_text}")
              (meter :name "Memory" :value {${vm}.mem} :text "''${${vm}.mem_text}")
              (meter :name "Disk (/home)" :value {${vm}.disk} :text "''${${vm}.disk_text}")
              (label :class "wg-detail" :halign "start" :text "Load ''${${vm}.load} · up ''${${vm}.uptime_text}")))
          (${vm}-firewall)
          (label :class "wg-detail" :halign "start" :wrap true
            :text "${info.panel.footer}")))
    '';

  # The VPNs the network tile can show an asterisk for, top to bottom:
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
  ++ map (vm: {
    kind = vm;
    up = "(${vm}.running && ${vm}.fresh && ${vm}.vpn.up)";
    text = "${vms.${vm}.title}'s VPN";
  }) vmNames;

  # The stack's labels, one per VPN, shown while it is up. At most four fit
  # beside the icon, so one shows only while fewer than four above it do;
  # the tile's VPN line and its details still name them all.
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

  # The list of VPNs that are up, as a yuck string expression.
  vpnTooltip = lib.concatMapStrings (s: ''''${${s.up} ? " · ${s.text}" : ""}'') vpnStars;

  # Fill in the @name@ placeholders of a file in home/eww.
  fill =
    vars: file:
    builtins.replaceStrings (map (n: "@${n}@") (lib.attrNames vars)) (lib.attrValues vars) (
      builtins.readFile file
    );
in
{
  home.packages = [
    pkgs.eww
    bar
    pkgs.vdirsyncer
  ];

  # The display settings are on the dash's devices tile (home/eww/display-edit.py).
  xdg.desktopEntries.display-settings = {
    name = "Displays";
    comment = "Arrange displays, pick resolutions and the primary display";
    exec = "eww-dash show devices";
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
      # The Bitwarden session from `bw-unlock` (home/secrets.nix), for
      # password.fetch; without it the fetch fails and the sync is skipped.
      EnvironmentFile = "-%t/bw-session";
      ExecStart = [
        "-${pkgs.vdirsyncer}/bin/vdirsyncer metasync"
        "${pkgs.vdirsyncer}/bin/vdirsyncer sync"
      ];
      ExecStartPost = "-${bin}/eww-cal refresh";
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

  xdg.configFile."eww/eww.yuck".text = fill {
    inherit
      bin
      eww
      vpnTooltip
      dashHint
      keyHints
      ;
    vpnStars = vpnStarLabels;
    swaymsg = "${pkgs.sway}/bin/swaymsg";
    swaylock = "${pkgs.swaylock}/bin/swaylock";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    vmPolls = lib.concatMapStrings vmPoll vmNames;
    vmBadges = lib.concatMapStrings vmBadge vmNames;
    vmPanels = lib.concatMapStrings vmPanel vmNames;
    vmBodies = lib.concatMapStrings (vm: "(${vm}-panel)\n") vmNames;
    vmTotal = toString (lib.length vmNames);
    # How many run, as a yuck expression.
    vmRunning =
      if vmNames == [ ] then
        "0"
      else
        lib.concatMapStringsSep " + " (vm: "(${vm}.running ? 1 : 0)") vmNames;
  } ./eww/eww.yuck;

  xdg.configFile."eww/eww.scss".text = ''
    $bg: ${p.bgDark};
    // The wallpaper's border colour (assets/wallpaper.png, docs/theme.md),
    // which sway's background also uses (home/sway.nix).
    $wall-bg: ${p.bg};
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
    $font: "${p.font.name}";
    $font-size: ${toString p.font.size}pt;

    ${builtins.readFile ./eww/eww.scss}
    .dash-wallpaper { background-image: url("${wallpaper}"); }
    ${lib.concatMapStrings (vm: ''
      // ${vms.${vm}.title}: its line on the dash while running, its VPN asterisk and its panel's title.
      .module.${vm}.running .icon, .vpn-star.${vm}, .dash .wg-title.${vm} { color: ${vms.${vm}.vm.palette.primary}; }
    '') vmNames}
  '';
}
