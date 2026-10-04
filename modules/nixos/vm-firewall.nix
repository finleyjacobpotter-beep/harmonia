# Firewall modes for the microVMs (Nike, Zelus), enforced on the host so
# nothing inside a VM (root included) can lift them. Each VM declares its
# modes in its own module (modules/nixos/nike.nix, zelus.nix); this turns
# every mode into an nftables table, prebuilt in /etc/vm-firewall, and adds
# the `vm-firewall` command that switches between them:
#
#   vm-firewall                    every VM's mode
#   sudo vm-firewall set nike oscp switch Nike to OSCP mode
#
# The bar's VM panels (home/eww.nix) call it without a password (sudo rule
# below). The mode survives a reboot: it is kept in /var/lib/vm-firewall and
# applied again at boot and whenever the host firewall restarts.
#
# A mode only filters what a VM starts: traffic it forwards out through the
# host (the internet, through the host's NAT) and connections to the host
# itself. `ssh nike` / `ssh zelus` are started by the host, so they (and the
# Blender and Godot forwards they carry) work in every mode.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.harmonia.vmFirewall;

  pyScript = import ../../lib/python-script.nix { inherit pkgs lib; };

  modeType = types.submodule {
    options = {
      name = mkOption { type = types.strMatching "[a-z0-9-]+"; };
      label = mkOption { type = types.str; };
      # A word for the bar badge.
      short = mkOption { type = types.str; };
      description = mkOption { type = types.str; };
      # nft rules (without the interface match) for what the VM sends out
      # to the internet; anything they don't accept gets `forwardPolicy`.
      forward = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      forwardPolicy = mkOption {
        type = types.enum [
          "accept"
          "drop"
        ];
      };
      # The same for new connections from the VM to the host.
      input = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      inputPolicy = mkOption {
        type = types.enum [
          "accept"
          "drop"
        ];
      };
    };
  };

  # One table per VM. Loading a mode's file replaces the whole table in one
  # transaction, so there is never a moment with half the rules.
  table = vm: tap: mode: ''
    table inet vm-firewall-${vm}
    delete table inet vm-firewall-${vm}
    table inet vm-firewall-${vm} {
      chain forward {
        type filter hook forward priority filter - 5; policy accept;
        ${
          lib.concatMapStrings (r: ''iifname "${tap}" ${r}'' + "\n    ") mode.forward
        }iifname "${tap}" ${mode.forwardPolicy}
      }
      chain input {
        type filter hook input priority filter - 5; policy accept;
        iifname "${tap}" ct state established,related accept
        ${
          lib.concatMapStrings (r: ''iifname "${tap}" ${r}'' + "\n    ") mode.input
        }iifname "${tap}" ${mode.inputPolicy}
      }
    }
  '';

  # What the command and the bar read: every VM's modes, in order.
  summary = lib.mapAttrs (_: vm: {
    inherit (vm) default;
    modes = map (m: {
      inherit (m)
        name
        label
        short
        description
        ;
    }) vm.modes;
  }) cfg;

  vmFirewall = pyScript "vm-firewall" {
    runtimeInputs = [ pkgs.nftables ];
  } ./vm-firewall/vm-firewall.py;
in
{
  options.harmonia.vmFirewall = mkOption {
    default = { };
    description = "Firewall modes for each microVM, by VM name.";
    type = types.attrsOf (
      types.submodule {
        options = {
          tap = mkOption { type = types.str; };
          default = mkOption { type = types.str; };
          modes = mkOption { type = types.listOf modeType; };
        };
      }
    );
  };

  config = lib.mkIf (cfg != { }) {
    assertions = lib.mapAttrsToList (vm: v: {
      assertion = lib.any (m: m.name == v.default) v.modes;
      message = "harmonia.vmFirewall.${vm}.default must be one of its modes";
    }) cfg;

    environment.etc = {
      "vm-firewall/config.json".text = builtins.toJSON summary;
    }
    // lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList (
          vm: v:
          map (mode: {
            name = "vm-firewall/${vm}/${mode.name}.nft";
            value.text = table vm v.tap mode;
          }) v.modes
        ) cfg
      )
    );

    environment.systemPackages = [ vmFirewall ];

    systemd.tmpfiles.rules = [ "d /var/lib/vm-firewall 0755 root root -" ];

    # At boot, and again whenever the host firewall is restarted.
    systemd.services.vm-firewall = {
      description = "Apply each microVM's firewall mode";
      wantedBy = [ "multi-user.target" ];
      after = [
        "firewall.service"
        "nftables.service"
      ];
      partOf = [ "firewall.service" ];
      before = map (vm: "microvm@${vm}.service") (lib.attrNames cfg);
      restartTriggers = [ config.environment.etc."vm-firewall/config.json".source ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${vmFirewall}/bin/vm-firewall apply";
      };
    };

    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command = "${vmFirewall}/bin/vm-firewall set *";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/vm-firewall set *";
            options = [ "NOPASSWD" ];
          }
        ]
        # The bar's start and stop buttons, for exactly these VMs.
        ++ lib.concatMap (
          vm:
          map
            (action: {
              command = "/run/current-system/sw/bin/systemctl ${action} microvm@${vm}.service";
              options = [ "NOPASSWD" ];
            })
            [
              "start"
              "stop"
            ]
        ) (lib.attrNames cfg);
      }
    ];
  };
}
