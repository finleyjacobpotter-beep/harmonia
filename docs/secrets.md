# Secrets

Local secrets tooling lives in `home/secrets.nix` (user side) and
`modules/nixos/secrets.nix` (pcscd and the YubiKey udev rules).

| Tool | Command | Notes |
| --- | --- | --- |
| GnuPG + gpg-agent | `gpg` | curses pinentry in the terminal; passphrases cached 10 min (2 h max) |
| pass | `pass` | store in `~/.local/share/password-store`, clipboard cleared after 45 s |
| YubiKey Manager | `ykman` | talks to the key through pcscd; gpg's scdaemon does too (`disable-ccid`) |
| Bitwarden CLI | `bw` | |
| OpenBao CLI | `bao` | set `BAO_ADDR` to your server, then `bao login` |

## First run

```sh
gpg --full-generate-key          # or import yours / use the one on your YubiKey
pass init <your key id>
bw login                         # once; later: export BW_SESSION=$(bw unlock --raw)
export BAO_ADDR=https://bao.example.com && bao login
ykman info                       # with the key plugged in
```

## Backup: `secrets-backup`

`secrets-backup [DIR]` writes `DIR/secrets-backup-<UTC time>.tar.gz.gpg`
(`DIR` defaults to `$HOME`). It includes whatever is reachable right now and
skips, with a warning, anything missing, locked or logged out:

| Part | What goes in | Needs |
| --- | --- | --- |
| `gpg/` | all public keys and the ownertrust | a keyring |
| `pass/` | the whole store as is (already encrypted), with its git history | `pass init` done |
| `bitwarden.json` | `bw export --format json` (asks for the master password again) | `bw status` is `unlocked` |
| `bao/<mount>/…` | every KV secret the token can read, one JSON per secret | `bao token lookup` succeeds |
| `yubikey/<serial>/` | `ykman info`, OATH account names, PIV and OpenPGP status | a YubiKey plugged in |

The tarball is encrypted to `$SECRETS_BACKUP_RECIPIENT` (a key id, fingerprint
or email), or to the first gpg secret key when that is unset. The recipient
must be a key you trust, for example your own. Set it permanently in
`home/bash.nix`'s `sessionVariables`.

Plaintext (the Bitwarden and OpenBao exports) only exists in a private
`mktemp -d` directory that is deleted when the function exits or is
interrupted; the tar stream goes straight into gpg, so no unencrypted archive
is written.

What is **not** in the backup:

- **gpg secret keys.** The backup is encrypted to them, so a copy inside it
  would be useless if they were lost. Back them up separately, e.g.
  `gpg --armor --export-secret-keys > /media/offline-usb/secret-keys.asc`.
- **YubiKey private keys and OATH seeds.** They cannot leave the device; the
  inventory tells you what to re-enrol on a replacement key.

Restore:

```sh
d=$(mktemp -d) && gpg -d secrets-backup-<time>.tar.gz.gpg | tar -xzf - -C "$d" && cd "$d"
```
