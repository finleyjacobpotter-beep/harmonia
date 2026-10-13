# Matrix in the terminal: iamb, a vim-keyed client, on Super+o c
# (home/open-mode.nix). It replaced the Element Flatpak; calls go through
# Element Call in Firefox instead (docs/matrix.md). iamb draws with the
# terminal's colours, so alacritty's Miami Wind theme (home/alacritty.nix)
# themes it too.
#
# iamb won't start without a profile, which names your Matrix account: set
# harmonia.matrix.userId (in home/default.nix, say) and the config below is
# written; until then iamb asks for one.
{ config, lib, ... }:
let
  cfg = config.harmonia.matrix;
in
{
  options.harmonia.matrix.userId = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "@you:matrix.org";
    description = "Your Matrix ID, for iamb's profile.";
  };

  config = {
    programs.iamb = {
      enable = true;
      settings = lib.mkIf (cfg.userId != null) {
        default_profile = "matrix";
        profiles.matrix.user_id = cfg.userId;
        settings = {
          # Desktop notifications through mako, so they collect on the dash's
          # notifications tile and follow its focus switch.
          notifications.enabled = true;
          username_display = "displayname";
        };
        # Reopen the rooms and splits from last time.
        layout.style = "restore";
      };
    };
  };
}
