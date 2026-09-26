{ palette, ... }:
let
  p = palette;
  a = p.ansi;
  at = builtins.elemAt a;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "alacritty";
      window = {
        padding = {
          x = 8;
          y = 6;
        };
        decorations = "None";
        opacity = 1.0;
      };
      font = {
        normal.family = p.font.mono;
        bold.family = p.font.mono;
        italic.family = p.font.mono;
        size = p.font.size + 0.0;
      };
      cursor.style = {
        shape = "Block";
        blinking = "On";
      };
      colors = {
        primary = {
          background = p.bg;
          foreground = p.fg;
          dim_foreground = p.fgDim;
          bright_foreground = p.white;
        };
        cursor = {
          text = p.bg;
          cursor = p.pink;
        };
        vi_mode_cursor = {
          text = p.bg;
          cursor = p.cyan;
        };
        selection = {
          text = "CellForeground";
          background = p.surfaceHi;
        };
        search = {
          matches = {
            foreground = p.bg;
            background = p.cyan;
          };
          focused_match = {
            foreground = p.bg;
            background = p.pink;
          };
        };
        hints = {
          start = {
            foreground = p.bg;
            background = p.yellow;
          };
          end = {
            foreground = p.bg;
            background = p.orange;
          };
        };
        footer_bar = {
          foreground = p.fg;
          background = p.surface;
        };
        normal = {
          black = at 0;
          red = at 1;
          green = at 2;
          yellow = at 3;
          blue = at 4;
          magenta = at 5;
          cyan = at 6;
          white = at 7;
        };
        bright = {
          black = at 8;
          red = at 9;
          green = at 10;
          yellow = at 11;
          blue = at 12;
          magenta = at 13;
          cyan = at 14;
          white = at 15;
        };
      };
    };
  };
}
