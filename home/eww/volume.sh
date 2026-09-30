# Default sink volume for the bar and its panel.
# Usage: eww-volume                 JSON: {"pct": N, "muted": bool, "text": "40%", "sink": "..."}
#        eww-volume up|down|mute    change it by 5% (up to 150%) or toggle mute
#        eww-volume set N           set it to N%
sink=@DEFAULT_AUDIO_SINK@

state() {
  out=$(wpctl get-volume "$sink" 2>/dev/null || echo "Volume: 0")
  pct=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$out")
  muted=false
  case "$out" in *MUTED*) muted=true ;; esac
  name=$(wpctl inspect "$sink" 2>/dev/null | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -n1)
  jq -nc --argjson pct "$pct" --argjson muted "$muted" --arg sink "$name" \
    '{pct: $pct, muted: $muted, sink: $sink, text: (if $muted then "muted" else "\($pct)%" end)}'
}

case "${1:-}" in
  up) wpctl set-volume -l 1.5 "$sink" 5%+ ;;
  down) wpctl set-volume "$sink" 5%- ;;
  mute) wpctl set-mute "$sink" toggle ;;
  set) wpctl set-volume -l 1.5 "$sink" "$2%" ;;
  *) state; exit 0 ;;
esac
eww update volume="$(state)"
