# Local secrets: KeePassXC (keepassxc-cli) for the local database, the
# Bitwarden CLI for the cloud vault, plain OpenSSH ssh-agent for SSH keys, gpg
# (no agent setup of its own), ykman and the OpenBao CLI, plus the
# `secrets-backup` command (home/secrets-backup.py), which bundles the
# KeePassXC database(s), a Bitwarden export, ~/.ssh, gpg keys and any old pass
# store into one
# passphrase-encrypted tarball. See docs/secrets.md.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
in
{
  home.packages = with pkgs; [
    keepassxc # keepassxc-cli (and the GUI)
    bitwarden-cli # bw
    yubikey-manager # ykman
    openbao # bao
    (pyScript "secrets-backup" {
      runtimeInputs = [
        gnupg
        bitwarden-cli
      ];
    } ./secrets-backup.py)
  ];

  # The local KeePassXC database, for `keepassxc-cli <command> "$KEEPASSXC_DB" ...`.
  home.sessionVariables.KEEPASSXC_DB = "${config.xdg.dataHome}/keepassxc/passwords.kdbx";

  # gpg stays for the YubiKey and secrets-backup, but gpg-agent no longer
  # backs pass or SSH: there is no pass store and no services.gpg-agent.
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
}
