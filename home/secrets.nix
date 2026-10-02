# Local secrets: gpg + gpg-agent, pass, ykman, Bitwarden CLI and the OpenBao
# CLI, plus the `secrets-backup` command (home/secrets-backup.py), which bundles pass,
# Bitwarden and gpg keys into one passphrase-encrypted tarball. See docs/secrets.md.
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
    yubikey-manager # ykman
    bitwarden-cli # bw
    openbao # bao
    (pyScript "secrets-backup" {
      runtimeInputs = [
        gnupg
        bitwarden-cli
      ];
    } ./secrets-backup.py)
  ];

  programs.gpg = {
    enable = true;
    settings = {
      keyid-format = "0xlong";
      with-fingerprint = true;
    };
    # Leave the reader to pcscd so ykman and gpg can share the YubiKey.
    scdaemonSettings.disable-ccid = true;
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableBashIntegration = true;
    # In-terminal passphrase prompt, keyboard only like the rest of the desktop.
    pinentry.package = pkgs.pinentry-curses;
    defaultCacheTtl = 600;
    maxCacheTtl = 7200;
  };

  services.ssh-agent.enable = false;

  programs.password-store = {
    enable = true;
    settings = {
      PASSWORD_STORE_DIR = "${config.xdg.dataHome}/password-store";
      PASSWORD_STORE_CLIP_TIME = "45";
    };
  };
}
