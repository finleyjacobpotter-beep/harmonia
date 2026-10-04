# Podman on the Zelus guest, plus the Mythic C2 lab as a systemd service,
# modelled on Nike's lab stacks (nike/labs.nix on the OSCP-tools branch):
#
#   systemctl start mythic     Mythic C2 (its own stack, via mythic-cli)
#   systemctl stop mythic
#
# It doesn't start at boot: bring it up when you need it. Mythic is for
# finley's isolated red-team / OSCP lab; implants call back to the server
# running here. Everything binds inside Zelus, which nothing on the LAN can
# reach (the host NATs its egress and forwards no port in), so reach the UI
# over an SSH tunnel: `ssh -L 7443:127.0.0.1:7443 zelus`, then
# https://localhost:7443 (mythic-cli prints the admin password; `mythic
# status` shows it again).
#
# Unlike BloodHound or CyberChef, Mythic ships no static compose file: its
# `mythic-cli` generates the compose project and drives it. So the service
# calls the `mythic` helper (zelus/mythic.py), which clones the repo into
# /var/lib/mythic, builds mythic-cli once, and runs `mythic-cli start|stop`.
# `podman` has a `docker` alias here (dockerCompat), so mythic-cli's
# `docker compose` lands on podman.
{
  lib,
  pkgs,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
  mythic = pyScript "mythic" {
    runtimeInputs = [
      pkgs.git
      pkgs.gnumake
      pkgs.podman
      pkgs.podman-compose
      pkgs.gettext # podman-compose shells out to envsubst
    ];
  } ./mythic.py;
in
{
  # Rootless-capable podman with a docker alias, so compose and the usual
  # `docker` muscle memory both work (as on Nike).
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name
  };
  environment.systemPackages = [
    mythic
    pkgs.podman-compose
  ];

  # `systemctl start mythic`. The repo and podman's images live under
  # /var/lib/mythic and /var (the big volume); nothing starts at boot.
  systemd.services.mythic = {
    description = "Mythic C2 stack (mythic-cli over podman)";
    path = with pkgs; [
      podman
      podman-compose
      gettext
      git
      gnumake
    ];
    restartIfChanged = false; # a rebuild shouldn't yank a running lab
    environment.MYTHIC_DIR = "/var/lib/mythic";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "mythic";
      WorkingDirectory = "/var/lib/mythic";
      # First start clones Mythic and builds its images; give it plenty of time.
      TimeoutStartSec = "3600";
      ExecStartPre = "${mythic}/bin/mythic ensure";
      ExecStart = "${mythic}/bin/mythic start";
      ExecStop = "${mythic}/bin/mythic stop";
    };
  };
}
