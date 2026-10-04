"""wp-enum: a small, free WordPress enumerator for the OSCP box.

It covers the parts of WPScan people reach for first, without the non-free
WPScan package: the core version, users, and installed plugins/themes, plus a
few commonly interesting files. It only reads the target over HTTP(S); it does
not exploit anything.

    wp-enum http://10.10.10.10
    wp-enum https://blog.target/ -p ~/share/plugins.txt --insecure

For the full plugin/vulnerability database, WPProbe (`wpprobe`) and nuclei's
WordPress templates are also on PATH.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from urllib.parse import urljoin, urlparse

import requests
from requests.packages import urllib3

# A short list of very common plugins/themes to probe when the REST API is
# closed. A real run should point -p/-t at a wordlist (SecLists has several).
COMMON_PLUGINS = [
    "akismet", "jetpack", "contact-form-7", "woocommerce", "elementor",
    "yoast-seo", "wordpress-seo", "wpforms-lite", "classic-editor",
    "wordfence", "all-in-one-wp-migration", "duplicator", "wp-file-manager",
    "really-simple-ssl", "updraftplus", "mailchimp-for-wp", "redirection",
]
COMMON_THEMES = [
    "twentytwentyone", "twentytwentytwo", "twentytwentythree",
    "twentytwentyfour", "twentytwenty", "twentynineteen", "astra", "divi",
    "oceanwp", "hello-elementor",
]

GENERATOR = re.compile(r'name="generator" content="WordPress ([0-9.]+)"', re.I)
README_VER = re.compile(r"Version ([0-9.]+)", re.I)
SLUG_VER = re.compile(r"(?:Stable tag|Version):\s*([0-9.]+)", re.I)


def get(session, url, **kw):
    """One GET with a timeout, returning the response or None on error."""
    try:
        return session.get(url, timeout=kw.pop("timeout", 15), **kw)
    except requests.RequestException:
        return None


def find_version(session, base):
    """The core version from the home page generator tag, the RSS feed or
    readme.html, in that order."""
    home = get(session, base)
    if home is not None:
        m = GENERATOR.search(home.text)
        if m:
            return m.group(1), "generator meta tag"

    feed = get(session, urljoin(base, "feed/"))
    if feed is not None and feed.ok:
        try:
            root = ET.fromstring(feed.content)
            gen = root.findtext(".//generator") or ""
            m = re.search(r"wordpress\.org/\?v=([0-9.]+)", gen)
            if m:
                return m.group(1), "RSS feed generator"
        except ET.ParseError:
            pass

    readme = get(session, urljoin(base, "readme.html"))
    if readme is not None and readme.ok:
        m = README_VER.search(readme.text)
        if m:
            return m.group(1), "readme.html"
    return None, None


def enum_users(session, base):
    """Users from the REST API, falling back to the ?author=N redirect."""
    found = {}
    api = get(session, urljoin(base, "wp-json/wp/v2/users"))
    if api is not None and api.ok:
        try:
            for u in api.json():
                found[u.get("slug", "?")] = u.get("name", "")
        except ValueError:
            pass
    if found:
        return found, "REST API"

    for n in range(1, 11):
        r = get(session, base, params={"author": n}, allow_redirects=False)
        if r is None:
            continue
        loc = r.headers.get("Location", "")
        m = re.search(r"/author/([^/]+)/?", loc)
        if m:
            found[m.group(1)] = ""
    return found, "author archive redirect"


def probe_slugs(session, base, kind, slugs):
    """Check wp-content/<kind>/<slug>/readme.txt (or style.css for themes) and
    read the version when the directory exists."""
    hits = {}
    for slug in slugs:
        d = urljoin(base, "wp-content/%s/%s/" % (kind, slug))
        files = ["readme.txt", "README.txt"]
        if kind == "themes":
            files = ["style.css", "readme.txt"]
        for name in files:
            r = get(session, urljoin(d, name))
            if r is None or not r.ok or "<html" in r.text[:200].lower():
                continue
            m = SLUG_VER.search(r.text)
            hits[slug] = m.group(1) if m else "?"
            break
    return hits


def check_files(session, base):
    """A few files worth knowing about: xmlrpc, config backups, logs."""
    interesting = [
        "xmlrpc.php", "wp-config.php.bak", "wp-config.php~", ".wp-config.php.swp",
        "wp-content/debug.log", "wp-content/uploads/", "wp-login.php",
    ]
    hits = []
    for path in interesting:
        r = get(session, urljoin(base, path), allow_redirects=False)
        if r is not None and r.status_code in (200, 405):
            hits.append("%s (%s)" % (path, r.status_code))
    return hits


def read_list(path):
    with open(path, encoding="utf-8", errors="ignore") as fh:
        return [line.strip() for line in fh if line.strip() and not line.startswith("#")]


def main():
    ap = argparse.ArgumentParser(description="small free WordPress enumerator")
    ap.add_argument("url", help="target base URL, e.g. http://10.10.10.10/")
    ap.add_argument("-p", "--plugins", metavar="FILE", help="plugin slug wordlist")
    ap.add_argument("-t", "--themes", metavar="FILE", help="theme slug wordlist")
    ap.add_argument("--insecure", action="store_true", help="skip TLS verification")
    ap.add_argument("--ua", default="Mozilla/5.0 (wp-enum)", help="User-Agent header")
    args = ap.parse_args()

    base = args.url if args.url.endswith("/") else args.url + "/"
    if not urlparse(base).scheme:
        base = "http://" + base

    session = requests.Session()
    session.headers["User-Agent"] = args.ua
    session.verify = not args.insecure
    if args.insecure:
        urllib3.disable_warnings()

    if get(session, base) is None:
        print("[!] cannot reach %s" % base)
        return 1

    print("[*] target: %s" % base)

    version, how = find_version(session, base)
    if version:
        print("[+] WordPress %s (via %s)" % (version, how))
    else:
        print("[-] core version not disclosed")

    users, how = enum_users(session, base)
    if users:
        print("[+] %d user(s) via %s:" % (len(users), how))
        for slug, name in sorted(users.items()):
            print("      %s%s" % (slug, " (%s)" % name if name else ""))
    else:
        print("[-] no users enumerated")

    plugins = read_list(args.plugins) if args.plugins else COMMON_PLUGINS
    hits = probe_slugs(session, base, "plugins", plugins)
    if hits:
        print("[+] %d plugin(s):" % len(hits))
        for slug, ver in sorted(hits.items()):
            print("      %s %s" % (slug, ver))
    else:
        print("[-] no plugins found (try -p with a wordlist)")

    themes = read_list(args.themes) if args.themes else COMMON_THEMES
    hits = probe_slugs(session, base, "themes", themes)
    if hits:
        print("[+] %d theme(s):" % len(hits))
        for slug, ver in sorted(hits.items()):
            print("      %s %s" % (slug, ver))

    files = check_files(session, base)
    if files:
        print("[+] interesting files:")
        for f in files:
            print("      %s" % f)
    return 0


if __name__ == "__main__":
    sys.exit(main())
