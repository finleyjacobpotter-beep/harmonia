# The host's side of Zelus for your user: the `opencode` command. opencode
# itself runs on Zelus (home/opencode.nix); this reads the Anthropic key from
# pass here (pinentry asks in this terminal if gpg-agent hasn't cached the
# passphrase) and hands it to opencode over ssh, so the key is never written
# to Zelus's disk. See docs/opencode.md.
{ pkgs, ... }:
let
  launcher = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [
      pkgs.pass
      pkgs.openssh
      pkgs.systemd
    ];
    text = ''
      if ! systemctl is-active --quiet microvm@zelus; then
        echo "opencode runs on Zelus, which is stopped. Start it with:" >&2
        echo "  sudo systemctl start microvm@zelus" >&2
        exit 1
      fi
      export PASSWORD_STORE_DIR="''${PASSWORD_STORE_DIR:-$HOME/.local/share/password-store}"
      if key=$(pass show opencode/anthropic-api-key 2>/dev/null | head -n1) && [ -n "$key" ]; then
        export ANTHROPIC_API_KEY="$key"
      else
        echo "opencode: no key in pass at opencode/anthropic-api-key; Claude won't be available." >&2
        sleep 2
      fi
      # Zelus's sshd accepts this one variable (zelus/default.nix). opencode
      # starts in ~/Projects, which is the host's ~/Projects.
      args=""
      if [ $# -gt 0 ]; then printf -v args ' %q' "$@"; fi
      exec ssh -t -o SendEnv=ANTHROPIC_API_KEY zelus "cd ~/Projects && exec opencode$args"
    '';
  };
in
{
  home.packages = [ launcher ];
}
