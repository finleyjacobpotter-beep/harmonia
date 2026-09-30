# The bar clock, in the time zone picked in the calendar panel.
# Usage: eww-clock           JSON: {"text": "Wed Sep 30 14:16", "abbr": "EDT", "zone": "America/New_York"}
#        eww-clock tz ZONE   switch to ZONE ("local" = the system time zone)
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/eww
state=$state_dir/timezone

now() {
  zone=$(cat "$state" 2>/dev/null || echo local)
  if [ "$zone" = local ]; then
    text=$(date '+%a %b %-d %H:%M'); abbr=$(date +%Z)
  else
    text=$(TZ=$zone date '+%a %b %-d %H:%M'); abbr=$(TZ=$zone date +%Z)
  fi
  jq -nc --arg text "$text" --arg abbr "$abbr" --arg zone "$zone" '{text: $text, abbr: $abbr, zone: $zone}'
}

case "${1:-}" in
  tz)
    mkdir -p "$state_dir"
    printf '%s\n' "$2" >"$state"
    eww update time="$(now)"
    eww-cal refresh
    ;;
  *) now ;;
esac
