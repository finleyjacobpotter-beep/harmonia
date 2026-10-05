# VPNs

WireGuard, OpenVPN and Proton VPN all run through NetworkManager
(`modules/nixos/vpn.nix`), so you can bring them up and down without root,
and the bar's network button shows which are up. No keys or configs live in
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

**Proton VPN**: run the Proton VPN app (`protonvpn-app`, in fuzzel, or
**Proton VPN app** in the network panel) and sign in; it keeps your login in
the GNOME keyring. The connections it makes are NetworkManager connections
named `ProtonVPN …` on the `proton0` device (WireGuard) or a `tun` device
(OpenVPN), and the bar counts them as Proton whichever protocol they use.
Its kill switch connections (`pvpn-*`) aren't tunnels and aren't listed.
Proton's own WireGuard or OpenVPN config files can also be imported as
above; name the connection `ProtonVPN …` to have the bar colour it as
Proton.

NetworkManager stores private keys and saved passwords in
`/etc/NetworkManager/system-connections/`, readable only by root.

## The bar

Each kind of VPN that is up adds a small asterisk beside the network icon,
stacked top to bottom, each its own colour:

| Asterisk | VPN |
|---|---|
| green | WireGuard |
| yellow | OpenVPN |
| purple | Proton VPN |
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
```

Tunnels that route all traffic (`AllowedIPs = 0.0.0.0/0`, OpenVPN's
`redirect-gateway`) need the firewall's reverse-path check set to `loose`,
which this module does.
