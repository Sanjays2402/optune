#!/usr/bin/env python3
"""Optune docs site generator.

Reads `pages/*.md` (with YAML-ish frontmatter), templates them through
`_template.html`, and writes static HTML to `dist/`. Inspired by peekaboo.sh.

Frontmatter keys:
  title:        page <h1> + <title> (required)
  section:      sidebar group name (required, uppercased automatically)
  order:        sort key inside the section (number, lower first)
  description:  meta description (optional)
  lede:         hero subtitle paragraph (optional)
  hero_title:   override for the big <h1> (optional, defaults to title)
  hide_toc:     if true, suppress the right-rail TOC
"""
from __future__ import annotations

import html
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).parent
PAGES_DIR = ROOT / "pages"
ASSETS_DIR = ROOT / "_assets"
DIST = ROOT / "dist"
TEMPLATE = (ROOT / "_template.html").read_text()


# ---------- Frontmatter + Markdown helpers ----------

def parse_frontmatter(text: str) -> tuple[dict, str]:
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---", 4)
    if end == -1:
        return {}, text
    block = text[4:end]
    body = text[end + 4 :].lstrip("\n")
    meta: dict = {}
    for line in block.splitlines():
        line = line.rstrip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val.lower() in ("true", "false"):
            meta[key] = val.lower() == "true"
        elif re.fullmatch(r"-?\d+", val):
            meta[key] = int(val)
        else:
            if (val.startswith('"') and val.endswith('"')) or (
                val.startswith("'") and val.endswith("'")
            ):
                val = val[1:-1]
            meta[key] = val
    return meta, body


def slugify(text: str) -> str:
    s = re.sub(r"[^\w\s-]", "", text.lower()).strip()
    s = re.sub(r"[\s_-]+", "-", s)
    return s.strip("-")


# ---------- Mini Markdown renderer ----------
# Handles: headings (#…####), paragraphs, lists (ul/ol, nested 1 level),
# fenced code (```lang), inline code, bold/italic, links, blockquotes,
# tables (pipe), horizontal rule, html passthrough for <div>/<details>.

INLINE_CODE = re.compile(r"`([^`]+?)`")
BOLD = re.compile(r"\*\*([^*]+?)\*\*")
ITALIC = re.compile(r"(?<!\*)\*([^*\n]+?)\*(?!\*)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
KBD = re.compile(r"\|kbd\|([^|]+)\|")


def render_inline(text: str) -> str:
    # Protect code spans first
    placeholders: list[str] = []

    def protect_code(m: re.Match) -> str:
        placeholders.append(html.escape(m.group(1)))
        return f"\x00CODE{len(placeholders)-1}\x00"

    text = INLINE_CODE.sub(protect_code, text)
    text = html.escape(text, quote=False)
    text = BOLD.sub(r"<strong>\1</strong>", text)
    text = ITALIC.sub(r"<em>\1</em>", text)
    text = LINK.sub(r'<a href="\2">\1</a>', text)
    text = KBD.sub(r'<span class="kbd">\1</span>', text)
    # Restore code
    text = re.sub(
        r"\x00CODE(\d+)\x00",
        lambda m: f"<code>{placeholders[int(m.group(1))]}</code>",
        text,
    )
    return text


@dataclass
class Heading:
    level: int
    text: str
    id: str


def render_markdown(md: str) -> tuple[str, list[Heading]]:
    out: list[str] = []
    headings: list[Heading] = []
    lines = md.split("\n")
    i = 0
    in_list = False
    list_kind = "ul"

    def close_list():
        nonlocal in_list
        if in_list:
            out.append(f"</{list_kind}>")
            in_list = False

    while i < len(lines):
        line = lines[i]

        # Fenced code block
        m = re.match(r"^```(\w*)\s*$", line)
        if m:
            close_list()
            lang = m.group(1)
            i += 1
            buf: list[str] = []
            while i < len(lines) and not lines[i].startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1  # closing fence
            code = "\n".join(buf)
            attr = f' class="language-{lang}"' if lang else ""
            out.append(f'<pre><code{attr}>{html.escape(code)}</code></pre>')
            continue

        # Horizontal rule
        if re.match(r"^---+\s*$", line):
            close_list()
            out.append("<hr>")
            i += 1
            continue

        # Heading
        m = re.match(r"^(#{1,4})\s+(.*?)\s*$", line)
        if m:
            close_list()
            level = len(m.group(1))
            txt = m.group(2)
            slug = slugify(txt)
            headings.append(Heading(level, txt, slug))
            out.append(
                f'<h{level} id="{slug}">{render_inline(txt)}</h{level}>'
            )
            i += 1
            continue

        # Blockquote (single line, can repeat)
        if line.startswith("> "):
            close_list()
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i].lstrip("> ").rstrip())
                i += 1
            out.append(
                "<blockquote><p>" + render_inline(" ".join(buf)) + "</p></blockquote>"
            )
            continue

        # Table — header / divider / rows
        if "|" in line and i + 1 < len(lines) and re.match(r"^\s*\|?[\s|:-]+\|?\s*$", lines[i + 1]):
            close_list()
            def split_row(s: str) -> list[str]:
                s = s.strip()
                if s.startswith("|"):
                    s = s[1:]
                if s.endswith("|"):
                    s = s[:-1]
                return [c.strip() for c in s.split("|")]
            headers = split_row(line)
            i += 2  # skip divider
            rows = []
            while i < len(lines) and "|" in lines[i] and lines[i].strip():
                rows.append(split_row(lines[i]))
                i += 1
            out.append("<table>")
            out.append("<thead><tr>" + "".join(f"<th>{render_inline(h)}</th>" for h in headers) + "</tr></thead>")
            out.append("<tbody>")
            for r in rows:
                out.append("<tr>" + "".join(f"<td>{render_inline(c)}</td>" for c in r) + "</tr>")
            out.append("</tbody></table>")
            continue

        # Unordered list
        m = re.match(r"^([-*])\s+(.*)$", line)
        if m:
            if not in_list or list_kind != "ul":
                close_list()
                out.append("<ul>")
                in_list = True
                list_kind = "ul"
            out.append(f"<li>{render_inline(m.group(2))}</li>")
            i += 1
            continue

        # Ordered list
        m = re.match(r"^(\d+)\.\s+(.*)$", line)
        if m:
            if not in_list or list_kind != "ol":
                close_list()
                out.append("<ol>")
                in_list = True
                list_kind = "ol"
            out.append(f"<li>{render_inline(m.group(2))}</li>")
            i += 1
            continue

        # Raw HTML passthrough (single line)
        if line.startswith("<") and not line.startswith("<!"):
            close_list()
            out.append(line)
            i += 1
            continue

        # Blank line
        if not line.strip():
            close_list()
            i += 1
            continue

        # Paragraph (consume contiguous non-empty lines)
        close_list()
        buf = [line]
        i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,4}\s|>|```|-{3,}|\d+\.\s|[-*]\s)", lines[i]):
            buf.append(lines[i])
            i += 1
        out.append("<p>" + render_inline(" ".join(buf)) + "</p>")

    close_list()
    return "\n".join(out), headings


# ---------- Site assembly ----------

def load_pages() -> list[dict]:
    pages = []
    for md_path in sorted(PAGES_DIR.glob("*.md")):
        text = md_path.read_text()
        meta, body = parse_frontmatter(text)
        meta.setdefault("section", "DOCS")
        meta.setdefault("order", 100)
        meta.setdefault("title", md_path.stem.replace("-", " ").title())
        meta["slug"] = md_path.stem
        meta["body"] = body
        pages.append(meta)
    return pages


def order_pages(pages: list[dict]) -> list[dict]:
    return sorted(pages, key=lambda p: (p.get("nav_order", p["order"]), p["order"], p["slug"]))


def section_order(pages: list[dict]) -> list[str]:
    """Preserve first-seen section order from the ordered pages list."""
    seen: list[str] = []
    for p in pages:
        sec = p["section"].upper()
        if sec not in seen:
            seen.append(sec)
    return seen


def render_sidebar(pages: list[dict], current_slug: str) -> str:
    sections: dict[str, list[dict]] = {}
    for p in pages:
        sections.setdefault(p["section"].upper(), []).append(p)
    chunks = []
    for sec in section_order(pages):
        chunks.append(f"<section><h2>{html.escape(sec)}</h2>")
        for p in sections[sec]:
            cls = "nav-link active" if p["slug"] == current_slug else "nav-link"
            chunks.append(
                f'<a class="{cls}" href="{p["slug"]}.html">{html.escape(p["title"])}</a>'
            )
        chunks.append("</section>")
    return "\n".join(chunks)


def render_toc(headings: list[Heading]) -> str:
    h2_h3 = [h for h in headings if h.level in (2, 3)]
    if len(h2_h3) < 2:
        return ""
    lines = ['<aside class="toc"><h2>On this page</h2>']
    for h in h2_h3:
        cls = "toc-l3" if h.level == 3 else ""
        lines.append(f'<a href="#{h.id}" class="{cls}">{html.escape(h.text)}</a>')
    lines.append("</aside>")
    return "\n".join(lines)


def render_page_nav(pages: list[dict], idx: int) -> str:
    prev = pages[idx - 1] if idx > 0 else None
    nxt = pages[idx + 1] if idx + 1 < len(pages) else None
    if not prev and not nxt:
        return ""
    parts = ['<nav class="page-nav">']
    if prev:
        parts.append(
            f'<a class="page-nav-prev" href="{prev["slug"]}.html"><small>← Previous</small><span>{html.escape(prev["title"])}</span></a>'
        )
    if nxt:
        parts.append(
            f'<a class="page-nav-next" href="{nxt["slug"]}.html"><small>Next →</small><span>{html.escape(nxt["title"])}</span></a>'
        )
    parts.append("</nav>")
    return "\n".join(parts)


def build():
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)
    # Copy assets
    assets_out = DIST / "_assets"
    shutil.copytree(ASSETS_DIR, assets_out)
    # Favicon at root
    shutil.copy(ASSETS_DIR / "favicon.svg", DIST / "favicon.svg")

    raw_pages = load_pages()
    pages = order_pages(raw_pages)
    if not pages:
        print("No pages found in pages/", file=sys.stderr)
        sys.exit(1)

    for idx, page in enumerate(pages):
        body_html, headings = render_markdown(page["body"])
        sidebar = render_sidebar(pages, page["slug"])
        toc = "" if page.get("hide_toc") else render_toc(headings)
        page_nav = render_page_nav(pages, idx)
        lede = f'<p class="lede">{render_inline(page["lede"])}</p>' if page.get("lede") else ""
        body_class = "home" if page["slug"] == "index" else ""

        out = (TEMPLATE
            .replace("{{TITLE}}", html.escape(f"{page['title']} — Optune"))
            .replace("{{DESCRIPTION}}", html.escape(page.get("description", "Optune — open-source Logitech control for macOS.")))
            .replace("{{PATH}}", "" if page["slug"] == "index" else f"{page['slug']}.html")
            .replace("{{ASSETS}}", "_assets")
            .replace("{{ROOT}}", "")
            .replace("{{BODY_CLASS}}", body_class)
            .replace("{{SIDEBAR}}", sidebar)
            .replace("{{SECTION}}", html.escape(page["section"].upper()))
            .replace("{{HERO_TITLE}}", html.escape(page.get("hero_title", page["title"])))
            .replace("{{LEDE}}", lede)
            .replace("{{SLUG}}", page["slug"])
            .replace("{{CONTENT}}", body_html)
            .replace("{{PAGE_NAV}}", page_nav)
            .replace("{{TOC}}", toc)
        )
        out_path = DIST / f"{page['slug']}.html"
        out_path.write_text(out)
        print(f"  {out_path.relative_to(ROOT)}")

    print(f"\n✓ Built {len(pages)} page(s) to {DIST.relative_to(ROOT)}/")


if __name__ == "__main__":
    build()
