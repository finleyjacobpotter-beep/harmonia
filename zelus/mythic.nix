# Mythic C2 on Zelus, for finley's isolated red-team / OSCP lab. Mythic
# (https://github.com/its-a-feature/Mythic) is an open-source C2 framework
# that runs as a docker-compose stack managed by its own `mythic-cli`; this
# turns on Docker in the guest and adds the `mythic` helper (zelus/mythic.py)
# that clones the repo and drives mythic-cli.
#
#   mythic start            bring the stack up (first run builds the images)
#   mythic status           what's running, and the admin URL + password
#   mythic stop             take it down
#
# The stack listens inside Zelus only; nothing on the LAN can reach the VM
# (the host NATs its egress and no port is forwarded in). Pulling and
# building the images needs the internet, so the firewall must be in
# Permissive mode (the bar's Zelus panel) the first time.
{
  pkgs,
  lib,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
  mythic = pyScript "mythic" {
    runtimeInputs = [
      pkgs.git
      pkgs.gnumake
      pkgs.docker
      pkgs.docker-compose
    ];
  } ./mythic.py;
in
{
  virtualisation.docker = {
    enable = true;
    # Images and volumes go on /home (the big volume), not the small /var.
    daemon.settings.data-root = "/home/c/.docker";
    autoPrune.enable = true;
  };
  # So `c` can drive Docker without sudo.
  users.users.c.extraGroups = [ "docker" ];

  environment.systemPackages = [
    mythic
    pkgs.docker-compose
  ];
}
