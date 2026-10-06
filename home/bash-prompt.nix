# The Miami Wind bash prompt and less/man colours, for home/bash.nix (on the
# host and on Nike). GPG_TTY and SSH_AUTH_SOCK come from home-manager's
# gpg-agent module (home/secrets.nix).
{
  palette,
  gitPrompt,
}:
let
  p = palette;
  # "#f472b6" -> "244;114;182"
  rgbBytes =
    hex:
    let
      h = p.strip hex;
      byte = i: toString (fromTOML "x = 0x${builtins.substring i 2 h}").x;
    in
    "${byte 0};${byte 2};${byte 4}";
  # 24-bit colour escape for a palette entry, wrapped for PS1.
  rgb = hex: ''\[\e[38;2;${rgbBytes hex}m\]'';
  reset = ''\[\e[0m\]'';
in
''
  source ${gitPrompt}
  GIT_PS1_SHOWDIRTYSTATE=1
  GIT_PS1_SHOWUNTRACKEDFILES=1

  __mw_prompt() {
    local status=$?
    local mark="${rgb p.primary}❯"
    [ $status -ne 0 ] && mark="${rgb p.redBright}❯"
    PS1="\n${rgb p.secondary}\u${rgb p.muted}@${rgb p.purple}\h ${rgb p.yellow}\w${rgb p.primary}$(__git_ps1 '  %s')${reset}\n$mark${reset} "
  }
  PROMPT_COMMAND="__mw_prompt''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

  # Colours for less / man pages
  export LESS_TERMCAP_md=$'\e[1;38;2;${rgbBytes p.primary}m'   # bold      -> accent
  export LESS_TERMCAP_us=$'\e[4;38;2;${rgbBytes p.secondary}m'    # underline -> secondary
  export LESS_TERMCAP_so=$'\e[38;2;${rgbBytes p.bg};48;2;${rgbBytes p.yellow}m' # standout -> yellow bg
  export LESS_TERMCAP_me=$'\e[0m'
  export LESS_TERMCAP_ue=$'\e[0m'
  export LESS_TERMCAP_se=$'\e[0m'
''
