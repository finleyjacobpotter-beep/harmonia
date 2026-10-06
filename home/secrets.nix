# Local secrets: gpg + gpg-agent, pass, ykman, Bitwarden CLI and the OpenBao
# CLI, plus the `secrets-backup` command (home/secrets-backup.py), which bundles pass,
# Bitwarden and gpg keys into one passphrase-encrypted tarball. See docs/secrets.md.
{
  pkgs,
  lib,
  config,
  palette,
  ...
}:
let
  p = palette;
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  # gpg-agent is one process for the whole session, so a curses prompt goes
  # to whichever terminal last ran `gpg-connect-agent updatestartuptty`, not
  # the one that asked, and fails outright when pass runs from a service or
  # the bar. Under Sway the prompt is a bemenu bar instead (keyboard only,
  # like fuzzel); on a plain console it stays curses.
  bemenuOpts = lib.escapeShellArgs [
    "--fn"
    "${p.font.name} ${toString p.font.size}"
    "--tb"
    p.bg
    "--tf"
    p.primary
    "--fb"
    p.bg
    "--ff"
    p.fg
    "--nb"
    p.bg
    "--nf"
    p.fg
    "--hb"
    p.surface
    "--hf"
    p.secondary
  ];
  pinentry = pkgs.writeShellScriptBin "pinentry-harmonia" ''
    if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      export BEMENU_OPTS=${lib.escapeShellArg bemenuOpts}
      exec ${pkgs.pinentry-bemenu}/bin/pinentry-bemenu "$@"
    fi
    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
  '';
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
    pinentry.package = pinentry;
    pinentry.program = "pinentry-harmonia";
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
