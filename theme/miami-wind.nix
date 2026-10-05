# Miami Wind — palette taken verbatim from the VS Code theme
# (hanakin.miami-wind, https://github.com/hanakin/miami-wind-vscode) and its
# canonical palette (https://github.com/hanakin/miami-wind/blob/main/palette.css).
#
# Every app in this flake reads its colours from here, so this is the only file
# to touch if you want to tweak the scheme.
rec {
  name = "Miami Wind";

  # Base colours
  pink = "#f472b6"; # primary
  cyan = "#22d3ee"; # secondary
  yellow = "#fef08a";
  purple = "#c084fc";
  blue = "#818cf8";
  green = "#34d399";
  red = "#f87171";
  orange = "#fdba74";

  # Bright colours
  pinkBright = "#ec4899";
  cyanBright = "#38bdf8";
  yellowBright = "#fde047"; # warning
  purpleBright = "#a78bfa";
  blueBright = "#2563eb"; # info
  greenBright = "#4ade80"; # success
  redBright = "#f43f5e"; # fail
  orangeBright = "#fb923c";

  # Greyscale (Catppuccin Mocha derived)
  grey50 = "#cdd6f4";
  grey100 = "#bac2de";
  grey200 = "#a6adc8";
  grey300 = "#9399b2";
  grey400 = "#7f849c";
  grey500 = "#6c7086";
  grey600 = "#585b70";
  grey700 = "#45475a";
  grey800 = "#313244";
  grey900 = "#1e1e2e";
  grey1000 = "#181825";
  grey1100 = "#11111b";
  grey1200 = "#0d0d14";
  grey1300 = "#09090b";
  white = "#f8f8f2";

  # Semantic roles, mirroring the VS Code theme
  bg = grey900; # editor.background
  bgAlt = grey1000; # sideBar.background
  bgDark = grey1100; # activityBar / statusBar / titleBar
  surface = grey800;
  surfaceHi = grey700;
  fg = grey50; # editor.foreground
  fgDim = grey200;
  muted = grey600;
  comment = blue;
  # The two colours the shell, tmux, ranger and neovim lead with. A microVM
  # swaps them for its own (harmonia.microvms.<name>.colors), so a shell on
  # it never looks like one on the host.
  primary = pink;
  primaryBright = pinkBright;
  secondary = cyan;
  secondaryBright = cyanBright;
  accent = primary; # focusBorder, cursor
  accentAlt = secondary;
  selection = "${primary}40"; # editor.selectionBackground
  selectionSolid = "#4a2d45"; # the selection blended over bg, for neovim
  accentAnsi = "magenta"; # the ANSI slot nearest the accent, for ranger

  # terminal.ansi* from the VS Code theme, in ANSI order (0-15)
  ansi = [
    grey1100 # black
    red
    green
    yellow
    blue
    pink # magenta
    cyan
    grey200 # white
    grey600 # bright black
    redBright
    greenBright
    yellowBright
    blueBright
    pinkBright # bright magenta
    cyanBright
    white # bright white
  ];

  font = {
    # "DepartureMono Nerd Font" is the variant with double-width icons for UI text;
    # "... Mono" keeps icons single-cell, which is what terminals want.
    name = "DepartureMono Nerd Font";
    mono = "DepartureMono Nerd Font Mono";
    propo = "DepartureMono Nerd Font Propo";
    size = 11;
  };

  # "#f472b6" -> "f472b6"
  strip = c: builtins.substring 1 (builtins.stringLength c - 1) c;
}
