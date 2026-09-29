#!/usr/bin/env bash
# Set up an Ubuntu desktop with Blender, Godot 4, their MCP servers and the
# GNOME Caffeine extension.
#
#   Blender       snap (published by the Blender Foundation)
#   Blender MCP   https://github.com/ahujasid/blender-mcp
#                 server: `uvx blender-mcp`, plus its addon enabled in Blender
#   Godot 4       latest stable editor from github.com/godotengine/godot,
#                 unpacked to /opt/godot and linked as /usr/local/bin/godot
#   Godot MCP     https://github.com/Coding-Solo/godot-mcp
#                 server: `npx @coding-solo/godot-mcp`
#   Caffeine      https://extensions.gnome.org/extension/517/caffeine/
#
# Run it as your normal user from a GNOME session (it asks for sudo when it
# needs it):
#   bash scripts/ubuntu-install.sh
#
# Safe to re-run: each step replaces what an earlier run installed.
# If the `claude` CLI is installed, both MCP servers are registered with it;
# otherwise the config to paste into your MCP client is printed at the end.
set -euo pipefail

CAFFEINE_UUID=caffeine@patapon.info
GODOT_DIR=/opt/godot
BLENDER_MCP_ADDON=https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py

die() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root (the script uses sudo itself)"
command -v apt-get >/dev/null || die "this script is for Ubuntu (apt not found)"
command -v snap >/dev/null || die "snapd is required (sudo apt install snapd)"

case $(uname -m) in
  x86_64) GODOT_ARCH=x86_64 ;;
  aarch64) GODOT_ARCH=arm64 ;;
  *) die "unsupported architecture $(uname -m)" ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- packages ---------------------------------------------------------------
step "Installing base packages"
sudo apt-get update
sudo apt-get install -y curl unzip jq

# The Godot MCP server runs on Node; older Ubuntu releases ship a Node too old
# for it, so fall back to the Node snap.
node_major=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
if [[ ${node_major:-0} -lt 18 ]]; then
  step "Installing Node.js"
  sudo apt-get install -y nodejs npm
  node_major=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
  if [[ ${node_major:-0} -lt 18 ]]; then
    sudo apt-get remove -y nodejs npm
    sudo snap install node --classic --channel=22
  fi
fi

# uv provides `uvx`, which runs the Blender MCP server.
if ! command -v uvx >/dev/null && [[ ! -x $HOME/.local/bin/uvx ]]; then
  step "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH=$HOME/.local/bin:$PATH

# --- Blender + Blender MCP ----------------------------------------------------
step "Installing Blender"
if snap list blender >/dev/null 2>&1; then
  sudo snap refresh blender || true
else
  sudo snap install blender --classic
fi

step "Installing and enabling the Blender MCP addon"
curl -fsSL "$BLENDER_MCP_ADDON" -o "$TMP/blender_mcp.py"
blender --background --python-expr "
import bpy
bpy.ops.preferences.addon_install(filepath='$TMP/blender_mcp.py', overwrite=True)
bpy.ops.preferences.addon_enable(module='blender_mcp')
bpy.ops.wm.save_userpref()
"

# --- Godot 4 + Godot MCP ------------------------------------------------------
step "Installing Godot 4"
release=$(curl -fsSL https://api.github.com/repos/godotengine/godot/releases/latest)
tag=$(jq -r .tag_name <<<"$release")
[[ $tag == 4.* ]] || die "latest Godot release is $tag, expected 4.x"
asset="Godot_v${tag}_linux.${GODOT_ARCH}.zip"
url=$(jq -r --arg a "$asset" '.assets[] | select(.name == $a) | .browser_download_url' <<<"$release")
[[ -n $url ]] || die "no $asset in Godot release $tag"
curl -fL --progress-bar "$url" -o "$TMP/godot.zip"
unzip -q "$TMP/godot.zip" -d "$TMP/godot"
sudo rm -rf "$GODOT_DIR"
sudo install -D -m 755 "$TMP/godot/Godot_v${tag}_linux.${GODOT_ARCH}" "$GODOT_DIR/godot"
sudo ln -sf "$GODOT_DIR/godot" /usr/local/bin/godot

sudo tee /usr/share/applications/godot.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Godot Engine
Comment=Godot $tag game engine editor
Exec=$GODOT_DIR/godot %f
Icon=applications-games
Terminal=false
Type=Application
Categories=Development;IDE;Game;
EOF
echo "Godot $tag installed at $GODOT_DIR/godot"

# --- register the MCP servers -------------------------------------------------
if command -v claude >/dev/null; then
  step "Registering the MCP servers with Claude Code"
  claude mcp remove blender -s user >/dev/null 2>&1 || true
  claude mcp remove godot -s user >/dev/null 2>&1 || true
  claude mcp add blender -s user -- uvx blender-mcp
  claude mcp add godot -s user -e GODOT_PATH="$GODOT_DIR/godot" -- npx -y @coding-solo/godot-mcp
  REGISTERED=1
fi

# --- Caffeine -----------------------------------------------------------------
step "Installing the Caffeine GNOME extension"
command -v gnome-shell >/dev/null || die "GNOME Shell not found; Caffeine needs Ubuntu's GNOME desktop"
shell_major=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
info=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$CAFFEINE_UUID&shell_version=$shell_major") \
  || die "no Caffeine release for GNOME Shell $shell_major"
curl -fsSL "https://extensions.gnome.org$(jq -r .download_url <<<"$info")" -o "$TMP/caffeine.zip"
gnome-extensions install --force "$TMP/caffeine.zip"

# `gnome-extensions enable` only works once the shell has loaded the extension,
# which on Wayland needs a new login, so also add it to the enabled list.
gnome-extensions enable "$CAFFEINE_UUID" 2>/dev/null || true
enabled=$(gsettings get org.gnome.shell enabled-extensions)
if [[ $enabled != *"'$CAFFEINE_UUID'"* ]]; then
  if [[ $enabled == "@as []" || $enabled == "[]" ]]; then
    gsettings set org.gnome.shell enabled-extensions "['$CAFFEINE_UUID']"
  else
    gsettings set org.gnome.shell enabled-extensions "${enabled%]}, '$CAFFEINE_UUID']"
  fi
fi

# --- done ---------------------------------------------------------------------
step "Done"
cat <<EOF
Blender:  $(blender --version 2>/dev/null | head -1)
Godot:    $("$GODOT_DIR/godot" --version 2>/dev/null || echo "$tag")

Next steps:
  - Log out and back in so GNOME loads Caffeine (the coffee cup in the top bar).
  - In Blender, open the sidebar (N) in the 3D viewport, go to the BlenderMCP
    tab and click "Connect to Claude" before using the Blender MCP server.
EOF

if [[ -z ${REGISTERED:-} ]]; then
  cat <<EOF
  - The claude CLI wasn't found, so add the MCP servers to your client's config:

    {
      "mcpServers": {
        "blender": { "command": "uvx", "args": ["blender-mcp"] },
        "godot": {
          "command": "npx",
          "args": ["-y", "@coding-solo/godot-mcp"],
          "env": { "GODOT_PATH": "$GODOT_DIR/godot" }
        }
      }
    }
EOF
fi
