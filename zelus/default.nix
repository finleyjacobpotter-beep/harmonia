# Zelus, the microVM guest. What every microVM shares (network, shares,
# volumes, ssh, the status service, the host's shell configs) is
# lib/microvm-guest.nix; the host side (its network, shared folders,
# `ssh zelus` and the Blender/Godot sockets) is modules/nixos/zelus.nix.
#
# Login: c, no password (ssh zelus from the host). The shell, neovim, tmux
# and ranger are the host's own home-manager configs in cyan instead of pink
# (colors in modules/nixos/zelus.nix). Claude Code and opencode (home/opencode.nix) both have
# the Blender and Godot MCP servers (home/mcp-servers.nix).
{
  lib,
  pkgs,
  vm,
  ...
}:
let
  mcp = (import ../home/mcp-servers.nix { inherit pkgs; }).zelus vm;
  claudeMcpServers = pkgs.writeText "claude-mcp-servers.json" (
    builtins.toJSON {
      blender = {
        type = "stdio";
        command = "${mcp.blender}/bin/blender-mcp";
        args = [ ];
      };
      # MCP over the host's Godot relay (modules/nixos/zelus.nix).
      godot = {
        type = "stdio";
        command = "${pkgs.socat}/bin/socat";
        args = [
          "-"
          "TCP:${vm.hostAddress}:${toString vm.godotPort}"
        ];
      };
    }
  );
in
{
  imports = [
    (import ../lib/microvm-guest.nix {
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
      source = vm.projectsDir;
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
    socat
  ];

  home-manager.extraSpecialArgs.zelus = vm;
  home-manager.users.c =
    { lib, ... }:
    {
      imports = [ ../home/opencode.nix ];

      # `claude`, then /login the first time. The MCP servers reach Blender
      # and Godot on the host through sockets on the host's end of the tap
      # (modules/nixos/zelus.nix), from an ssh session or the console alike.
      programs.claude-code = {
        enable = true;
        # When to use the Rust tools (home/rust-tools.nix); opencode reads
        # ~/.claude/skills too.
        skills = {
          rust-search = ./skills/rust-search/SKILL.md;
          rust-edit = ./skills/rust-edit/SKILL.md;
          rust-inspect = ./skills/rust-inspect/SKILL.md;
        };
      };

      # The Blender and Godot MCP servers, as user-scope servers in
      # ~/.claude.json (what `claude mcp add --scope user` writes), merged in on
      # every activation. programs.claude-code.mcpServers ships them as a
      # personal plugin instead, which Claude Code didn't show.
      home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        f="$HOME/.claude.json"
        [ -s "$f" ] || echo '{}' > "$f"
        tmp=$(mktemp "$f.XXXXXX")
        ${pkgs.jq}/bin/jq --slurpfile servers ${claudeMcpServers} \
          '.mcpServers = ((.mcpServers // {}) + $servers[0])' "$f" > "$tmp"
        run mv "$tmp" "$f"
      '';
    };
}
