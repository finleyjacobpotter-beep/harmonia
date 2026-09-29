# secrets-backup [DIR]  (packaged as a command by home/secrets.nix)
#
# Bundle the pass store, a Bitwarden export and your gpg keys (secret keys
# included) into DIR/secrets-backup-<UTC timestamp>.tar.gz.gpg (DIR defaults
# to $HOME), encrypted with a passphrase (AES-256) rather than a gpg key, so
# the backup can still be opened after the keys themselves are lost.
#
# Anything locked, logged out or not set up yet is skipped with a warning.
# Plaintext only ever exists inside a private mktemp directory, which is
# removed on exit, and the tarball is streamed straight into gpg.
umask 077

warn() { printf 'secrets-backup: %s\n' "$*" >&2; }

out_dir=${1:-$HOME}
if [ ! -d "$out_dir" ]; then
  warn "no such directory: $out_dir"
  exit 1
fi

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM HUP
included=()

# gpg: public and secret keys plus ownertrust. Secret keys stay protected
# by their own passphrase inside the export (gpg asks for it).
if [ -z "$(gpg --list-secret-keys --with-colons 2>/dev/null)" ]; then
  warn "gpg: no secret keys, skipping"
else
  mkdir "$tmp/gpg"
  if gpg --armor --export >"$tmp/gpg/public-keys.asc" &&
    gpg --armor --export-secret-keys >"$tmp/gpg/secret-keys.asc" &&
    gpg --export-ownertrust >"$tmp/gpg/ownertrust.txt"; then
    included+=(gpg)
  else
    warn "gpg: export failed, skipping"
    rm -rf "$tmp/gpg"
  fi
fi

# pass: the store is already gpg-encrypted, copy it as is (with its git history).
store=${PASSWORD_STORE_DIR:-$HOME/.password-store}
if [ ! -f "$store/.gpg-id" ]; then
  warn "pass: no store at $store (run 'pass init'), skipping"
elif cp -a "$store" "$tmp/pass"; then
  included+=(pass)
else
  warn "pass: copy failed, skipping"
  rm -rf "$tmp/pass"
fi

# Bitwarden: needs an unlocked session (export BW_SESSION=$(bw unlock --raw)).
if [ "$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null)" != unlocked ]; then
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

if [ ${#included[@]} -eq 0 ]; then
  warn "nothing to back up"
  exit 1
fi

# gpg asks for the backup passphrase twice through pinentry.
out="$out_dir/secrets-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.gpg"
if tar -C "$tmp" -czf - . |
  gpg --yes --no-symkey-cache --symmetric --cipher-algo AES256 \
    --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65011712 \
    --output "$out.partial"; then
  mv "$out.partial" "$out"
  printf 'secrets-backup: wrote %s (%s)\n' "$out" "${included[*]}"
else
  rm -f "$out.partial"
  warn "encryption failed"
  exit 1
fi
