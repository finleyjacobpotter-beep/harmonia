# The Miami Wind bash prompt and less/man colours, for home/bash.nix (on the
# host and on Nike). `gpg` is null where there is no gpg-agent (Nike).
{
  palette,
  gitPrompt,
  gpg,
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
    local mark="${rgb p.pink}❯"
    [ $status -ne 0 ] && mark="${rgb p.redBright}❯"
    PS1="\n${rgb p.cyan}\u${rgb p.muted}@${rgb p.purple}\h ${rgb p.yellow}\w${rgb p.pink}$(__git_ps1 '  %s')${reset}\n$mark${reset} "
  }
  PROMPT_COMMAND="__mw_prompt''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

  # Colours for less / man pages
  export LESS_TERMCAP_md=$'\e[1;38;2;${rgbBytes p.pink}m'   # bold      -> accent
  export LESS_TERMCAP_us=$'\e[4;38;2;${rgbBytes p.cyan}m'    # underline -> cyan
  export LESS_TERMCAP_so=$'\e[38;2;${rgbBytes p.bg};48;2;${rgbBytes p.yellow}m' # standout -> yellow bg
  export LESS_TERMCAP_me=$'\e[0m'
  export LESS_TERMCAP_ue=$'\e[0m'
  export LESS_TERMCAP_se=$'\e[0m'
''
+ (
  if gpg == null then
    ""
  else
    ''

      # Setup GPG / SSH
      export GPG_TTY="$(tty)"
      ${gpg}/bin/gpg-connect-agent /bye
      if [ -z "$SSH_AUTH_SOCK" ]; then
        export SSH_AUTH_SOCK=$(${gpg}/bin/gpgconf --list-dirs agent-ssh-socket)
      fi
    ''
)
