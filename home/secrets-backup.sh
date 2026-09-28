# secrets-backup [DIR]
#
# Bundle everything the local secrets tools can currently reach into
# DIR/secrets-backup-<UTC timestamp>.tar.gz.gpg (DIR defaults to $HOME),
# encrypted to $SECRETS_BACKUP_RECIPIENT, or to your first gpg secret key.
#
# A tool that is missing, locked or logged out is skipped with a warning.
# Plaintext only ever exists inside a private mktemp directory, which is
# removed on exit, and the tarball is streamed straight into gpg.
secrets-backup() {
  (
    set -o pipefail
    umask 077

    warn() { printf 'secrets-backup: %s\n' "$*" >&2; }
    have() { command -v "$1" >/dev/null 2>&1; }

    out_dir=${1:-$HOME}
    if [ ! -d "$out_dir" ]; then
      warn "no such directory: $out_dir"
      exit 1
    fi

    recipient=${SECRETS_BACKUP_RECIPIENT:-}
    if [ -z "$recipient" ]; then
      recipient=$(gpg --list-secret-keys --with-colons 2>/dev/null |
        awk -F: '$1 == "fpr" { print $10; exit }')
    fi
    if [ -z "$recipient" ] || ! gpg --list-keys "$recipient" >/dev/null 2>&1; then
      warn "no gpg key to encrypt to; set SECRETS_BACKUP_RECIPIENT or create a key"
      exit 1
    fi

    tmp=$(mktemp -d) || exit 1
    trap 'rm -rf "$tmp"' EXIT
    trap 'exit 130' INT TERM HUP
    included=()

    # gpg: public keys and ownertrust. Secret keys are left out on purpose:
    # the backup is encrypted to them, so they need a backup of their own.
    mkdir "$tmp/gpg"
    if gpg --armor --export >"$tmp/gpg/public-keys.asc" &&
      gpg --export-ownertrust >"$tmp/gpg/ownertrust.txt"; then
      included+=(gpg)
    else
      warn "gpg: export failed, skipping"
      rm -rf "$tmp/gpg"
    fi

    # pass: the store is already gpg-encrypted, copy it as is (with its git history).
    store=${PASSWORD_STORE_DIR:-$HOME/.password-store}
    if ! have pass; then
      warn "pass: not installed, skipping"
    elif [ ! -f "$store/.gpg-id" ]; then
      warn "pass: no store at $store (run 'pass init'), skipping"
    elif cp -a "$store" "$tmp/pass"; then
      included+=(pass)
    else
      warn "pass: copy failed, skipping"
      rm -rf "$tmp/pass"
    fi

    # Bitwarden: needs an unlocked session (export BW_SESSION=$(bw unlock --raw)).
    if ! have bw; then
      warn "bitwarden: bw not installed, skipping"
    elif [ "$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null)" != unlocked ]; then
      warn "bitwarden: vault is not unlocked (bw login / bw unlock), skipping"
    else
      bw sync >/dev/null 2>&1 || warn "bitwarden: sync failed, exporting the local copy"
      # bw asks for the master password again before exporting.
      if bw export --format json --output "$tmp/bitwarden.json" >/dev/null; then
        included+=(bitwarden)
      else
        warn "bitwarden: export failed, skipping"
        rm -f "$tmp/bitwarden.json"
      fi
    fi

    # OpenBao: every KV secret the current token can read, one JSON file per secret.
    bao_walk() { # mount path
      local keys key
      keys=$(bao kv list -format=json -mount="$1" "$2" 2>/dev/null | jq -r '.[]') || return 0
      while IFS= read -r key; do
        [ -n "$key" ] || continue
        case $key in
          */) bao_walk "$1" "$2$key" ;;
          *)
            mkdir -p "$tmp/bao/$1/$2"
            bao kv get -format=json -mount="$1" "$2$key" >"$tmp/bao/$1/$2$key.json" ||
              warn "bao: could not read $1/$2$key"
            ;;
        esac
      done <<<"$keys"
    }
    if ! have bao; then
      warn "bao: not installed, skipping"
    elif ! bao token lookup >/dev/null 2>&1; then
      warn "bao: not logged in or server unreachable (check BAO_ADDR, run bao login), skipping"
    else
      mkdir "$tmp/bao"
      mounts=$(bao secrets list -format=json 2>/dev/null |
        jq -r 'to_entries[] | select(.value.type == "kv") | .key | rtrimstr("/")')
      while IFS= read -r mount; do
        [ -n "$mount" ] && bao_walk "$mount" ""
      done <<<"$mounts"
      if [ -n "$(ls -A "$tmp/bao")" ]; then
        included+=(bao)
      else
        warn "bao: no readable KV secrets, skipping"
        rmdir "$tmp/bao"
      fi
    fi

    # YubiKey: private keys never leave the device, so this is an inventory
    # (serials, OATH account names, PIV and OpenPGP status) to rebuild from.
    if ! have ykman; then
      warn "ykman: not installed, skipping"
    else
      serials=$(ykman list --serials 2>/dev/null)
      if [ -z "$serials" ]; then
        warn "ykman: no YubiKey plugged in, skipping"
      else
        while IFS= read -r serial; do
          d="$tmp/yubikey/$serial"
          mkdir -p "$d"
          ykman --device "$serial" info >"$d/info.txt" 2>&1
          ykman --device "$serial" oath accounts list >"$d/oath-accounts.txt" 2>&1
          ykman --device "$serial" piv info >"$d/piv.txt" 2>&1
          ykman --device "$serial" openpgp info >"$d/openpgp.txt" 2>&1
        done <<<"$serials"
        included+=(yubikey)
      fi
    fi

    if [ ${#included[@]} -eq 0 ]; then
      warn "nothing to back up"
      exit 1
    fi

    out="$out_dir/secrets-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.gpg"
    if tar -C "$tmp" -czf - . |
      gpg --batch --yes --encrypt --recipient "$recipient" --output "$out.partial"; then
      mv "$out.partial" "$out"
      printf 'secrets-backup: wrote %s (%s)\n' "$out" "${included[*]}"
    else
      rm -f "$out.partial"
      warn "encryption failed"
      exit 1
    fi
  )
}
