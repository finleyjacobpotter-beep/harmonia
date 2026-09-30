# Network rates for the bar and its interface panel.
# Usage: eww-net              JSON: {"shown": {...}, "auto": bool, "ifaces": [...]}
#        eww-net show IFACE   show IFACE on the bar ("auto" = the default route's)
# Rates come from /sys/class/net/*/statistics, against the previous sample
# kept in $XDG_RUNTIME_DIR.
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/eww
state=$state_dir/net-iface
prev=${XDG_RUNTIME_DIR:-/tmp}/eww-net.prev

sample() {
  for dir in /sys/class/net/*; do
    name=${dir##*/}
    [ "$name" = lo ] && continue
    wireless=false
    [ -d "$dir/wireless" ] && wireless=true
    printf '%s %s %s %s %s\n' "$name" "$(cat "$dir/statistics/rx_bytes")" \
      "$(cat "$dir/statistics/tx_bytes")" "$(cat "$dir/operstate")" "$wireless"
  done
}

list() {
  now=$(date +%s%N)
  cur=$(sample)
  last=0
  old=""
  if [ -r "$prev" ]; then
    last=$(head -n1 "$prev")
    old=$(tail -n +2 "$prev")
  fi
  printf '%s\n%s\n' "$now" "$cur" >"$prev.$$" && mv "$prev.$$" "$prev"

  default=$(ip route show default 2>/dev/null |
    awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
  choice=$(cat "$state" 2>/dev/null || echo auto)
  shown=$choice
  if [ "$choice" = auto ] || [ ! -e "/sys/class/net/$choice" ]; then shown=$default; fi
  addrs=$(ip -j -4 addr show 2>/dev/null || echo '[]')

  # name state wireless down up
  awk -v now="$now" -v last="$last" -v old="$old" '
    BEGIN {
      n = split(old, lines, "\n")
      for (i = 1; i <= n; i++) { split(lines[i], f, " "); rx[f[1]] = f[2]; tx[f[1]] = f[3] }
      dt = (last > 0 && now > last) ? (now - last) / 1e9 : 0
      split("bps kbps Mbps Gbps", unit, " ")
    }
    {
      down = 0; up = 0
      if (dt > 0 && ($1 in rx)) {
        if ($2 >= rx[$1]) down = ($2 - rx[$1]) / dt
        if ($3 >= tx[$1]) up = ($3 - tx[$1]) / dt
      }
      printf "%s\t%s\t%s\t%s\t%s\n", $1, $4, $5, rate(down), rate(up)
    }
    # Bits per second, scaled to bps, kbps, Mbps or Gbps and padded to a
    # fixed width: the number is "0.0" to "999.9", padded to five characters
    # ("  0.0 bps " to "999.9 Gbps") so the bar stays put.
    function rate(bytes,  v, i) {
      v = bytes * 8
      i = 1
      while (v >= 999.95 && i < 4) { v /= 1000; i++ }
      if (v > 999.9) v = 999.9
      return sprintf("%5.1f %-4s", v, unit[i])
    }' <<<"$cur" |
    jq -Rsc --arg shown "$shown" --arg choice "$choice" --arg default "$default" --argjson addrs "$addrs" '
      ($addrs | map({key: .ifname, value: ([.addr_info[]? | .local][0] // "")}) | from_entries) as $ip
      | [split("\n")[] | select(. != "") | split("\t")
         | {name: .[0], state: .[1], wireless: (.[2] == "true"),
            down: .[3], up: .[4],
            address: ($ip[.[0]] // ""), shown: (.[0] == $shown), default: (.[0] == $default)}] as $ifs
      | {auto: ($choice == "auto"), default: $default,
         shown: (($ifs | map(select(.shown)) | .[0])
           // {name: "offline", state: "down", wireless: false, down: "  0.0 bps ", up: "  0.0 bps ", address: ""}),
         ifaces: $ifs}'
}

case "${1:-}" in
  show)
    mkdir -p "$state_dir"
    printf '%s\n' "$2" >"$state"
    eww update net="$(list)"
    ;;
  *) list ;;
esac
