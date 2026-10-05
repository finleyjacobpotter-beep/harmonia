# Zelus, the microVM guest. What every microVM shares (network, shares,
# volumes, ssh, the status service, the host's shell configs) is
# lib/microvm-guest.nix; the host side (its network, shared folders,
# `ssh zelus` and the Blender/Godot forwards) is modules/nixos/zelus.nix,
# which passes `zelus` below.
#
# Login: c, no password (ssh zelus from the host). The shell, neovim, tmux
# and ranger are the host's own home-manager configs in cyan instead of pink
# (zelus/palette.nix). Claude Code and opencode (home/opencode.nix) both have
# the Blender and Godot MCP servers (home/mcp-servers.nix).
{
  lib,
  pkgs,
  zelus,
  ...
}:
let
  mcp = import ../home/mcp-servers.nix { inherit pkgs; };
in
{
  imports = [
    (import ../lib/microvm-guest.nix {
      name = "zelus";
      user = "c";
      vm = zelus;
      varSize = 4096;
      homeSize = 32768;
    })
  ];

  # The only non-free package, and only on Zelus.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];

  # The host's ~/Projects (what Blender and Godot can open), read-write, so
  # Claude Code can work on the same files the editors have open.
  microvm.shares = [
    {
      proto = "virtiofs";
      tag = "projects";
      source = zelus.projectsDir;
      mountPoint = "/home/c/Projects";
    }
  ];

  # No password anywhere: Zelus is reachable from the host only, and ssh,
  # the console and sudo let c straight in.
  users.users.c.hashedPassword = "";
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.sshd.allowNullPassword = true;
  services.getty.autologinUser = "c";
  services.openssh.settings.PermitEmptyPasswords = "yes";

  # bash, neovim, tmux, ranger, Claude Code and opencode come from
  # home-manager below.
  environment.systemPackages = with pkgs; [
    git
    jq
    curl
    wget
    unzip
    btop
    gnumake
    gcc
    python3
    uv
    nodejs
  ];

  home-manager.extraSpecialArgs = { inherit zelus; };
  home-manager.users.c = {
    imports = [ ../home/opencode.nix ];

    # `claude`, then /login the first time. The MCP servers connect to
    # Blender and Godot on the host through `ssh zelus` (see
    # modules/nixos/zelus.nix), so start Claude Code from an ssh session.
    programs.claude-code = {
      enable = true;
      # When to use the Rust tools (home/rust-tools.nix); opencode reads
      # ~/.claude/skills too.
      skills = {
        rust-search = ./skills/rust-search/SKILL.md;
        rust-edit = ./skills/rust-edit/SKILL.md;
        rust-inspect = ./skills/rust-inspect/SKILL.md;
      };
      mcpServers = {
        blender.command = "${mcp.blender}/bin/blender-mcp";
        godot.command = "${mcp.godot}/bin/godot-mcp";
      };
    };
  };
}
