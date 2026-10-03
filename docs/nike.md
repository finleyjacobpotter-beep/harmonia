# Nike and containers

## Nike (microVM)

Nike is a small NixOS VM for VPN work and OSCP pentesting practice, built with
[microvm.nix](https://github.com/microvm-nix/microvm.nix) on QEMU/KVM as part
of the host's own build. The guest is [`nike/default.nix`](../nike/default.nix);
the host side (network, shared folders, `ssh nike`) is
[`modules/nixos/nike.nix`](../modules/nixos/nike.nix).

| | |
| --- | --- |
| Packages | bash, neovim, tmux, ranger, openssh, python3, openvpn, nmap, plus the OSCP toolset ([`nike/tools.nix`](../nike/tools.nix)) |
| Login | user `k`, password `k` (in `wheel`, so `sudo` works) |
| Resources | 4 vCPUs, 6 GiB RAM (headroom for the lab containers) |
| Address | `10.20.0.2`, host side `10.20.0.1` on the `vm-nike` tap |
| Shared folder | `~/nike-share` on the host is `~/share` on Nike, read-write |
| Persistent | `/home` (16 GiB) and `/var` (24 GiB, holds the podman images) in `/var/lib/microvms/nike` |

Everything else (the root filesystem) is a tmpfs and starts fresh on every
boot. Nike reads the host's `/nix/store` read-only, so it costs no extra disk
for packages.

### Using it

It doesn't start at boot:

```sh
sudo systemctl start microvm@nike     # stop / restart / status work too
ssh nike                               # password k
```

`Super+o v` opens a terminal with `ssh nike`. The first start creates the two
disk images, so it takes a little longer.

Inside, bash, tmux, neovim and ranger are the same home-manager configs as
on the host ([`home/`](../home)), with the same keys, aliases and plugins.
The only difference is the colour: orange is the primary colour instead of
pink ([`nike/palette.nix`](../nike/palette.nix)), so you can always tell which
machine a shell is on. tmux on Nike uses the same `Ctrl+Space` prefix: inside
a host tmux, press it twice to reach Nike's.

### VPN

Put your `.ovpn` file in `~/nike-share` on the host, then on Nike:

```sh
sudo openvpn --config ~/share/client.ovpn
```

(in a tmux window, or add `--daemon`). The bar's Nike badge turns green
(**vpn**) once Nike's traffic leaves through the tunnel; see
[the bar](bar.md#nike). A config without `redirect-gateway` brings the tunnel
up without routing the internet through it, and the badge stays orange
(**no vpn**). DNS goes to Quad9 (`9.9.9.9`) unless the VPN config changes it;
with a full tunnel those queries go through the VPN too.

### Network

Nike has its own tap interface with a `/32` route each way, and the host
NATs its traffic out through whatever the host is using (Wi-Fi, ethernet or
a WireGuard tunnel). Nothing on your LAN can reach Nike; only the host can
(`ssh nike`). The tap is configured by systemd-networkd and NetworkManager
leaves it alone; everything else stays with NetworkManager.

### Shared folder

`~/nike-share` is a virtiofs share, so files keep their owner: `k` on Nike
and your user on the host are both uid 1000. If your host user has a
different uid (`id -u`), change `uid` in `nike/default.nix` to match.

### Changing it

Edit `nike/default.nix` (packages go in `environment.systemPackages`) and
`rebuild`. A running Nike restarts with the new config. To start over with
empty disks:

```sh
sudo systemctl stop microvm@nike
sudo rm /var/lib/microvms/nike/{home,var}.img
```

Nike's password is in `nike/default.nix` as a hash; make a new one with
`openssl passwd -6 newpassword`.

## Pentesting lab (OSCP)

Nike is also the OSCP study box, so it ships the toolset
([`nike/tools.nix`](../nike/tools.nix)) and two lab stacks
([`nike/labs.nix`](../nike/labs.nix)). It is deliberately walled off: its own
tap network, reachable only from the host, and nothing listens outside
localhost. Use it against machines you are authorised to test (your own labs,
Hack The Box, the OSCP exam).

### Tools

The toolset tracks the [0xsyr0/oscp](https://github.com/0xsyr0/oscp)
cheat-sheet: every tool on that list that is packaged in nixpkgs is here.

A `python3` with **impacket** (the `impacket-*` scripts are on `PATH`),
**pwntools**, ldap3, dnspython and pycryptodome, plus **lsassy**, **pypykatz**,
**bloodyAD** and **dploot** for AD and credential looting, and **penelope**
(the reverse-shell handler). Grouped in `nike/tools.nix`:

- **Enumeration**: nmap, masscan, rustscan, netdiscover, arp-scan, nbtscan,
  snmpwalk (net-snmp), onesixtyone, dnsrecon, dnsenum, fierce, dig/host.
- **SMB / Windows**: smbclient and rpcclient (samba), smbmap, smbclient-ng,
  enum4linux-ng, netexec (`nxc`), responder.
- **Web**: gobuster, feroxbuster, ffuf, dirb, wfuzz, nikto, nuclei, whatweb,
  cewl, sqlmap, jwt-cli (JSON Web Tokens).
- **WordPress**: `wp-enum` (our own free enumerator, below) and WPProbe, plus
  nikto and nuclei's WordPress templates.
- **Exploitation**: metasploit, searchsploit (exploitdb), PayloadsAllTheThings.
- **Passwords**: hashcat (+utils), john, hydra, medusa, hashid, haiti, crunch,
  username-anarchy, KeePwn.
- **Active Directory**: evil-winrm, certipy, kerbrute, donpapi, coercer,
  adidnsdump, pretender, mimikatz, powersploit, powershell, pyWhisker,
  rusthound-ce (BloodHound CE collector).
- **Pivoting**: ligolo-ng, chisel, socat, proxychains-ng, sshpass, stunnel,
  xfreerdp (freerdp).
- **Post-exploitation / privesc**: linux-exploit-suggester, pspy,
  firefox_decrypt.
- **Shells / RE / forensics**: netcat (`nc`), rlwrap, gdb, radare2, ltrace,
  binwalk, exiftool, steghide, foremost.
- **Wordlists**: SecLists, linked at `/usr/share/wordlists` and
  `/usr/share/seclists` (and `$WORDLISTS`); PayloadsAllTheThings at
  `/usr/share/payloadsallthethings`.

Only free packages are included. `wpscan` is unfree (the WPScan Public Source
License is non-commercial), so instead of enabling it, Nike ships free
WordPress tooling:

- **`wp-enum`** ([`nike/wp-enum.py`](../nike/wp-enum.py)) — a small enumerator
  that covers what WPScan is usually reached for first, over HTTP only (it
  reads, it doesn't exploit): the core version, users (REST API, then the
  `?author=N` redirect) and installed plugins/themes, plus a few interesting
  files. Point `-p`/`-t` at a wordlist for a wider plugin/theme sweep:
  ```sh
  wp-enum http://10.10.10.10/
  wp-enum https://blog.target/ -p $WORDLISTS/CMS/wp-plugins.fuzz.txt --insecure
  ```
- **WPProbe** (`wpprobe`) — a maintained, MIT-licensed plugin and
  vulnerability scanner.
- **nikto** and **nuclei** (its `http/cves` and WordPress templates) round
  these out.

If you do want WPScan itself on your own box, add `"wpscan"` to the
`allowUnfreePredicate` list in `hosts/harmonia/default.nix` and `wpscan` to
`nike/tools.nix`, then `rebuild` — but note that bakes a non-commercial
dependency into the flake.

### Tools not in nixpkgs

A few things on the 0xsyr0/oscp list aren't packaged in nixpkgs. They aren't
dropped — they just aren't baked into the image, because most of them either
run **on the target** (Windows `.exe`/`.ps1` payloads you drop onto the victim,
not on Nike) or are single scripts easier to pull fresh. Grab them into
`~/share` (persists, visible on the host) when a box needs them:

- **Drop-on-target payloads** — PEASS-ng (`linpeas.sh`, `winPEASx64.exe`),
  Ghostpack compiled binaries (Rubeus, Certify, Seatbelt), SharpHound.exe,
  nanodump, RunasCs, powercat, WESNG, Watson, Sherlock, JAWS, PrivescCheck.
  These execute on the victim, so fetch the release/binary and serve it (e.g.
  `python3 -m http.server` from `~/share`); don't install them on Nike.
  ```sh
  # examples, run inside Nike
  curl -LO https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
  git clone https://github.com/r3motecontrol/Ghostpack-CompiledBinaries ~/share/ghostpack
  ```
- **Python/CLI tools** — JWT_Tool, PKINITtools, krbrelayx, PassTheCert,
  PowerView.py, CUPP, bopscrk, LaZagne. Install per-engagement with pipx (it's
  on `PATH` via the python env) or clone and run:
  ```sh
  pipx install git+https://github.com/ticarpi/jwt_tool
  git clone https://github.com/dirkjanm/krbrelayx ~/share/krbrelayx
  ```
- **PHP gadget generators** — PHPGGC, PHP Filter Chain Generator. Clone when a
  PHP target needs them:
  ```sh
  git clone https://github.com/ambionics/phpggc ~/share/phpggc
  ```

If you reach for one of these every time, add it to `nike/tools.nix` with
`fetchFromGitHub` (for a script/binary) or as an overlay package, and
`rebuild`.

### Lab services (podman-compose)

Two [podman-compose](https://github.com/containers/podman-compose) stacks run
as systemd services. Neither starts at boot (the containers are heavy); bring
one up when you need it:

```sh
sudo systemctl start ligolo-ng     # or: stop
sudo systemctl start bloodhound
```

- **ligolo-ng** ([`/etc/nike/ligolo-ng/compose.yml`](../nike/labs.nix)): the
  pivot proxy, run from a local image built from the same `ligolo-proxy`
  binary (nothing is pulled). It uses the host network and a TUN device and
  listens on `:11601` for agents, with a self-signed certificate. Its console
  is interactive, so attach to it to drive it:
  ```sh
  sudo podman attach nike-ligolo-proxy    # Ctrl-p Ctrl-q to detach
  ```
- **bloodhound** ([`/etc/nike/bloodhound/compose.yml`](../nike/labs.nix)):
  BloodHound CE — Postgres, Neo4j and the web UI, modelled on SpecterOps' own
  compose file. The images are pulled on first start. Everything binds to
  localhost, so reach the UI over an SSH tunnel from the host:
  ```sh
  ssh -L 8080:127.0.0.1:8080 nike        # then open http://localhost:8080
  ```
  The default login is `admin` / the password printed in
  `sudo podman logs nike-bloodhound` on first run; Neo4j is
  `neo4j` / `bloodhoundcommunityedition`. Collect graph data on targets with
  the bundled `bloodhound-python` and upload the ZIP in the UI.

The container images and volumes live on Nike's `/var`, which is sized for
them. `podman` has a `docker` alias here, so `docker compose` muscle memory
works too.

## Containers (host)

On the host, containers use rootless **podman** (with `podman-compose` and
**buildah**); there is no Docker daemon and no `docker` alias.

## Plain QEMU

There is no libvirt or virt-manager. QEMU itself stays installed for one-off
VMs, and your user is in the `kvm` group, so this works without root:

```sh
qemu-img create -f qcow2 disk.qcow2 20G
qemu-system-x86_64 -enable-kvm -m 4G -smp 2 -cpu host \
  -drive file=disk.qcow2,if=virtio -cdrom installer.iso
```
