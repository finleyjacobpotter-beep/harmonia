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
| `pass/` | the whole store as is (already encrypted), with its git history | `pass init` done |
| `bitwarden.json` | `bw export --format json` (asks for the master password again) | `bw status` is `unlocked` |
| `gpg/` | public and secret keys, and the ownertrust | a secret key in the keyring |

The tarball is encrypted with a **passphrase** (gpg `--symmetric`, AES-256),
not with a gpg key, so it still opens if your keys are lost. gpg asks for the
passphrase twice through pinentry and does not cache it. The secret keys
inside keep their own key passphrase on top of that. Pick a strong backup
passphrase you can remember without this machine.

Plaintext (the Bitwarden export) only exists in a private `mktemp -d`
directory that is deleted when the function exits or is interrupted; the tar
stream goes straight into gpg, so no unencrypted archive is written.

YubiKey private keys and OATH seeds are not in the backup: they cannot leave
the device.

Restore:

```sh
d=$(mktemp -d) && gpg -d secrets-backup-<time>.tar.gz.gpg | tar -xzf - -C "$d" && cd "$d"
gpg --import gpg/secret-keys.asc && gpg --import-ownertrust gpg/ownertrust.txt
cp -a pass ~/.local/share/password-store
bw import bitwardenjson bitwarden.json   # then delete the plaintext: rm -rf "$d"
```
