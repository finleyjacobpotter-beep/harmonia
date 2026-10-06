# Calendar

Clicking the clock on the bar opens a month calendar. Buttons at the top
switch the bar's time zone between **Eastern** (`America/New_York`),
**Pacific** (`America/Los_Angeles`) and **UTC**; the choice is kept in
`~/.local/state/eww/timezone` and also decides which day an event falls on.
Until you pick one, the bar uses the system time zone.

Days with events get a coloured dot per calendar under the date. Click a
day to list its events under the grid; `‹` `›` change month and **Today**
goes back.

## Syncing a CalDAV calendar

The events come from [vdirsyncer](https://vdirsyncer.pimutils.org/), which
copies your calendars into `~/.local/share/calendars` as `.ics` files. A
user timer (`vdirsyncer.timer`) syncs every 15 minutes, then refreshes the
calendar panel. It does nothing until you write the config below, which is
not part of the repo, so your server and user name stay out of it.

1. Store the password in pass (an app password if your provider has them):

   ```sh
   pass insert calendar/caldav
   ```

2. Write `~/.config/vdirsyncer/config`:

   ```ini
   [general]
   status_path = "~/.local/state/vdirsyncer/status/"

   [pair calendar]
   a = "calendar_remote"
   b = "calendar_local"
   collections = ["from a"]
   metadata = ["color", "displayname"]

   [storage calendar_remote]
   type = "caldav"
   url = "https://caldav.example.com/"
   username = "you@example.com"
   password.fetch = ["command", "pass", "show", "calendar/caldav"]
   read_only = true

   [storage calendar_local]
   type = "filesystem"
   path = "~/.local/share/calendars/"
   fileext = ".ics"
   ```

   For a published `.ics` link (a "subscribe" URL) instead of a CalDAV
   account, use this remote storage and `collections = null`:

   ```ini
   [storage calendar_remote]
   type = "http"
   url = "https://example.com/calendar.ics"
   ```

3. Find the calendars and sync once by hand:

   ```sh
   vdirsyncer discover calendar
   vdirsyncer metasync && vdirsyncer sync
   ```

   After that the timer keeps it up to date. Run a sync now with
   `systemctl --user start vdirsyncer`, and see its log with
   `journalctl --user -u vdirsyncer`.

`read_only = true` keeps the sync one way (server to laptop); the bar only
reads the files. Drop it if you edit these files with another program and
want the changes pushed back.

### The password and the timer

pass decrypts with your gpg key, and gpg-agent (home/secrets.nix) asks for
the passphrase. The timer never asks (its gpg runs with
`--pinentry-mode=error`), so a timed sync only works while gpg-agent still
has the key cached (10 minutes after you last used it, 2 hours at most).
When it isn't, the sync fails quietly and the
calendar keeps the events from the last good sync; run `vdirsyncer sync`
in a terminal to sync straight away. A published `.ics` link needs no
password, so it always syncs.

## Colours

Each calendar's dot uses the colour your server gives it (vdirsyncer's
`metasync` saves it as a `color` file next to the events). Calendars
without one get the Miami Wind accents in turn. To pick your own, write a
colour into that file, for example
`echo '#5fd7ff' > ~/.local/share/calendars/work/color`, and remove
`"color"` from `metadata` so the next sync doesn't overwrite it.

A single `.ics` file copied straight into `~/.local/share/calendars/` is
shown as a calendar of its own, with no sync needed.

The panel is `home/eww/cal.py`: it reads every `.ics` file, expands
repeating events, and marks each day an event touches.
