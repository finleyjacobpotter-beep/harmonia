#!/usr/bin/env python3
"""Set up an Ubuntu desktop with Blender, Godot 4, their MCP servers and the
GNOME Caffeine extension.

  Blender       snap (published by the Blender Foundation)
  Blender MCP   https://github.com/ahujasid/blender-mcp
                server: `uvx blender-mcp`, plus its addon enabled in Blender
  Godot 4       latest stable editor from github.com/godotengine/godot,
                unpacked to /opt/godot and linked as /usr/local/bin/godot
  Godot MCP     https://github.com/Coding-Solo/godot-mcp
                server: `npx @coding-solo/godot-mcp`
  Tau           https://github.com/huggingface/tau
                Hugging Face's terminal coding agent, `pipx install tau-ai`
  Caffeine      https://extensions.gnome.org/extension/517/caffeine/

Run it as your normal user from a GNOME session (it asks for sudo when it
needs it):
  python3 scripts/ubuntu-install.py

Safe to re-run: each step replaces what an earlier run installed.
If the `claude` CLI is installed, both MCP servers are registered with it;
otherwise the config to paste into your MCP client is printed at the end.
"""

import ast
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

CAFFEINE_UUID = "caffeine@patapon.info"
GODOT_DIR = "/opt/godot"
BLENDER_MCP_ADDON = "https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py"
LOCAL_BIN = Path.home() / ".local/bin"


def die(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def step(message):
    print(f"\n==> {message}", flush=True)


def run(*args, **kwargs):
    subprocess.run(args, check=True, **kwargs)


def quiet(*args):
    """Run a command, hiding its output, and say whether it worked."""
    null = subprocess.DEVNULL
    return subprocess.run(args, stdout=null, stderr=null).returncode == 0


def output(*args):
    """A command's output, or "" if it is missing or fails."""
    try:
        return subprocess.run(args, capture_output=True, text=True).stdout.strip()
    except OSError:
        return ""


def fetch(url):
    with urllib.request.urlopen(url) as response:
        return response.read()


def major(version_output):
    match = re.search(r"[0-9]+", version_output)
    return int(match.group(0)) if match else 0


def install_packages():
    step("Installing base packages")
    run("sudo", "apt-get", "update")
    run("sudo", "apt-get", "install", "-y", "curl", "unzip", "jq", "pipx")

    # The Godot MCP server runs on Node; older Ubuntu releases ship a Node
    # too old for it, so fall back to the Node snap.
    if major(output("node", "--version")) < 18:
        step("Installing Node.js")
        run("sudo", "apt-get", "install", "-y", "nodejs", "npm")
        if major(output("node", "--version")) < 18:
            run("sudo", "apt-get", "remove", "-y", "nodejs", "npm")
            run("sudo", "snap", "install", "node", "--classic", "--channel=22")

    # uv provides `uvx`, which runs the Blender MCP server.
    if not shutil.which("uvx") and not os.access(LOCAL_BIN / "uvx", os.X_OK):
        step("Installing uv")
        run("sh", input=fetch("https://astral.sh/uv/install.sh"))
    os.environ["PATH"] = f"{LOCAL_BIN}{os.pathsep}{os.environ.get('PATH', '')}"


def install_blender(tmp):
    step("Installing Blender")
    if quiet("snap", "list", "blender"):
        subprocess.run(["sudo", "snap", "refresh", "blender"])
    else:
        run("sudo", "snap", "install", "blender", "--classic")

    step("Installing and enabling the Blender MCP addon")
    addon = tmp / "blender_mcp.py"
    addon.write_bytes(fetch(BLENDER_MCP_ADDON))
    run("blender", "--background", "--python-expr", f"""
import bpy
bpy.ops.preferences.addon_install(filepath={str(addon)!r}, overwrite=True)
bpy.ops.preferences.addon_enable(module='blender_mcp')
bpy.ops.wm.save_userpref()
""")


def install_godot(tmp, arch):
    step("Installing Godot 4")
    release = json.loads(fetch("https://api.github.com/repos/godotengine/godot/releases/latest"))
    tag = release["tag_name"]
    if not tag.startswith("4."):
        die(f"latest Godot release is {tag}, expected 4.x")
    binary = f"Godot_v{tag}_linux.{arch}"
    url = next((a["browser_download_url"] for a in release["assets"] if a["name"] == f"{binary}.zip"), None)
    if not url:
        die(f"no {binary}.zip in Godot release {tag}")
    print(f"Downloading {url}", file=sys.stderr, flush=True)
    archive = tmp / "godot.zip"
    archive.write_bytes(fetch(url))
    with zipfile.ZipFile(archive) as z:
        z.extractall(tmp / "godot")
    run("sudo", "rm", "-rf", GODOT_DIR)
    run("sudo", "install", "-D", "-m", "755", str(tmp / "godot" / binary), f"{GODOT_DIR}/godot")
    run("sudo", "ln", "-sf", f"{GODOT_DIR}/godot", "/usr/local/bin/godot")

    desktop = f"""[Desktop Entry]
Name=Godot Engine
Comment=Godot {tag} game engine editor
Exec={GODOT_DIR}/godot %f
Icon=applications-games
Terminal=false
Type=Application
Categories=Development;IDE;Game;
"""
    run("sudo", "tee", "/usr/share/applications/godot.desktop", input=desktop, text=True, stdout=subprocess.DEVNULL)
    print(f"Godot {tag} installed at {GODOT_DIR}/godot")
    return tag


def install_tau():
    step("Installing Tau")
    # Tau needs Python 3.12+. Ubuntu 24.04 and later ship it; on older
    # releases pipx uses a 3.12 fetched by uv instead.
    python = "python3"
    if not quiet("python3", "-c", "import sys; sys.exit(sys.version_info < (3, 12))"):
        run("uv", "python", "install", "3.12")
        python = output("uv", "python", "find", "3.12")
    run("pipx", "install", "--force", "--python", python, "tau-ai")
    run("pipx", "ensurepath", stdout=subprocess.DEVNULL)


def register_mcp_servers():
    if not shutil.which("claude"):
        return False
    step("Registering the MCP servers with Claude Code")
    quiet("claude", "mcp", "remove", "blender", "-s", "user")
    quiet("claude", "mcp", "remove", "godot", "-s", "user")
    run("claude", "mcp", "add", "blender", "-s", "user", "--", "uvx", "blender-mcp")
    run("claude", "mcp", "add", "godot", "-s", "user", "-e", f"GODOT_PATH={GODOT_DIR}/godot", "--", "npx", "-y", "@coding-solo/godot-mcp")
    return True


def install_caffeine(tmp):
    step("Installing the Caffeine GNOME extension")
    if not shutil.which("gnome-shell"):
        die("GNOME Shell not found; Caffeine needs Ubuntu's GNOME desktop")
    shell = major(output("gnome-shell", "--version"))
    query = urllib.parse.urlencode({"uuid": CAFFEINE_UUID, "shell_version": shell})
    try:
        info = json.loads(fetch(f"https://extensions.gnome.org/extension-info/?{query}"))
    except (OSError, ValueError):
        die(f"no Caffeine release for GNOME Shell {shell}")
    archive = tmp / "caffeine.zip"
    archive.write_bytes(fetch("https://extensions.gnome.org" + info["download_url"]))
    run("gnome-extensions", "install", "--force", str(archive))

    # `gnome-extensions enable` only works once the shell has loaded the
    # extension, which on Wayland needs a new login, so also add it to the
    # enabled list.
    quiet("gnome-extensions", "enable", CAFFEINE_UUID)
    enabled = output("gsettings", "get", "org.gnome.shell", "enabled-extensions")
    extensions = [] if enabled.startswith("@as") else list(ast.literal_eval(enabled or "[]"))
    if CAFFEINE_UUID not in extensions:
        extensions.append(CAFFEINE_UUID)
        run("gsettings", "set", "org.gnome.shell", "enabled-extensions", str(extensions))


def main():
    if os.geteuid() == 0:
        die("run as your normal user, not root (the script uses sudo itself)")
    if not shutil.which("apt-get"):
        die("this script is for Ubuntu (apt not found)")
    if not shutil.which("snap"):
        die("snapd is required (sudo apt install snapd)")
    arch = {"x86_64": "x86_64", "aarch64": "arm64"}.get(platform.machine())
    if not arch:
        die(f"unsupported architecture {platform.machine()}")

    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp = Path(tmp_dir)
        install_packages()
        install_blender(tmp)
        tag = install_godot(tmp, arch)
        install_tau()
        registered = register_mcp_servers()
        install_caffeine(tmp)

    step("Done")
    blender = output("blender", "--version").splitlines()
    print(f"""Blender:  {blender[0] if blender else ""}
Godot:    {output(f"{GODOT_DIR}/godot", "--version") or tag}
Tau:      {LOCAL_BIN}/tau

Next steps:
  - Log out and back in so GNOME loads Caffeine (the coffee cup in the top bar).
  - In Blender, open the sidebar (N) in the 3D viewport, go to the BlenderMCP
    tab and click "Connect to Claude" before using the Blender MCP server.
  - Run `tau` and use /login to connect a model provider (Hugging Face,
    Anthropic, OpenAI, OpenRouter or a local model).""")

    if not registered:
        print(f"""  - The claude CLI wasn't found, so add the MCP servers to your client's config:

    {{
      "mcpServers": {{
        "blender": {{ "command": "uvx", "args": ["blender-mcp"] }},
        "godot": {{
          "command": "npx",
          "args": ["-y", "@coding-solo/godot-mcp"],
          "env": {{ "GODOT_PATH": "{GODOT_DIR}/godot" }}
        }}
      }}
    }}""")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        die(f"{' '.join(map(str, e.cmd))} failed (exit {e.returncode})")
    except KeyboardInterrupt:
        sys.exit(130)
