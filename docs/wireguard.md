# WireGuard

WireGuard tunnels are NetworkManager connections (`modules/nixos/wireguard.nix`),
so you can bring them up and down without root. No keys or configs live in
this repo.

## Adding a tunnel

Import a standard `wg-quick` config. The connection is named after the file
(`wg0.conf` becomes `wg0`):

```sh
nmcli connection import type wireguard file ~/Downloads/wg0.conf
nmcli connection modify wg0 connection.autoconnect no   # optional: only on demand
rm ~/Downloads/wg0.conf                                  # NetworkManager keeps its own copy
```

NetworkManager stores the private key in `/etc/NetworkManager/system-connections/`,
readable only by root.

## The bar

The VPN icon on the eww bar shows how many tunnels are up (cyan when at
least one is). Click it to open the WireGuard panel. For each tunnel it
shows:

- its address
- while it's up: the peer endpoint, the time since the last handshake, and
  traffic received and sent

The **Connect** / **Disconnect** button next to each tunnel toggles it.
Click the icon again or `✕` to close the panel.

The endpoint and handshake come from `wg show`, which needs root. Wheel
users may run exactly `wg show all endpoints` and `wg show all latest-handshakes`
through sudo without a password. Neither prints keys.

## From the terminal

```sh
nmcli connection up wg0        # or: down
nmcli -f NAME,TYPE,DEVICE connection show
sudo wg show                   # full status
```

Tunnels that route all traffic (`AllowedIPs = 0.0.0.0/0`) need the firewall's
reverse-path check set to `loose`, which this module does.
