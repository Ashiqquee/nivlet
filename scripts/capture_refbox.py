#!/usr/bin/env python3
"""Capture public Refbox reference pixels; requires Playwright and Chrome.

Uses a fresh headless browser, never the user's browser profile. Output includes
provenance, demo timestamps and screenshot hashes. No app download or login.
"""

import argparse
import hashlib
import json
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", default="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "references/ui-ux/refbox")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "page_url": "https://ref.box/",
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "viewport_css_pixels": {"width": 1440, "height": 1050},
        "device_scale_factor": 2,
        "method": "Isolated headless Chrome for page/hero/image screenshots; FFmpeg for original collapse-video frames. Public promo material, not installed app.",
        "captures": [],
    }

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=args.chrome, headless=True)
        try:
            manifest["browser_version"] = browser.version
            context = browser.new_context(viewport=manifest["viewport_css_pixels"], device_scale_factor=2)
            page = context.new_page()
            page.goto(manifest["page_url"], wait_until="networkidle", timeout=60000)
            page.evaluate("document.fonts.ready")
            # Trigger lazy-loading throughout the public page before full-page capture.
            for y in range(0, int(page.evaluate("document.documentElement.scrollHeight")), 800):
                page.evaluate("y => window.scrollTo(0, y)", y)
                page.wait_for_timeout(100)
            page.evaluate("window.scrollTo(0, 0)")
            page.evaluate("() => document.querySelectorAll('video').forEach(v => v.pause())")

            def save(name, locator=None, **metadata):
                target = output / name
                if locator is None:
                    page.screenshot(path=str(target), full_page=metadata.pop("full_page", False), scale="css")
                else:
                    locator.screenshot(path=str(target))
                manifest["captures"].append({
                    "file": name,
                    "pixel_scale": 1 if locator is None else 2,
                    "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                    **metadata,
                })
                print("Captured", name, flush=True)

            def seek(media, seconds):
                media.evaluate("""(v, t) => new Promise((resolve, reject) => {
                    v.pause();
                    if (Math.abs(v.currentTime - t) < 0.01 && v.readyState >= 2) { resolve(); return; }
                    const timer = setTimeout(() => reject(new Error('Demo seek timed out')), 15000);
                    v.addEventListener('seeked', () => { clearTimeout(timer); resolve(); }, {once:true});
                    v.currentTime = t;
                })""", seconds)
                page.wait_for_timeout(150)

            save("01-homepage-full.png", full_page=True, kind="website-full-page")
            save("02-homepage-viewport.png", kind="website-viewport")

            video = page.locator("video").first
            video.scroll_into_view_if_needed()
            video.evaluate("v => { v.preload = 'auto'; v.pause(); }")
            page.wait_for_function("() => Number.isFinite(document.querySelector('video').duration) && document.querySelector('video').readyState >= 2", timeout=30000)
            duration = video.evaluate("v => v.duration")
            source = video.evaluate("v => v.currentSrc")
            for index, seconds in enumerate([0, 3, 6, 9, 12], start=3):
                if seconds >= duration:
                    continue
                seek(video, seconds)
                save(f"{index:02d}-hero-demo-{seconds:02d}s.png", locator=video,
                     kind="embedded-demo-frame", source_url=source, seconds=seconds, duration_seconds=duration)

            # Exact image elements from the landing page, not reconstructed mockups.
            for name, alt in [
                ("08-project-sections.png", "Refbox board organized into collapsible sections"),
                ("09-floating-reference.png", "Refbox floating a color reference over a drawing workspace"),
            ]:
                image = page.get_by_alt_text(alt, exact=True)
                image.scroll_into_view_if_needed()
                image.evaluate("img => img.decode()")
                save(name, locator=image, kind="website-image-element", source_url=image.evaluate("img => img.currentSrc"), alt=alt)

            # These demos overlap on the website. Element bounds can capture an
            # overlaid sibling, so extract this clip's original frames directly.
            collapse = page.locator("video").filter(has=page.locator("source[src*='extra-hide']"))
            direct = page.locator("video[src*='extra-hide']")
            if direct.count():
                collapse = direct
            if collapse.count():
                collapse = collapse.first
                source = collapse.evaluate("v => v.currentSrc || v.src || v.querySelector('source').src")
                response = context.request.get(source)
                if not response.ok:
                    raise RuntimeError("Could not download public collapse demo")
                with tempfile.TemporaryDirectory(prefix="refai-refbox-") as temporary:
                    clip = Path(temporary) / "collapse.webm"
                    clip.write_bytes(response.body())
                    duration = float(subprocess.check_output([
                        "ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "default=noprint_wrappers=1:nokey=1", str(clip)
                    ], text=True).strip())
                    for name, fraction in [("10-collapse-demo.png", 0), ("11-collapse-demo-middle.png", 0.5), ("12-collapse-demo-late.png", 0.85)]:
                        seconds = duration * fraction
                        target = output / name
                        subprocess.run(["ffmpeg", "-v", "error", "-ss", str(seconds), "-i", str(clip),
                                        "-frames:v", "1", "-y", str(target)], check=True)
                        manifest["captures"].append({
                            "file": name, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                            "pixel_scale": "native-source", "kind": "source-video-frame",
                            "source_url": source, "seconds": seconds, "duration_seconds": duration,
                        })
                        print("Extracted original demo frame", name, flush=True)
        finally:
            browser.close()

    # Only a complete run replaces the manifest; a failed run leaves the previous one intact.
    (output / "capture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
