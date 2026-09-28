# i3 + i3status config for the Kali VM (modules/nixos/vms.nix).
#
# The modifier is Alt (keys.vmWm), not Super: sway owns Super on the host and
# would swallow it before the VM window saw it, and neovim/tmux/alacritty
# never bind Alt (home/keymap.nix checks this), so nothing fights over a key.
# Directions are vim's h/j/k/l. Colours come from the Miami Wind palette.
{ palette, keys }:
let
  p = palette;
  mod = keys.vmWm;
  lock = "i3lock -c ${p.strip p.bg}";
  ws = n: key: ''
    bindsym ${mod}+${key} workspace number ${toString n}
    bindsym ${mod}+Shift+${key} move container to workspace number ${toString n}
  '';
  workspaces = builtins.concatStringsSep "" (
    builtins.genList (i: ws (i + 1) (toString (if i == 9 then 0 else i + 1))) 10
  );
in
{
  i3 = ''
    set $mod ${mod}
    font pango:${p.font.name} ${toString p.font.size}

    default_border pixel 2
    default_floating_border pixel 2
    gaps inner 6
    gaps outer 2
    smart_borders on
    floating_modifier $mod

    #                       border          background      text           indicator      child_border
    client.focused          ${p.pink}       ${p.pink}       ${p.bgDark}    ${p.cyan}      ${p.pink}
    client.focused_inactive ${p.surfaceHi}  ${p.surface}    ${p.fg}        ${p.surfaceHi} ${p.surfaceHi}
    client.unfocused        ${p.surface}    ${p.bgAlt}      ${p.fgDim}     ${p.surface}   ${p.surface}
    client.urgent           ${p.redBright}  ${p.redBright}  ${p.white}     ${p.redBright} ${p.redBright}
    client.background       ${p.bg}

    exec_always --no-startup-id feh --no-fehbg --bg-max --image-bg '${p.bg}' ~/.local/share/harmonia/wallpaper.png
    exec --no-startup-id dunst

    # apps
    bindsym $mod+Return exec alacritty
    bindsym $mod+d exec --no-startup-id rofi -show drun
    bindsym $mod+q kill

    # focus / move (vim directions)
    bindsym $mod+h focus left
    bindsym $mod+j focus down
    bindsym $mod+k focus up
    bindsym $mod+l focus right
    bindsym $mod+Shift+h move left
    bindsym $mod+Shift+j move down
    bindsym $mod+Shift+k move up
    bindsym $mod+Shift+l move right
    bindsym $mod+a focus parent
    bindsym $mod+Shift+a focus child

    # workspaces
    ${workspaces}
    bindsym $mod+Tab workspace back_and_forth

    # layout
    bindsym $mod+s split vertical
    bindsym $mod+v split horizontal
    bindsym $mod+t layout tabbed
    bindsym $mod+Shift+t layout stacking
    bindsym $mod+e layout toggle split
    bindsym $mod+f fullscreen toggle
    bindsym $mod+Shift+space floating toggle
    bindsym $mod+space focus mode_toggle
    bindsym $mod+minus scratchpad show
    bindsym $mod+Shift+minus move scratchpad

    # session
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+r restart
    bindsym $mod+Shift+x exec --no-startup-id ${lock}
    bindsym $mod+Shift+e mode "system"

    # screenshots → clipboard
    bindsym Print exec --no-startup-id maim -s | xclip -selection clipboard -t image/png
    bindsym Shift+Print exec --no-startup-id maim | xclip -selection clipboard -t image/png

    bindsym $mod+r mode "resize"
    mode "resize" {
      bindsym h resize shrink width 20 px
      bindsym j resize grow height 20 px
      bindsym k resize shrink height 20 px
      bindsym l resize grow width 20 px
      bindsym Shift+h resize shrink width 100 px
      bindsym Shift+j resize grow height 100 px
      bindsym Shift+k resize shrink height 100 px
      bindsym Shift+l resize grow width 100 px
      bindsym Escape mode "default"
      bindsym Return mode "default"
    }

    mode "system" {
      bindsym l exec --no-startup-id ${lock}, mode "default"
      bindsym e exit
      bindsym r exec --no-startup-id systemctl reboot
      bindsym Shift+p exec --no-startup-id systemctl poweroff
      bindsym Escape mode "default"
      bindsym Return mode "default"
    }

    bar {
      status_command i3status
      position top
      font pango:${p.font.name} ${toString p.font.size}
      colors {
        background ${p.bgDark}
        statusline ${p.fg}
        separator  ${p.muted}
        #                  border         background     text
        focused_workspace  ${p.pink}      ${p.pink}      ${p.bgDark}
        active_workspace   ${p.surfaceHi} ${p.surface}   ${p.fg}
        inactive_workspace ${p.bgDark}    ${p.bgDark}    ${p.fgDim}
        urgent_workspace   ${p.redBright} ${p.redBright} ${p.white}
        binding_mode       ${p.cyan}      ${p.cyan}      ${p.bgDark}
      }
    }
  '';

  i3status = ''
    general {
      colors = true
      color_good = "${p.green}"
      color_degraded = "${p.yellow}"
      color_bad = "${p.redBright}"
      interval = 5
    }

    order += "cpu_usage"
    order += "memory"
    order += "disk /"
    order += "tztime local"

    cpu_usage { format = "cpu %usage" }
    memory { format = "mem %used" }
    disk "/" { format = "disk %avail" }
    tztime local { format = "%a %d %b %H:%M" }
  '';
}
