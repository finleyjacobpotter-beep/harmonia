"""Run the Mythic C2 stack on Zelus (finley's isolated red-team lab VM).

Mythic (https://github.com/its-a-feature/Mythic) is an open-source
command-and-control framework; running the server here lets implants from
his lab call back to it. Mythic ships as a docker-compose stack driven by its
own `mythic-cli`, so this just clones the repo into a persistent folder,
builds `mythic-cli` once, and passes the rest straight through to it.

Usage: mythic start | stop | status | logs ... | <any mythic-cli command>
       mythic update                 git pull in the repo, then rebuild

The repo lives in ~/mythic (override with MYTHIC_DIR). Set MYTHIC_REF to pin
a tag or commit; empty means the default branch.
"""

import os
import subprocess
import sys

REPO_URL = "https://github.com/its-a-feature/Mythic"


def run(cmd: list, **kw) -> subprocess.CompletedProcess:
    print("+ " + " ".join(cmd), file=sys.stderr)
    return subprocess.run(cmd, check=True, **kw)


def ensure_repo(repo: str, ref: str) -> None:
    if not os.path.isdir(os.path.join(repo, ".git")):
        run(["git", "clone", REPO_URL, repo])
    if ref:
        run(["git", "-C", repo, "fetch", "--tags", "origin", ref])
        run(["git", "-C", repo, "checkout", ref])


def ensure_cli(repo: str) -> None:
    if not os.path.isfile(os.path.join(repo, "mythic-cli")):
        # Mythic's Makefile builds mythic-cli inside a golang container.
        run(["make"], cwd=repo)


def main() -> int:
    repo = os.environ.get("MYTHIC_DIR") or os.path.expanduser("~/mythic")
    ref = os.environ.get("MYTHIC_REF", "")
    args = sys.argv[1:]

    ensure_repo(repo, ref)

    if args[:1] == ["update"]:
        run(["git", "-C", repo, "pull", "--ff-only"])
        run(["make"], cwd=repo)
        return 0

    ensure_cli(repo)
    if not args:
        args = ["status"]
    return subprocess.run([os.path.join(repo, "mythic-cli"), *args], cwd=repo).returncode


if __name__ == "__main__":
    sys.exit(main())
