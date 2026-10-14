# Secrets

Local secrets tooling lives in `home/secrets.nix` (user side) and
`modules/nixos/secrets.nix` (pcscd and the YubiKey udev rules).

The dash's secrets tile (`u`, [the dash](bar.md#tiles)) shows what is
unlocked or loaded right now (the Bitwarden session, ssh-agent's keys,
passphrases gpg-agent has cached, a YubiKey) with buttons to lock or forget
each, and when `secrets-backup` last ran.

| Tool | Command | Notes |
| --- | --- | --- |
| Bitwarden CLI | `bw` | the vault on `harmonia.bitwarden.server`; `bw-unlock` / `bw-lock` keep a session for the shell and the calendar sync |
| OpenSSH ssh-agent | `ssh-add` | holds SSH keys (`$XDG_RUNTIME_DIR/ssh-agent`); gnome-keyring's SSH agent is off |
| GnuPG | `gpg` | for the YubiKey and the backup; no gpg-agent setup, so it backs neither passwords nor SSH |
| YubiKey Manager | `ykman` | talks to the key through pcscd; gpg's scdaemon does too (`disable-ccid`) |
| OpenBao CLI | `bao` | set `BAO_ADDR` to your server, then `bao login` |
| age | `age`, `age-keygen` | the key sops encrypts to, at `~/.config/sops/age/keys.txt` |
| sops | `sops` | edits files kept encrypted in a repository |

## Bitwarden

**Bitwarden (`bw`) is the vault**: anything you also want on your phone or
another machine, and anything a background job needs (the calendar sync
reads its CalDAV password from here), because `bw` can stay unlocked for the
session. Firefox has the Bitwarden add-on for the same vault
([firefox.md](firefox.md)). `bw` keeps an encrypted copy of the vault in
`~/.config/Bitwarden CLI`, so it can read items offline once unlocked; edits
need the server, and `bw sync` fetches changes.

**The server is `harmonia.bitwarden.server`**, set to
`https://vault.iojoi.cc` in `home/default.nix` (harmonia and cadmus;
Dionysus keeps bitwarden.com unless its home sets it too). Each rebuild runs
`bw config server` with it, before you `bw login`, and gives the Firefox
add-on the same server ([firefox.md](firefox.md)). bw won't change servers
while logged in to another one: the rebuild then warns, and `bw logout`
followed by another rebuild switches it. `bw config server` shows the one in
use.

```sh
# Log in once, then unlock per session
bw login
bw-unlock                              # sets BW_SESSION here, in new shells and for the calendar sync
bw get password calendar/caldav
bw-lock                                # or log out
```

Secrets that should never sit on someone else's server (recovery codes, the
Bitwarden master password and 2FA recovery code, disk and backup
passphrases) can go in a file encrypted with sops and your age key
([below](#sops-with-age)), kept wherever you like; `secrets-backup` saves
the age key that opens it.

There is no KeePassXC: its CLI can't import a Bitwarden export into a
`.kdbx` (`keepassxc-cli import` only reads KeePass XML), so it couldn't hold
an offline copy of the vault, and `secrets-backup` already keeps one.

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
ssh-add                          # your default keys
export BAO_ADDR=https://bao.example.com && bao login
ykman info                       # with the key plugged in
```

## Backup: `secrets-backup`

`secrets-backup [DIR]` (a command on your PATH; `--help` lists its options)
writes `DIR/secrets-backup-<UTC time>.tar.gz.gpg` (`DIR` defaults to `$HOME`). It includes whatever is reachable right now and
skips, with a warning, anything missing, locked or logged out:

| Part | What goes in | Needs |
| --- | --- | --- |
| `ssh/` | all of `~/.ssh`: keys, `config`, `known_hosts` (passphrase-protected keys stay protected) | a `~/.ssh` |
| `sops/keys.txt` | the age key sops decrypts with (`$SOPS_AGE_KEY_FILE` or `~/.config/sops/age/keys.txt`) | a key there |
| `pass/` | a pass store left from before, with its git history, if one is still there | `~/.local/share/password-store` or `~/.password-store` |
| `bitwarden.json` | `bw export --format json` (asks for the master password again) | an unlocked vault: `BW_SESSION`, or the session `bw-unlock` left in `$XDG_RUNTIME_DIR` (so a shell opened before the unlock works too) |

The tarball is encrypted with a **passphrase** (gpg `--symmetric`, AES-256),
not with a gpg key, so it opens with nothing but that passphrase. `secrets-backup`
asks for it twice in the terminal and hands it to gpg through a pipe; nothing
caches it. Pick a strong backup passphrase you can remember without this
machine.

gpg keys are not in the backup: no gpg identity is kept, and gpg is here only
to encrypt the backup and to talk to the YubiKey.

Plaintext (the Bitwarden export, unprotected SSH keys, the age key) only exists in a private `mktemp -d`
directory that is deleted when the function exits or is interrupted; the tar
stream goes straight into gpg, so no unencrypted archive is written.

YubiKey private keys and OATH seeds are not in the backup: they cannot leave
the device.

Restore:

```sh
d=$(mktemp -d) && gpg --pinentry-mode loopback -d secrets-backup-<time>.tar.gz.gpg | tar -xzf - -C "$d" && cd "$d"
mkdir -p ~/.ssh && cp -a ssh/. ~/.ssh/ && chmod 700 ~/.ssh
[ -f sops/keys.txt ] && install -Dm600 sops/keys.txt ~/.config/sops/age/keys.txt
[ -d pass ] && cp -a pass ~/.local/share/password-store   # only if the backup had one
bw import bitwardenjson bitwarden.json   # then delete the plaintext: rm -rf "$d"
```
