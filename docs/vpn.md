# VPNs

WireGuard and OpenVPN run through NetworkManager and openfortivpn through
its own systemd service (`modules/nixos/vpn.nix`), so you can bring them all
up and down without root, and the bar's network button shows which are up. No keys or configs live in
this repo.

## Adding a VPN

**WireGuard**: import a standard `wg-quick` config. The connection is named
after the file (`wg0.conf` becomes `wg0`):

```sh
nmcli connection import type wireguard file ~/Downloads/wg0.conf
nmcli connection modify wg0 connection.autoconnect no   # optional: only on demand
rm ~/Downloads/wg0.conf                                  # NetworkManager keeps its own copy
```

**OpenVPN**: import an `.ovpn` file the same way (NetworkManager's OpenVPN
plugin is installed). Certificates it references are copied into
`~/.cert/nm-openvpn/`:

```sh
nmcli connection import type openvpn file ~/Downloads/client.ovpn
```

If the server wants a username and password, either save them once,

```sh
nmcli connection modify client +vpn.data 'username=you, password-flags=0' vpn.secrets 'password=…'
```

or leave them out: **Connect** on the bar then opens a terminal that asks
for them (`nmcli --ask`), since the desktop has no NetworkManager password
dialog. Plain `openvpn` is installed too; a tunnel started with
`sudo openvpn --config client.ovpn` still shows on the bar, without a
Connect/Disconnect button.

**openfortivpn** (Fortinet SSL VPN): NetworkManager's plugin for it was
dropped from nixpkgs as insecure, so each VPN is a config file run by
openfortivpn's own `openfortivpn@NAME` service. Write
`/etc/openfortivpn/NAME.conf` (see `man openfortivpn`) and keep it root's
alone if it holds the password:

```sh
sudo tee /etc/openfortivpn/work.conf >/dev/null <<'EOF'
host = vpn.example.com
port = 443
username = you
password = …
trusted-cert = <sha256 the first connection prints>
EOF
sudo chmod 600 /etc/openfortivpn/work.conf
```

The network panel lists every `*.conf` there, and **Connect** /
**Disconnect** start and stop `openfortivpn@NAME`, allowed without a
password for wheel users (polkit). The service can't ask for a password or
one-time code, so a VPN that needs one at each login is run by hand
instead: `sudo openfortivpn -c /etc/openfortivpn/work.conf` in a terminal.
It still shows on the bar while it's up, without a button.

NetworkManager stores private keys and saved passwords in
`/etc/NetworkManager/system-connections/`, readable only by root.

## The bar

Each kind of VPN whose interface is up adds a small asterisk beside the
network icon, after a space, stacked top to bottom in this order, each its
own colour. The asterisks follow the interfaces themselves (`wg*`, `tun*`,
`ppp*`), so a tunnel started by hand (`wg-quick up`, `sudo openvpn`,
`sudo openfortivpn`) shows too. At most four fit, so a fifth or sixth
kind (only possible with the microVMs' VPNs) shows only in the tooltip and
the panel:

| Asterisk | VPN |
|---|---|
| green | WireGuard |
| yellow | OpenVPN |
| purple | openfortivpn |
| blue | another NetworkManager VPN (e.g. OpenConnect) |
| orange | Nike's VPN (inside the VM) |
| cyan | Zelus's VPN (inside the VM) |

The stack keeps its width whether any are up or not, so the bar doesn't
shift. Hover the network button for the names; click it to open the network
panel, which lists every VPN first, then the interfaces. For each VPN:

- its name, with its asterisk while it is up
- its kind, device and address
- while it's up: the server, the time since the last WireGuard handshake,
  and traffic received and sent

The **Connect** / **Disconnect** button next to each one toggles it. Click
the network button again or `✕` to close the panel.

The WireGuard endpoint and handshake come from `wg show`, which needs root.
Wheel users may run exactly `wg show all endpoints` and
`wg show all latest-handshakes` through sudo without a password. Neither
prints keys.

## From the terminal

```sh
nmcli connection up wg0        # or: down
nmcli -f NAME,TYPE,DEVICE connection show
sudo wg show                   # full WireGuard status
systemctl start openfortivpn@work   # or: stop, status
journalctl -u openfortivpn@work     # why it didn't connect
```

Tunnels that route all traffic (`AllowedIPs = 0.0.0.0/0`, OpenVPN's
`redirect-gateway`, openfortivpn's default routes) need the firewall's reverse-path check set to `loose`,
which this module does.
