"""Drive the Mythic C2 stack on Zelus (finley's isolated red-team lab VM).

Mythic (https://github.com/its-a-feature/Mythic) is an open-source
command-and-control framework. Unlike the other lab stacks, Mythic does not
ship a static compose file: its own `mythic-cli` generates the (podman-)compose
project and brings it up. So this clones the repo into a persistent folder,
builds `mythic-cli` once, and passes the rest straight through to it. The
`mythic` systemd service (zelus/labs.nix) calls `ensure` then `start`/`stop`;
you can also run it by hand over `ssh zelus`.

Usage: mythic ensure                 clone into $MYTHIC_DIR and build mythic-cli
       mythic start | stop | status  the matching mythic-cli command
       mythic update                 git pull, then rebuild
       mythic <any mythic-cli args>  e.g. logs mythic_server, install github <url>

$MYTHIC_DIR is where the repo lives (the service sets it to /var/lib/mythic).
Set $MYTHIC_REF to pin a tag or commit; empty means the default branch.
"""

import os
import subprocess
import sys

REPO_URL = "https://github.com/its-a-feature/Mythic"


def run(cmd: list, **kw) -> None:
    print("+ " + " ".join(cmd), file=sys.stderr)
    subprocess.run(cmd, check=True, **kw)


def repo_dir() -> str:
    return os.environ.get("MYTHIC_DIR") or os.path.expanduser("~/mythic")


def ensure(repo: str, ref: str) -> None:
    if not os.path.isdir(os.path.join(repo, ".git")):
        run(["git", "clone", REPO_URL, repo])
    if ref:
        run(["git", "-C", repo, "fetch", "--tags", "origin", ref])
        run(["git", "-C", repo, "checkout", ref])
    if not os.path.isfile(os.path.join(repo, "mythic-cli")):
        # Mythic's Makefile builds mythic-cli inside a golang container.
        run(["make"], cwd=repo)


def main() -> int:
    repo = repo_dir()
    ref = os.environ.get("MYTHIC_REF", "")
    args = sys.argv[1:] or ["status"]

    if args == ["ensure"]:
        ensure(repo, ref)
        return 0

    if args[:1] == ["update"]:
        ensure(repo, ref)
        run(["git", "-C", repo, "pull", "--ff-only"])
        run(["make"], cwd=repo)
        return 0

    ensure(repo, ref)
    return subprocess.run([os.path.join(repo, "mythic-cli"), *args], cwd=repo).returncode


if __name__ == "__main__":
    sys.exit(main())
