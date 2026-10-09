"""mkdocs hooks for the docs site (mkdocs.yml).

The pages in docs/ link to the Nix files they describe with relative paths
(../modules/nixos/fans.nix), which work when browsing the repository on
GitHub. mkdocs only publishes docs/, so those links would break on the site:
rewrite every relative link that leaves docs/ into a link to the same path on
GitHub's main branch.
"""

import posixpath
import re

LINK = re.compile(r"(\]\()([^)\s]+)(\))")


def on_page_markdown(markdown, page, config, files):
    repo = config["repo_url"].rstrip("/")
    page_dir = posixpath.dirname(page.file.src_uri)

    def rewrite(match):
        target = match.group(2)
        if re.match(r"^[a-z][a-z0-9+.-]*:|^#|^/", target):
            return match.group(0)
        path, sep, anchor = target.partition("#")
        # Relative to docs/; a result starting with ../ is outside docs/.
        resolved = posixpath.normpath(posixpath.join(page_dir, path))
        if not resolved.startswith("../"):
            return match.group(0)
        repo_path = resolved[len("../"):]
        url = f"{repo}/blob/main/{repo_path}" + (sep + anchor if sep else "")
        return match.group(1) + url + match.group(3)

    return LINK.sub(rewrite, markdown)
