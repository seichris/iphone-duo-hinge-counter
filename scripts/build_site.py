#!/usr/bin/env python3
"""Build the static SEO/support site from the same policy text bundled in the app."""
import argparse
from html import escape
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSS = """*{box-sizing:border-box}body{margin:0;font:18px/1.65 system-ui,sans-serif;background:#101819;color:#e7f2ee}a{color:#a6edcf;text-underline-offset:4px}a:focus-visible{outline:3px solid #fff;outline-offset:5px}header,main,footer{max-width:900px;margin:auto;padding:28px}header{display:flex;flex-wrap:wrap;gap:24px;justify-content:space-between;border-bottom:1px solid #354843}nav{display:flex;gap:24px}h1{font-size:clamp(2.5rem,7vw,4.4rem);line-height:1.1;letter-spacing:-.04em}h2{line-height:1.25;margin-top:2.5rem}.lead{font-size:1.35rem;color:#bdd4ca}.notice{padding:20px;border:1px solid #67867a;border-radius:12px}.status{font-size:.8rem;text-transform:uppercase;letter-spacing:.12em;color:#a6edcf}section{margin:36px 0}footer{font-size:.85rem;border-top:1px solid #354843}li{margin:.7rem 0}.skip{position:absolute;left:-10000px}.skip:focus{left:16px;top:8px;background:#101819} @media(prefers-color-scheme:light){body{background:#f7faf8;color:#173029}a{color:#165944}.lead{color:#345e4c}.status{color:#245f49}.skip:focus{background:#fff}a:focus-visible{outline-color:#173029}}"""


def render_pages(root: Path) -> dict[str, str]:
    help_content = json.loads((root / "Resources/HelpContent.json").read_text())
    release = json.loads((root / "appstore/release.json").read_text())
    base = release["website_base_url"]
    def page(title, description, path, body):
        canonical = base + path
        return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)}</title><meta name="description" content="{escape(description, quote=True)}">
<link rel="canonical" href="{escape(canonical, quote=True)}"><link rel="stylesheet" href="styles.css">
<meta property="og:title" content="{escape(title, quote=True)}"><meta property="og:description" content="{escape(description, quote=True)}"><meta property="og:type" content="website"><meta property="og:url" content="{escape(canonical, quote=True)}">
</head><body><a class="skip" href="#main">Skip to content</a><header><a href="./">Fold Counter</a><nav aria-label="Main"><a href="support.html">Support</a><a href="privacy.html">Privacy</a></nav></header>
<main id="main">{body}</main><footer><p>Independent software. Not affiliated with or endorsed by Apple. iPhone is a trademark of Apple Inc.</p><p><a href="https://github.com/seichris/iphone-duo-fold-counter">Source and project status</a> · <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub hosting privacy</a></p></footer></body></html>\n'''
    pages = {"styles.css": CSS + "\n", ".nojekyll": ""}
    body = '''<p class="status">In preparation · not available on the App Store yet</p>
<h1>Fold Counter<br>for iPhone Duo</h1><p class="lead">A clear record of the openings you observe.</p>
<p>See recorded daily totals, history charts and saved widget counts. Keep manual entries separate from sensor observations. No account, ads or analytics.</p>
<p class="notice"><strong>Foreground-only, not 24/7.</strong> Automatic counting requires supported hardware and a complete close-to-open movement observed while this app is active. Missed openings are not recovered. Duo SDK and physical-device validation are still pending.</p>
<p><a href="https://github.com/seichris/iphone-duo-fold-counter">Follow development on GitHub</a> · <a href="support.html">How counting works</a></p>
<section><h2>Understand your recorded openings</h2><p>Today's count, an all-time recorded total and a daily average. Explore 7-, 30- and 90-day history without treating incomplete observations as a device-lifetime total.</p></section>
<section><h2>Keep your history in your hands</h2><p>Store records locally, export CSV, create a JSON backup and restore or erase your history. Home Screen and Lock Screen widgets show saved snapshots; they do not monitor the hinge.</p></section>
<section><h2>Can an iPhone fold counter track every opening?</h2><p>Not this implementation. It only counts a complete transition observed while active. Locking the phone, switching apps and display handoff may interrupt observation. It does not measure hinge health, remaining lifespan or warranty eligibility.</p></section>
<section><h2>Can I try it without a foldable phone?</h2><p>The development build provides manual entries and an isolated unsaved demo on supported iOS versions. A demo count is never presented as a real hardware observation.</p></section>'''
    pages["index.html"] = page("Fold Counter for iPhone Duo | Recorded Opening History",
        "An independent fold counter in development for iPhone Duo: recorded openings, daily history, widgets and local backups. Foreground-only, not 24/7 tracking.", "", body)
    for key, title in (("privacy", "Privacy Policy"), ("support", "Help & Support")):
        body = f'<h1>{title}</h1><p>Fold Counter · updated {escape(help_content["updated"])}</p>'
        for item in help_content[key]:
            body += f'<section><h2>{escape(item["title"])}</h2><p>{escape(item["body"])}</p></section>'
        body += f'<p><a href="{escape(help_content["issue_url"], quote=True)}">Contact the maintainer via a public GitHub issue</a>. Do not post private information.</p>'
        pages[key + ".html"] = page(title + " | Fold Counter", "Fold Counter " + title.lower() + ": local data, counting coverage, widgets, backups and help.", key + ".html", body)
    pages["robots.txt"] = f"User-agent: *\nAllow: /\nSitemap: {base}sitemap.xml\n"
    # A project-site robots file is not the origin-wide robots.txt; see the release guide.
    pages["sitemap.xml"] = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + ''.join(f'<url><loc>{escape(base + p)}</loc></url>' for p in ('', 'support.html', 'privacy.html')) + '</urlset>\n'
    return pages


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pages = render_pages(ROOT)
    for name, content in pages.items():
        path = ROOT / "site" / name
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise SystemExit(f"Stale generated site file: {name}; run python3 scripts/build_site.py")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
    print(f"{'Checked' if args.check else 'Built'} {len(pages)} site files. No deployment performed.")


if __name__ == "__main__":
    main()
