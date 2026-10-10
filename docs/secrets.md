# Secrets

Local secrets tooling lives in `home/secrets.nix` (user side) and
`modules/nixos/secrets.nix` (pcscd and the YubiKey udev rules).

| Tool | Command | Notes |
| --- | --- | --- |
| KeePassXC CLI | `keepassxc-cli` | the local database, at `$KEEPASSXC_DB` (`~/.local/share/keepassxc/passwords.kdbx`) |
| Bitwarden CLI | `bw` | the cloud vault; `bw-unlock` / `bw-lock` keep a session for the shell and the calendar sync |
| OpenSSH ssh-agent | `ssh-add` | holds SSH keys (`$XDG_RUNTIME_DIR/ssh-agent`); gnome-keyring's SSH agent is off |
| GnuPG | `gpg` | for the YubiKey and the backup; no gpg-agent setup, so it backs neither passwords nor SSH |
| YubiKey Manager | `ykman` | talks to the key through pcscd; gpg's scdaemon does too (`disable-ccid`) |
| OpenBao CLI | `bao` | set `BAO_ADDR` to your server, then `bao login` |
| age | `age`, `age-keygen` | the key sops encrypts to, at `~/.config/sops/age/keys.txt` |
| sops | `sops` | edits files kept encrypted in a repository |

## KeePassXC and Bitwarden together

The two are split by where a secret needs to be:

- **Bitwarden (`bw`) is the everyday vault.** Anything you also want on your
  phone or another machine, and anything a background job needs (the
  calendar sync reads its CalDAV password from here), because `bw` can stay
  unlocked for the session. Firefox has the Bitwarden add-on for the same
  vault ([firefox.md](firefox.md)).
- **KeePassXC (`keepassxc-cli`) is the local, offline database.** Secrets that
  should never sit on someone else's server: recovery codes, the Bitwarden
  master password and 2FA recovery code, disk and backup passphrases, keys
  for this machine only. It asks for the database password on every command,
  so nothing stays unlocked.

```sh
# Bitwarden: log in once, then unlock per session
bw login
bw-unlock                              # sets BW_SESSION here, in new shells and for the calendar sync
bw get password calendar/caldav
bw-lock                                # or log out

# KeePassXC: create the database once, then use it directly
mkdir -p "$(dirname "$KEEPASSXC_DB")"
keepassxc-cli db-create -p "$KEEPASSXC_DB"
keepassxc-cli add -g "$KEEPASSXC_DB" recovery/bitwarden     # -g generates a password
keepassxc-cli show -s "$KEEPASSXC_DB" recovery/bitwarden
keepassxc-cli clip "$KEEPASSXC_DB" recovery/bitwarden       # copies, clears after 10 s
keepassxc-cli open "$KEEPASSXC_DB"                          # interactive shell: one unlock, many commands
```

The same `.kdbx` opens in the KeePassXC app (installed with the CLI) if you
want a window.

## SSH keys

`ssh-add ~/.ssh/id_ed25519` loads a key into OpenSSH's agent until you log
out. `SSH_AUTH_SOCK` is set by home-manager for bash. A key on the YubiKey
works through ssh's FIDO2 support (`ssh-keygen -t ed25519-sk`), with no agent
in between.

## sops with age

sops encrypts the values in a YAML, JSON or `.env` file so it can be
committed; age keys say who can open it. Make a key once per machine (on
harmonia, cadmus and Dionysus alike) and list its public half in the
repository's `.sops.yaml`:

```sh
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt    # prints the public key, age1...
age-keygen -y ~/.config/sops/age/keys.txt    # prints it again later
```

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/.*
    age: age1harmonia...,age1cadmus...,age1dionysus...
```

```sh
sops secrets/app.yaml                        # opens decrypted in $EDITOR, saves encrypted
sops updatekeys secrets/app.yaml             # after adding a key to .sops.yaml
```

sops finds `keys.txt` there by default (or at `$SOPS_AGE_KEY_FILE`).
`secrets-backup` includes it; another machine's key listed in `.sops.yaml`
can also still open the files.

## First run

```sh
bw login && bw-unlock
mkdir -p "$(dirname "$KEEPASSXC_DB")" && keepassxc-cli db-create -p "$KEEPASSXC_DB"
ssh-add                          # your default keys
export BAO_ADDR=https://bao.example.com && bao login
ykman info                       # with the key plugged in
```

## Backup: `secrets-backup`

`secrets-backup [DIR]` (a command on your PATH) writes `DIR/secrets-backup-<UTC time>.tar.gz.gpg`
(`DIR` defaults to `$HOME`). It includes whatever is reachable right now and
skips, with a warning, anything missing, locked or logged out:

| Part | What goes in | Needs |
| --- | --- | --- |
| `keepassxc/` | `$KEEPASSXC_DB` and every other `.kdbx` (and key file) next to it, as is (already encrypted) | a database there |
| `ssh/` | all of `~/.ssh`: keys, `config`, `known_hosts` (passphrase-protected keys stay protected) | a `~/.ssh` |
| `sops/keys.txt` | the age key sops decrypts with (`$SOPS_AGE_KEY_FILE` or `~/.config/sops/age/keys.txt`) | a key there |
| `pass/` | a pass store left from before, with its git history, if one is still there | `~/.local/share/password-store` or `~/.password-store` |
| `bitwarden.json` | `bw export --format json` (asks for the master password again) | `bw status` is `unlocked` |
| `gpg/` | public and secret keys, and the ownertrust | a secret key in the keyring |

The tarball is encrypted with a **passphrase** (gpg `--symmetric`, AES-256),
not with a gpg key, so it still opens if your keys are lost. `secrets-backup`
asks for it twice in the terminal and hands it to gpg through a pipe; nothing
caches it. The secret keys
inside keep their own key passphrase on top of that. Pick a strong backup
passphrase you can remember without this machine.

Plaintext (the Bitwarden export, unprotected SSH keys, the age key) only exists in a private `mktemp -d`
directory that is deleted when the function exits or is interrupted; the tar
stream goes straight into gpg, so no unencrypted archive is written.

YubiKey private keys and OATH seeds are not in the backup: they cannot leave
the device.

Restore:

```sh
d=$(mktemp -d) && gpg --pinentry-mode loopback -d secrets-backup-<time>.tar.gz.gpg | tar -xzf - -C "$d" && cd "$d"
gpg --pinentry-mode loopback --import gpg/secret-keys.asc && gpg --import-ownertrust gpg/ownertrust.txt
mkdir -p "$(dirname "$KEEPASSXC_DB")" && cp keepassxc/* "$(dirname "$KEEPASSXC_DB")"/
mkdir -p ~/.ssh && cp -a ssh/. ~/.ssh/ && chmod 700 ~/.ssh
[ -f sops/keys.txt ] && install -Dm600 sops/keys.txt ~/.config/sops/age/keys.txt
[ -d pass ] && cp -a pass ~/.local/share/password-store   # only if the backup had one
bw import bitwardenjson bitwarden.json   # then delete the plaintext: rm -rf "$d"
```
