# Local secrets: the Bitwarden CLI for the vault, plain OpenSSH ssh-agent for
# SSH keys, gpg (no agent setup of its own), ykman, the OpenBao CLI, and age
# and sops for secrets kept encrypted in a repository, plus the
# `secrets-backup` command (home/secrets-backup.py), which bundles a
# Bitwarden export, ~/.ssh, the sops age key and any old pass store into one
# passphrase-encrypted tarball. See docs/secrets.md.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
  server = config.harmonia.bitwarden.server;
  bw = lib.getExe' pkgs.bitwarden-cli "bw";
in
{
  options.harmonia.bitwarden.server = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "https://vault.example.com";
    description = ''
      Your self-hosted Bitwarden (or Vaultwarden) server, with https://, for
      bw and the Firefox add-on (home/firefox.nix). null keeps bitwarden.com.
    '';
  };

  config = {
    home.packages = with pkgs; [
      bitwarden-cli # bw
      yubikey-manager # ykman
      openbao # bao
      # age-keygen makes the key sops reads from ~/.config/sops/age/keys.txt,
      # its default on Linux, so neither needs more setup here.
      age # age, age-keygen
      sops
      (pyScript "secrets-backup" {
        runtimeInputs = [
          gnupg
          bitwarden-cli
        ];
      } ./secrets-backup.py)
    ];

    # gpg stays for the YubiKey and to encrypt secrets-backup (no gpg identity
    # is kept), but gpg-agent no longer backs pass or SSH: there is no pass
    # store and no services.gpg-agent.
    programs.gpg = {
      enable = true;
      settings = {
        keyid-format = "0xlong";
        with-fingerprint = true;
      };
      # Leave the reader to pcscd so ykman and gpg can share the YubiKey.
      scdaemonSettings.disable-ccid = true;
    };

    # OpenSSH's own agent ($XDG_RUNTIME_DIR/ssh-agent); `ssh-add` your keys.
    services.ssh-agent.enable = true;

    # `bw-unlock` unlocks the Bitwarden vault for this shell, for new shells and
    # for user services (the calendar sync) until `bw-lock` or logout: the
    # session key is kept in $XDG_RUNTIME_DIR, a private tmpfs.
    programs.bash.initExtra = ''
      bw-unlock() {
        local s
        s=$(bw unlock --raw) || return
        export BW_SESSION=$s
        (umask 077 && printf 'BW_SESSION=%s\n' "$s" > "$XDG_RUNTIME_DIR/bw-session")
      }
      bw-lock() {
        bw lock
        unset BW_SESSION
        rm -f "$XDG_RUNTIME_DIR/bw-session"
      }
      if [ -z "$BW_SESSION" ] && [ -r "$XDG_RUNTIME_DIR/bw-session" ]; then
        read -r __bw < "$XDG_RUNTIME_DIR/bw-session" && export BW_SESSION=''${__bw#BW_SESSION=}
        unset __bw
      fi
    '';

    # Point bw at the server before `bw login`. bw keeps it in
    # ~/.config/Bitwarden CLI/data.json and refuses to change it while logged
    # in elsewhere, so then this only warns.
    home.activation.bitwardenServer = lib.mkIf (server != null) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ "$(${bw} config server 2>/dev/null)" != ${lib.escapeShellArg server} ]; then
          run ${bw} config server ${lib.escapeShellArg server} \
            || warnEcho "bw is logged in to another server: bw logout, then rebuild to switch to ${server}"
        fi
      ''
    );
  };
}
