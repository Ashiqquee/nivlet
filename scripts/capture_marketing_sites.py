#!/usr/bin/env python3
"""Capture public Mac-app marketing pages as website design references.

Uses a fresh headless Chrome (never a personal profile). Saves a first-viewport
and a height-capped full-page capture per site, plus a manifest with hashes.
Public marketing pages only; no login, downloads or app installs.
"""

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

SITES = [
    ("raycast", "https://www.raycast.com/"),
    ("refbox", "https://ref.box/"),
    ("dropover", "https://dropoverapp.com/"),
    ("cleanshot", "https://cleanshot.com/"),
    ("alcove", "https://tryalcove.com/"),
    ("klack", "https://tryklack.com/"),
    ("ice", "https://icemenubar.app/"),
    ("homerow", "https://www.homerow.app/"),
    ("superwhisper", "https://superwhisper.com/"),
    ("paste", "https://pasteapp.io/"),
    ("granola", "https://www.granola.ai/"),
    ("maccy", "https://maccy.app/"),
    ("shottr", "https://shottr.cc/"),
    ("notchnook", "https://lo.cafe/notchnook"),
    ("teenyshelf", "https://teenyshelf-website.pages.dev/"),
    ("wisprflow", "https://wisprflow.ai/"),
    ("rectangle", "https://rectangleapp.com/"),
    ("awwwards-sotd", "https://www.awwwards.com/websites/sites_of_the_day/"),
    ("awwwards-apps", "https://www.awwwards.com/websites/mobile-apps/"),
]

MAX_FULL_HEIGHT = 7000


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    manifest_path = output / "capture-manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"captures": {}}
    viewport = {"width": 1440, "height": 900}

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=args.chrome, headless=True)
        manifest["browser_version"] = browser.version
        for slug, url in SITES:
            if args.only and slug not in args.only:
                continue
            context = browser.new_context(viewport=viewport, device_scale_factor=1, color_scheme="dark")
            page = context.new_page()
            entry = {"url": url, "captured_at_utc": datetime.now(timezone.utc).isoformat(), "files": {}}
            try:
                page.goto(url, wait_until="load", timeout=45000)
                page.wait_for_timeout(2500)
                height = int(page.evaluate("document.documentElement.scrollHeight"))
                for y in range(0, min(height, MAX_FULL_HEIGHT), 700):
                    page.evaluate("y => window.scrollTo(0, y)", y)
                    page.wait_for_timeout(120)
                page.evaluate("window.scrollTo(0, 0)")
                page.wait_for_timeout(800)
                hero = output / f"{slug}-hero.png"
                page.screenshot(path=str(hero))
                full = output / f"{slug}-full.png"
                clip_h = min(int(page.evaluate("document.documentElement.scrollHeight")), MAX_FULL_HEIGHT)
                page.screenshot(path=str(full), full_page=True,
                                clip={"x": 0, "y": 0, "width": viewport["width"], "height": clip_h})
                entry["title"] = page.title()
                entry["final_url"] = page.url
                for f in (hero, full):
                    entry["files"][f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
                print("ok", slug, page.title())
            except Exception as exc:  # keep going; record failures honestly
                entry["error"] = str(exc).splitlines()[0]
                print("FAIL", slug, entry["error"])
            manifest["captures"][slug] = entry
            context.close()
        browser.close()

    manifest["viewport_css_pixels"] = viewport
    manifest["method"] = "Isolated headless Chrome, dark color-scheme preference, 1x; full page capped at %d px." % MAX_FULL_HEIGHT
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
