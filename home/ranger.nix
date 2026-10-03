{ pkgs, palette, ... }:
let
  # The ANSI colour that stands in for the accent (magenta = pink, red on Nike).
  accent = palette.accentAnsi;
  devicons = pkgs.fetchFromGitHub {
    owner = "alexanderjeurissen";
    repo = "ranger_devicons";
    rev = "1bcaff0366a9d345313dc5af14002cfdcddabb82";
    hash = "sha256-qvWqKVS4C5OO6bgETBlVDwcv4eamGlCUltjsBU3gAbA=";
  };
in
{
  programs.ranger = {
    enable = true;
    extraPackages = with pkgs; [
      file
      highlight
      atool
      poppler-utils
      mediainfo
    ];
    settings = {
      colorscheme = "miami_wind";
      preview_files = true;
      preview_directories = true;
      preview_images = false; # alacritty has no image protocol
      draw_borders = "both";
      show_hidden = false;
      vcs_aware = true;
      unicode_ellipsis = true;
      line_numbers = "relative";
      one_indexed = true;
    };
    plugins = [
      {
        name = "ranger_devicons";
        src = devicons;
      }
    ];
    extraConfig = ''
      default_linemode devicons
    '';
  };

  # Colour scheme built on the terminal's ANSI slots, which alacritty maps to
  # the Miami Wind palette (see home/alacritty.nix).
  xdg.configFile."ranger/colorschemes/miami_wind.py".text = ''
    from ranger.gui.colorscheme import ColorScheme
    from ranger.gui.color import (
        black, red, green, yellow, blue, magenta, cyan, white, default,
        normal, bold, reverse, dim, BRIGHT, default_colors,
    )


    class Scheme(ColorScheme):
        progress_bar_color = ${accent}

        def use(self, context):
            fg, bg, attr = default_colors

            if context.reset:
                return default_colors

            elif context.in_browser:
                if context.selected:
                    attr = reverse
                if context.empty or context.error:
                    fg = red + BRIGHT
                if context.border:
                    fg = black + BRIGHT
                if context.media:
                    fg = magenta if context.image else yellow
                if context.container:
                    fg = yellow + BRIGHT  # nearest ANSI slot to orange
                if context.directory:
                    attr |= bold
                    fg = cyan
                elif context.executable and not any((
                        context.media, context.container, context.fifo,
                        context.socket)):
                    attr |= bold
                    fg = green
                if context.socket:
                    fg = magenta + BRIGHT
                if context.fifo or context.device:
                    fg = yellow
                    if context.device:
                        attr |= bold
                if context.link:
                    fg = blue if context.good else red + BRIGHT
                if context.tag_marker and not context.selected:
                    attr |= bold
                    fg = ${accent}
                if not context.selected and (context.cut or context.copied):
                    fg = black + BRIGHT
                    attr |= bold
                if context.main_column:
                    if context.selected:
                        attr |= bold
                    if context.marked:
                        attr |= bold
                        fg = yellow + BRIGHT
                if context.badinfo:
                    if attr & reverse:
                        bg = red
                    else:
                        fg = red

                if context.inactive_pane:
                    fg = black + BRIGHT

            elif context.in_titlebar:
                attr |= bold
                if context.hostname:
                    fg = ${accent}
                elif context.directory:
                    fg = cyan
                elif context.tab:
                    if context.good:
                        bg = ${accent}
                        fg = black
                elif context.link:
                    fg = blue

            elif context.in_statusbar:
                if context.permissions:
                    if context.good:
                        fg = cyan
                    elif context.bad:
                        fg = red + BRIGHT
                if context.marked:
                    attr |= bold | reverse
                    fg = yellow
                if context.frozen:
                    attr |= bold | reverse
                    fg = cyan
                if context.message:
                    if context.bad:
                        attr |= bold
                        fg = red + BRIGHT
                if context.loaded:
                    bg = self.progress_bar_color
                if context.vcsinfo:
                    fg = blue
                    attr &= ~bold
                if context.vcscommit:
                    fg = yellow
                    attr &= ~bold
                if context.vcsdate:
                    fg = cyan
                    attr &= ~bold

            if context.text:
                if context.highlight:
                    attr |= reverse

            if context.in_taskview:
                if context.title:
                    fg = ${accent}
                if context.selected:
                    attr |= reverse
                if context.loaded:
                    if context.selected:
                        fg = self.progress_bar_color
                    else:
                        bg = self.progress_bar_color

            if context.vcsfile and not context.selected:
                attr &= ~bold
                if context.vcsconflict:
                    fg = red + BRIGHT
                elif context.vcsuntracked:
                    fg = yellow
                elif context.vcschanged:
                    fg = magenta
                elif context.vcsunknown:
                    fg = red
                elif context.vcsstaged:
                    fg = green
                elif context.vcssync:
                    fg = green
                elif context.vcsignored:
                    fg = black + BRIGHT

            elif context.vcsremote and not context.selected:
                attr &= ~bold
                if context.vcssync or context.vcsnone:
                    fg = green
                elif context.vcsbehind:
                    fg = red
                elif context.vcsahead:
                    fg = blue
                elif context.vcsdiverged:
                    fg = magenta + BRIGHT
                elif context.vcsunknown:
                    fg = red

            return fg, bg, attr
  '';
}
