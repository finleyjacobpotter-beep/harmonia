# Displays for the bar: one icon per sway output, a panel per display to pick
# its resolution, and which display is primary (the one with the bar).
# Usage: eww-display              JSON: {"primary": name, "outputs": [...]}
#        eww-display watch        the same on every output change (for deflisten);
#                                 also reapplies saved resolutions to displays as they
#                                 connect and moves the bar if the primary one comes or goes
#        eww-display start        apply saved resolutions and open the bar (sway startup)
#        eww-display mode NAME MODE   set and remember a resolution, e.g. 2560x1440@143.998Hz
#        eww-display primary NAME     move the bar (and its panels) to NAME, remembered
#        eww-display power NAME on|off
#        eww-display select NAME      open (or close) NAME's panel from its bar icon
#        eww-display dropdown         open or close the resolution list in that panel
#        eww-display menu WINDOW      toggle one of the bar's panels on the primary display
#        eww-display toggle-bar
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/eww
primary_file=$state_dir/primary-display
modes_file=$state_dir/display-modes.json
run_dir=${XDG_RUNTIME_DIR:-/tmp}
seen_file=$run_dir/eww-display.seen
last_file=$run_dir/eww-display.primary
sel_file=$run_dir/eww-display.selected

outputs() { swaymsg -r -t get_outputs 2>/dev/null || echo '[]'; }
saved_modes() { cat "$modes_file" 2>/dev/null || echo '{}'; }

# The remembered primary display if it is connected and on, else the first one that is.
primary() {
  saved=$(cat "$primary_file" 2>/dev/null || true)
  jq -r --arg saved "$saved" '
    [.[] | select(.active) | .name] as $on
    | if ($on | index($saved)) != null then $saved else ($on[0] // "") end' <<<"$1"
}

list() {
  outs=$(outputs)
  jq -c --arg primary "$(primary "$outs")" --arg sel "$(cat "$sel_file" 2>/dev/null || true)" '
    def rate: .refresh / 1000;
    def mode_id: "\(.width)x\(.height)@\(rate)Hz";
    def mode_label: "\(.width)x\(.height) @ \(rate | round) Hz";
    {primary: $primary,
     outputs: [to_entries[] | .key as $i | .value
       | {name, number: ($i + 1), active, primary: (.name == $primary),
          title: ([.make, .model] | map(select(. != null and . != "" and . != "Unknown")) | join(" ")),
          current: (if .active and .current_mode then .current_mode | mode_label else "off" end),
          current_id: (if .active and .current_mode then .current_mode | mode_id else "" end),
          modes: (.modes // [] | unique_by(mode_id)
            | sort_by(-(.width * .height), -.refresh)
            | map({id: mode_id, label: mode_label}))}]}
    # The display whose panel is open, as a list of zero or one for the panel
    # to loop over (it only builds that one).
    | .selected = [.outputs[] | select(.name == $sel)]' <<<"$outs"
}

# Saved resolutions are keyed by make, model and serial, so they follow a
# monitor from port to port.
key() { jq -r --arg n "$2" '.[] | select(.name == $n) | "\(.make) \(.model) \(.serial)"' <<<"$1"; }

# Give newly connected displays their saved resolution (once per connection,
# so a mode sway can't do doesn't loop).
apply_saved() {
  outs=$1
  seen=$(cat "$seen_file" 2>/dev/null || true)
  now_on=$(jq -r '.[] | select(.active) | .name' <<<"$outs")
  saved=$(saved_modes)
  for name in $now_on; do
    grep -qx "$name" <<<"$seen" && continue
    mode=$(jq -r --arg k "$(key "$outs" "$name")" '.[$k] // empty' <<<"$saved")
    [ -n "$mode" ] && swaymsg output "$name" mode "$mode" >/dev/null
  done
  printf '%s\n' "$now_on" >"$seen_file"
}

open_bar() {
  if [ -n "$1" ]; then eww open bar --screen "$1"; else eww open bar; fi
  printf '%s\n' "$1" >"$last_file"
}

# Move the bar when the primary display changes (unplugged, or back again).
follow_primary() {
  want=$(primary "$1")
  [ "$want" = "$(cat "$last_file" 2>/dev/null || true)" ] && return
  for w in $(eww active-windows 2>/dev/null | cut -d: -f1); do
    [ "$w" = bar ] || eww close "$w"
  done
  open_bar "$want"
}

# GTK windows grow but don't shrink: reopen the panel after closing the list.
reopen_panel() { eww open display-menu --screen "$(primary "$(outputs)")"; }

case "${1:-}" in
  watch)
    apply_saved "$(outputs)"
    list
    swaymsg -t subscribe -m '["output"]' | while read -r _; do
      outs=$(outputs)
      apply_saved "$outs"
      follow_primary "$(outputs)"
      list
    done
    ;;
  start)
    rm -f "$seen_file"
    apply_saved "$(outputs)"
    open_bar "$(primary "$(outputs)")"
    ;;
  mode)
    outs=$(outputs)
    mkdir -p "$state_dir"
    saved_modes | jq --arg k "$(key "$outs" "$2")" --arg m "$3" '.[$k] = $m' >"$modes_file.$$" &&
      mv "$modes_file.$$" "$modes_file"
    swaymsg output "$2" mode "$3" >/dev/null
    eww update display_modes_open=false displays="$(list)"
    reopen_panel
    ;;
  dropdown)
    if [ "$(eww get display_modes_open 2>/dev/null || true)" = true ]; then
      eww update display_modes_open=false
      reopen_panel
    else
      eww update display_modes_open=true
    fi
    ;;
  primary)
    mkdir -p "$state_dir"
    printf '%s\n' "$2" >"$primary_file"
    eww close display-menu 2>/dev/null || true
    follow_primary "$(outputs)"
    eww update displays="$(list)"
    ;;
  power)
    if [ "$3" = on ]; then swaymsg output "$2" enable >/dev/null; else swaymsg output "$2" disable >/dev/null; fi
    eww update displays="$(list)"
    reopen_panel
    ;;
  select)
    if [ "$(cat "$sel_file" 2>/dev/null || true)" = "$2" ] &&
      eww active-windows 2>/dev/null | grep -q ': display-menu$'; then
      eww close display-menu
    else
      printf '%s\n' "$2" >"$sel_file"
      eww update display_modes_open=false displays="$(list)"
      reopen_panel
    fi
    ;;
  menu)
    eww open --toggle "$2" --screen "$(primary "$(outputs)")"
    ;;
  toggle-bar)
    if eww active-windows 2>/dev/null | grep -q '^bar:'; then eww close bar; else open_bar "$(primary "$(outputs)")"; fi
    ;;
  *) list ;;
esac
