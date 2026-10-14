# Claude Code and pi, each in its own container on harmonia (docs/pi.md):
# `claude` and `pi` are launchers that start the agent in a rootless,
# hardened podman container named <agent>-<folder>-<uuid>, so every session
# shows on the dash's virtualization tile (home/eww/pods.py). Neither agent
# is installed on the host any more; their configs stay where they were.
#
# The image is Debian (pinned by digest) with Nix and flakes, both agents,
# the Blender, Godot and radare2 MCP servers (./mcp-servers.nix, the same
# builds the configs name), headless Godot and Blender, and the usual
# tools. Nix builds it; the launcher loads it into podman the first time
# after a rebuild changes it.
#
# A container sees only:
#   ~/workdir            the folder you started it in, read-write
#   its own config       ~/.claude for Claude Code; ~/.pi, and Claude's
#                        skills read-only, for pi
#   ~/.cache             ~/.cache/harmonia-agents on the host (uv's and
#                        Nix's caches), so MCP servers start fast
#   the Godot MCP record ~/.config/godot-ai/capabilities, read-only
# and of the host's own services only Blender's add-on (9876) and godot-ai
# (8000, 9500), forwarded to the container's localhost by pasta.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  mcpServers = import ./mcp-servers.nix { inherit pkgs; };
  pi = pkgs.callPackage ../pkgs/pi.nix { };

  # Debian trixie-slim, amd64 (harmonia is x86_64). Update with
  #   nix run nixpkgs#nix-prefetch-docker -- --image-name library/debian --image-tag trixie-slim --arch amd64 --os linux
  debian = pkgs.dockerTools.pullImage {
    imageName = "library/debian";
    imageDigest = "sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f";
    hash = "sha256-gxpTdlht6IxE56i7WP84q9FhyKLkZK7bS3ahlVAGKmg=";
    finalImageName = "debian";
    finalImageTag = "trixie-slim";
    os = "linux";
    arch = "amd64";
  };

  # What the agents find on PATH, ahead of Debian's own /usr/bin.
  tools = pkgs.buildEnv {
    name = "harmonia-agent-tools";
    paths =
      (with pkgs; [
        claude-code
        nix
        bashInteractive
        coreutils
        findutils
        diffutils
        gnugrep
        gnused
        gawk
        gnutar
        gzip
        xz
        unzip
        which
        less
        procps
        file
        git
        ripgrep
        fd
        jq
        curl
        cacert
        uv
        python3
        # Headless: `godot --headless`, `blender -b`.
        godot
        blender
      ])
      ++ [
        pi
        mcpServers.host.blender
        mcpServers.host.godot
        mcpServers.host.radare2
      ];
  };

  certs = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  # Every store path is the user's (uid 1000, group users), so the
  # single-user Nix inside can add to the store without root.
  image = pkgs.dockerTools.streamLayeredImage {
    name = "localhost/harmonia-agent";
    fromImage = debian;
    includeNixDB = true;
    uid = 1000;
    gid = 100;
    uname = "user";
    gname = "users";
    contents = [ tools ];
    fakeRootCommands = ''
      mkdir -p nix/store nix/var/nix
      chown -R 1000:100 nix
    '';
    config = {
      Env = [
        "PATH=${tools}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        "LANG=C.UTF-8"
        "SSL_CERT_FILE=${certs}"
        "NIX_SSL_CERT_FILE=${certs}"
        "GIT_SSL_CAINFO=${certs}"
        # Single-user Nix: no build users, and no build sandbox, which
        # needs namespaces the container doesn't allow.
        "NIX_CONFIG=experimental-features = nix-command flakes\nsandbox = false\nbuild-users-group ="
        # Godot and Blender have no display here.
        "GODOT_DISPLAY_DRIVER=headless"
      ];
    };
  };

  # The agents' common instructions: where they are, so they can tell you
  # when something is out of reach, without spending a turn finding out.
  prompt = agent: ''
    You (${agent}) are running in a rootless Podman container on the user's machine: Debian, with Nix and flakes, and Godot and Blender installed headless (`godot --headless`, `blender -b`). Only the folder the user started you in is mounted, read-write, at ~/workdir, plus your own configuration; nothing else from the host is visible, there is no root or sudo, and of the host's services only Blender (port 9876) and Godot (8000, 9500) are reachable, through your MCP servers. For tools you lack, use `nix shell nixpkgs#<package>` or the project's flake. When a request needs something outside this (other folders, system packages, host services, hardware, a display), tell the user it isn't reachable from the container rather than working around it. Take this description as given: don't probe, test or try to leave the container, and run a project's tests only when the change calls for them.
  '';

  git = config.programs.git.settings.user or { };

  # `claude` / `pi` [ARGS]: the agent in a new container for the current folder.
  launcher =
    {
      agent,
      command,
      mounts,
    }:
    pkgs.writeShellApplication {
      name = agent;
      # podman comes from the system (modules/nixos/podman.nix), with the
      # setuid newuidmap rootless podman needs.
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        image=localhost/harmonia-agent:${image.imageTag}
        if ! podman image exists "$image"; then
          echo "${agent}: loading the agent image (once after each rebuild that changes it)…" >&2
          ${image} | podman load >&2
          # Older harmonia-agent images go; a running session keeps its own.
          podman images --noheading --format '{{.Repository}}:{{.Tag}}' \
            | grep '^localhost/harmonia-agent:' | grep -vx "$image" \
            | xargs -r podman rmi >/dev/null 2>&1 || true
        fi

        # <agent>-<folder>-<uuid>, the folder reduced to what podman allows.
        folder=$(basename "$PWD" | tr -c 'A-Za-z0-9_.-' '-' | sed 's/^[-_.]*//; s/-*$//')
        name="${agent}-''${folder:-root}-$(cat /proc/sys/kernel/random/uuid)"

        mkdir -p "$HOME/.cache/harmonia-agents"
        mounts=(
          --mount "type=tmpfs,destination=$HOME,tmpfs-mode=0700,U=true"
          -v "$PWD:$HOME/workdir"
          -v "$HOME/.cache/harmonia-agents:$HOME/.cache"
          ${mounts}
        )
        capabilities="$HOME/.config/godot-ai/capabilities"
        if [ -d "$capabilities" ]; then
          mounts+=(-v "$capabilities:$capabilities:ro")
        fi

        exec podman run --rm -it --init \
          --name "$name" --hostname "${agent}-''${folder:-root}" \
          --label harmonia.agent=${agent} --label "harmonia.workdir=$PWD" \
          --userns=keep-id --cap-drop=all --security-opt=no-new-privileges \
          --pids-limit=4096 \
          --network "pasta:-T,9876,-T,8000,-T,9500" \
          "''${mounts[@]}" -w "$HOME/workdir" \
          -e TERM -e COLORTERM \
          -e GIT_AUTHOR_NAME=${lib.escapeShellArg (git.name or "")} -e GIT_COMMITTER_NAME=${
            lib.escapeShellArg (git.name or "")
          } \
          -e GIT_AUTHOR_EMAIL=${lib.escapeShellArg (git.email or "")} -e GIT_COMMITTER_EMAIL=${
            lib.escapeShellArg (git.email or "")
          } \
          --entrypoint ${command} "$image" \
          --append-system-prompt ${lib.escapeShellArg (prompt agent)} "$@"
      '';
    };
in
{
  home.packages = [
    (launcher {
      agent = "claude";
      command = "claude";
      # Claude Code keeps everything, .claude.json included, in ~/.claude
      # (CLAUDE_CONFIG_DIR), so the one folder is all it needs.
      mounts = ''-v "$HOME/.claude:$HOME/.claude" -e "CLAUDE_CONFIG_DIR=$HOME/.claude"'';
    })
    (launcher {
      agent = "pi";
      command = "pi";
      # pi reads Claude Code's skills too (home/ai.nix).
      mounts = ''-v "$HOME/.pi:$HOME/.pi" -v "$HOME/.claude/skills:$HOME/.claude/skills:ro"'';
    })
  ];
}
