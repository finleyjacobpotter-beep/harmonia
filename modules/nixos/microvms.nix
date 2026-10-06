# The microVMs (microvm.nix), each declared once:
#
#   harmonia.microvms.nike = {
#     index = 0;                 # its network: 10.20.0.1 (host) <-> 10.20.0.2
#     user = "k";
#     guest = ../../nike;        # its NixOS config
#     key = "v";                 # Super+o, then v: `ssh nike` in a terminal
#     colors.primary = "orange"; # its shell, tmux, ranger, neovim and bar badge
#     firewall.modes = [ ... ];  # between Lockdown and Permissive
#   };
#
# Everything else comes from that: the tap, MAC and addresses, ~/<name>-share
# and the status folder, NAT, `ssh <name>`, the firewall modes
# (modules/nixos/vm-firewall.nix), the bar's badge and panel (home/eww.nix)
# and the open mode's key (home/open-mode.nix). The guest gets all of it as
# the `vm` module argument (lib/microvm-guest.nix).
#
# A VM sits on its own tap with a /32 route each way, so nothing else on your
# LAN can reach it. It doesn't start at boot: sudo systemctl start microvm@NAME.
{
  config,
  lib,
  inputs,
  palette,
  keys,
  username,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.harmonia.microvms;

  vmType = types.submodule (
    { name, config, ... }:
    let
      hex = lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString config.index));
      c = config.colors;
    in
    {
      options = {
        index = mkOption {
          type = types.ints.between 0 255;
          description = "Picks the VM's network, 10.20.<index>.0, and MAC.";
        };
        user = mkOption { type = types.str; };
        guest = mkOption {
          type = types.path;
          description = "The guest's NixOS config.";
        };
        title = mkOption {
          type = types.str;
          default = lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
        };
        key = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The open mode's key for `ssh <name>` in a terminal.";
        };
        colors = {
          # Palette slot names (theme/miami-wind.nix): the primary colour
          # replaces the host's pink, the secondary its cyan.
          primary = mkOption { type = types.str; };
          secondary = mkOption {
            type = types.str;
            default = "cyan";
          };
          # The primary @ 25% over bg, for neovim's selection.
          selection = mkOption { type = types.str; };
          # The ANSI colour nearest the primary, for ranger.
          ansi = mkOption { type = types.str; };
        };
        firewall = {
          default = mkOption {
            type = types.str;
            default = "permissive";
          };
          # The VM's own modes, listed between Lockdown and Permissive.
          modes = mkOption {
            type = types.listOf types.attrs;
            default = [ ];
          };
          # TCP ports on the host's end of the tap that the VM may reach in
          # every mode, Lockdown included, and what they are (for Lockdown's
          # description).
          hostPorts = mkOption {
            type = types.listOf types.port;
            default = [ ];
          };
          hostPortsLabel = mkOption {
            type = types.str;
            default = "";
          };
        };
        # The bar's panel: whether to show the VM's VPN (nike/status.py
        # reports it), and the line saying how to reach the VM.
        panel = {
          vpn = mkOption {
            type = types.bool;
            default = false;
          };
          footer = mkOption {
            type = types.str;
            default = "ssh ${name} · ~/${name}-share is ~/share on ${config.title}";
          };
        };
        sshOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "More lines for its ssh Host entry.";
        };
        vmArgs = mkOption {
          type = types.attrs;
          default = { };
          description = "Added to microvm.vms.<name>.";
        };
        extra = mkOption {
          type = types.attrs;
          default = { };
          description = "More values for the guest's `vm` argument.";
        };

        # Derived; what the guest sees as `vm`.
        vm = mkOption {
          type = types.attrs;
          readOnly = true;
          default = {
            inherit name keys;
            inherit (config) user title;
            tap = "vm-${name}";
            mac = "02:00:00:00:${hex}:01";
            hostAddress = "10.20.${toString config.index}.1";
            address = "10.20.${toString config.index}.2";
            shareDir = "/home/${username}/${name}-share";
            statusDir = "/var/lib/${name}/status";
            nameservers = [
              "9.9.9.9"
              "149.112.112.112"
            ];
            palette =
              let
                primary = palette.${c.primary};
                secondary = palette.${c.secondary};
              in
              palette
              // {
                inherit primary secondary;
                primaryBright = palette."${c.primary}Bright";
                secondaryBright = palette."${c.secondary}Bright";
                accent = primary;
                accentAlt = secondary;
                selection = "${primary}40";
                selectionSolid = c.selection;
                accentAnsi = c.ansi;
              };
          }
          // config.extra;
        };
      };
    }
  );
in
{
  imports = [ ./vm-firewall.nix ];

  options.harmonia.microvms = mkOption {
    type = types.attrsOf vmType;
    default = { };
  };

  config = lib.mkIf (cfg != { }) {
    microvm.vms = lib.mapAttrs (
      _: v:
      {
        autostart = false;
        specialArgs = {
          inherit inputs;
          inherit (v) vm;
        };
        config = v.guest;
      }
      // v.vmArgs
    ) cfg;

    systemd.tmpfiles.rules = lib.concatMap (v: [
      "d ${v.vm.shareDir} 0755 ${username} users -"
      "d /var/lib/${v.vm.name} 0755 root root -"
      "d ${v.vm.statusDir} 0755 root root -"
    ]) (lib.attrValues cfg);

    # The host's end of each tap: an address and a route to the VM. networkd
    # handles only these interfaces; NetworkManager keeps everything else.
    systemd.network = {
      enable = true;
      wait-online.enable = false;
      networks = lib.mapAttrs' (
        name: v:
        lib.nameValuePair "30-${name}" {
          matchConfig.Name = v.vm.tap;
          address = [ "${v.vm.hostAddress}/32" ];
          routes = [ { Destination = "${v.vm.address}/32"; } ];
          linkConfig.RequiredForOnline = "no";
        }
      ) cfg;
    };
    networking.networkmanager.unmanaged = lib.mapAttrsToList (_: v: "interface-name:${v.vm.tap}") cfg;

    # Out to the internet through whatever the host uses (Wi-Fi, ethernet or
    # a VPN tunnel).
    networking.nat = {
      enable = true;
      internalIPs = lib.mapAttrsToList (_: v: "${v.vm.address}/32") cfg;
    };

    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: v:
        ''
          Host ${name}
            HostName ${v.vm.address}
            User ${v.user}
        ''
        + lib.concatMapStrings (option: "  ${option}\n") v.sshOptions
      ) cfg
    );

    # Every VM has Lockdown and Permissive; its own modes go between them.
    # Switched from the bar's panel or `sudo vm-firewall set NAME MODE`.
    harmonia.vmFirewall = lib.mapAttrs (
      _: v:
      let
        inherit (v.firewall) hostPorts hostPortsLabel;
        hostRules =
          lib.optional (hostPorts != [ ])
            "tcp dport { ${lib.concatMapStringsSep ", " toString hostPorts} } accept";
      in
      {
        inherit (v.vm) tap;
        inherit (v.firewall) default;
        modes = map (m: m // { input = hostRules ++ (m.input or [ ]); }) (
          [
            {
              name = "lockdown";
              label = "Lockdown";
              short = "lock";
              description =
                if hostPorts == [ ] then
                  "Nothing out; only ssh from the host"
                else
                  "Nothing out but ${hostPortsLabel}; ssh from the host";
              forwardPolicy = "drop";
              inputPolicy = "drop";
            }
          ]
          ++ v.firewall.modes
          ++ [
            {
              name = "permissive";
              label = "Permissive";
              short = "open";
              description = "Anything out to the internet and the host";
              forwardPolicy = "accept";
              inputPolicy = "accept";
            }
          ]
        );
      }
    ) cfg;
  };
}
