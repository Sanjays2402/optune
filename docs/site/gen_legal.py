#!/usr/bin/env python3
"""Generate the docs site's Legal pages from the repository-root Markdown files.

The root files (PRIVACY.md, TERMS.md, ...) are the single source of truth. This
script prepends frontmatter, converts the few Markdown features the mini
renderer lacks (autolinks, _italics_) and rewrites relative links, writing
generated pages into pages/ (git-ignored). Run before build.py.
"""
import re
from pathlib import Path

HERE = Path(__file__).parent
REPO = HERE.parent.parent
BLOB = "https://github.com/Sanjays2402/optune/blob/main/"

PAGES = {
    "PRIVACY.md": ("privacy", "Privacy Policy", 410, "What Optune stores, what it sends over the network, and what it never collects."),
    "TERMS.md": ("terms", "Terms of Use", 420, "Terms for using the Optune app, CLI, source and website."),
    "TRADEMARKS.md": ("trademarks", "Trademarks", 430, "Optune is independent and not affiliated with Logitech or Apple."),
    "THIRD_PARTY_NOTICES.md": ("third-party-notices", "Third-party notices", 440, "Dependencies, licences and acknowledgements."),
    "SECURITY.md": ("security", "Security", 450, "How to report a vulnerability and what to know about permissions."),
    "CONTRIBUTING.md": ("contributing", "Contributing", 460, "How to contribute, and how we keep the project clean."),
    "CODE_OF_CONDUCT.md": ("code-of-conduct", "Code of Conduct", 470, "How we treat each other."),
}
LINKS = {src: f"{slug}.html" for src, (slug, *_ ) in PAGES.items()}


def fix_link(m: re.Match) -> str:
    text, target = m.group(1), m.group(2)
    if re.match(r"^(https?:|mailto:|#)", target):
        return m.group(0)
    path, _, frag = target.partition("#")
    if path in LINKS:
        return f"[{text}]({LINKS[path]}{'#' + frag if frag else ''})"
    return f"[{text}]({BLOB}{path})"


for src, (slug, title, order, desc) in PAGES.items():
    body = (REPO / src).read_text()
    body = re.sub(r"^# .*\n", "", body, count=1)                       # title comes from frontmatter
    body = re.sub(r"<(https?://[^>\s]+)>", r"[\1](\1)", body)          # autolinks
    body = re.sub(r"(?<![\w])_([^_\n]+?)_(?![\w])", r"*\1*", body)     # _italic_ -> *italic*
    body = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", fix_link, body)          # relative links
    front = f"---\ntitle: {title}\nsection: Legal\norder: {order}\ndescription: {desc}\nlede: {desc}\nsource: {src}\n---\n\n# {title}\n"
    (HERE / "pages" / f"{slug}.md").write_text(front + body)
print(f"generated {len(PAGES)} legal pages")
