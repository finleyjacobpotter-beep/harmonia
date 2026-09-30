# The Miami Wind bash prompt and less/man colours. Shared by home/bash.nix
# and the Kali VM's bashrc (modules/nixos/vms.nix), which differ only in
# where git's prompt helper lives.
{ palette, gitPrompt }:
let
  p = palette;
  # 24-bit colour escape for a palette entry, wrapped for PS1.
  rgb =
    hex:
    let
      h = p.strip hex;
      byte = i: toString (fromTOML "x = 0x${builtins.substring i 2 h}").x;
    in
    ''\[\e[38;2;${byte 0};${byte 2};${byte 4}m\]'';
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
  export LESS_TERMCAP_md=$'\e[1;38;2;244;114;182m'   # bold      -> pink
  export LESS_TERMCAP_us=$'\e[4;38;2;34;211;238m'    # underline -> cyan
  export LESS_TERMCAP_so=$'\e[38;2;30;30;46;48;2;254;240;138m' # standout -> yellow bg
  export LESS_TERMCAP_me=$'\e[0m'
  export LESS_TERMCAP_ue=$'\e[0m'
  export LESS_TERMCAP_se=$'\e[0m'

  # Setup GPG / SSH
  export GPG_TTY="$(tty)"
  gpg-connect-agent /bye
  if [ -z "$SSH_AUTH_SOCK" ]; then
    export SSH_AUTH_SOCK=$(/etc/profiles/per-user/${config.home.username}/bin/gpgconf --list-dirs agent-ssh-socket)
  fi
''
