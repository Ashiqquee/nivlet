#!/usr/bin/env python3
"""Build local or Developer ID candidates; notarize only via an explicit subcommand.

Standard library only. Never installs the app or touches a working library.
See docs/distribution.md for credentials, acceptance checks and recovery.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "ashique.nivlet.Nivlet"
ALLOWED_ENTITLEMENTS = {
    "com.apple.security.app-sandbox",
    "com.apple.security.files.user-selected.read-write",
    "com.apple.application-identifier",
    "com.apple.developer.team-identifier",
}
PENDING = [
    "Phase 6 native acceptance gate",
    "Clean-Mac quarantined install and first launch",
    "Disconnected first launch with stapled tickets",
    "Real signed previous-release update and rollback",
    "macOS 14 and macOS 27 runtime compatibility",
]


def run(*args, check=True):
    result = subprocess.run([str(a) for a in args], cwd=ROOT, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} failed ({result.returncode}):\n"
                           + result.stderr.decode(errors="replace")
                           + result.stdout.decode(errors="replace")[-6000:])
    return result


def output(*args):
    return run(*args).stdout.decode().strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def save_manifest(folder, manifest):
    temporary = folder / "manifest.json.tmp"
    temporary.write_text(json.dumps(manifest, indent=2) + "\n")
    temporary.replace(folder / "manifest.json")


def require_identity(identity, team):
    if not identity or not re.fullmatch(r"[A-Fa-f0-9]{40}", identity):
        raise ValueError("Use the 40-character SHA-1 of a Developer ID Application identity.")
    if not team or not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("Supply the 10-character Apple team ID.")
    identities = output("/usr/bin/security", "find-identity", "-v", "-p", "codesigning")
    matching = [line for line in identities.splitlines()
                if identity.upper() in line.upper() and '"Developer ID Application:' in line
                and f"({team})" in line]
    if len(matching) != 1:
        raise ValueError("The requested Developer ID Application identity/team is unavailable.")


def inspect_app(app, *, team=None, local=False):
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", app)
    details = run("/usr/bin/codesign", "--display", "--verbose=4", app).stderr.decode()
    details = "\n".join(line for line in details.splitlines() if not line.startswith("Executable=")) + "\n"
    signed = run("/usr/bin/codesign", "--display", "--entitlements", "-", "--xml", app)
    entitlements = plistlib.loads(signed.stdout)
    if set(entitlements) - ALLOWED_ENTITLEMENTS:
        raise ValueError("Unexpected distribution entitlements: "
                         + ", ".join(sorted(set(entitlements) - ALLOWED_ENTITLEMENTS)))
    for required in ("com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-write"):
        if entitlements.get(required) is not True:
            raise ValueError(f"Missing required entitlement: {required}")
    if not re.search(r"flags=0x[0-9a-f]+\([^)]*\bruntime\b", details):
        raise ValueError("Hardened Runtime is missing.")
    if local:
        if "Signature=adhoc" not in details:
            raise ValueError("Local build must have an ad-hoc signature.")
    else:
        if not team or f"TeamIdentifier={team}\n" not in details:
            raise ValueError("App team does not match the requested team.")
        if "Authority=Developer ID Application:" not in details or "\nTimestamp=" not in details:
            raise ValueError("Developer ID Application signature with secure timestamp required.")
        for key in ("com.apple.developer.team-identifier",):
            if key in entitlements and entitlements[key] != team:
                raise ValueError("Entitlement team does not match signature.")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != BUNDLE_ID or info.get("LSUIElement") is not True:
        raise ValueError("Unexpected bundle identity or app activation policy.")
    if info.get("LSMinimumSystemVersion") != "14.0":
        raise ValueError("The provisional macOS 14 deployment floor changed.")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    if output("/usr/bin/lipo", "-archs", executable) != "arm64":
        raise ValueError("Only the tested Apple-silicon candidate is supported by this workflow.")
    return {"bundle_id": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"], "minimum_macos": info["LSMinimumSystemVersion"],
            "architectures": ["arm64"], "executable_sha256": sha256(executable),
            "entitlements": entitlements, "signature": details}


def new_folder(path):
    path = path.expanduser().resolve()
    # No reuse or recursive deletion of an existing output directory.
    path.mkdir(parents=True, exist_ok=False)
    return path


# Finder window for the mounted image. Positions are icon centres in points and match
# scripts/dmg/background.tiff (660 × 460, drawn by scripts/dmg/make_background.swift).
FINDER_LAYOUT = """
tell application "Finder"
    tell disk "Nivlet"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set bounds of container window to {200, 120, 860, 608}
        set options to icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 112
        set text size of options to 13
        set background picture of options to file ".background:background.tiff"
        set position of item "Nivlet.app" of container window to {170, 190}
        set position of item "Applications" of container window to {490, 190}
        set position of item "Install and recovery.txt" of container window to {330, 362}
        close
        open
        delay 1
        close
    end tell
end tell
"""


def saved_layout(mount, *, wait):
    for _ in range(int(wait * 2)):
        layout = (mount / ".DS_Store").read_bytes() if (mount / ".DS_Store").is_file() else b""
        if b"icvp" in layout and layout.count(b"Iloc") >= 3:
            return True
        time.sleep(0.5)
    return False


def lay_out(writable):
    """Has Finder save the window layout and marks the volume's custom icon. Needs a GUI session
    and permission for the calling app to control Finder."""
    if Path("/Volumes/Nivlet").exists():
        raise RuntimeError("Eject the mounted “Nivlet” disk image before packaging; Finder lays out the new one by name.")
    attached = plistlib.loads(run("/usr/bin/hdiutil", "attach", "-readwrite", "-noverify", "-noautoopen",
                                  "-plist", writable).stdout)
    mount = next(Path(entity["mount-point"]) for entity in attached["system-entities"] if "mount-point" in entity)
    try:
        if mount != Path("/Volumes/Nivlet"):
            raise RuntimeError(f"Image mounted at {mount}, not /Volumes/Nivlet.")
        # On a new volume Finder often keeps the first pass in memory and writes .DS_Store only after
        # a second; detaching before it is written loses the layout.
        for _ in range(3):
            run("/usr/bin/osascript", "-e", FINDER_LAYOUT)
            if saved_layout(mount, wait=10):
                break
        else:
            raise RuntimeError("Finder did not save the disk image layout.")
        run("/usr/bin/xcrun", "SetFile", "-a", "C", mount)
        shutil.rmtree(mount / ".fseventsd", ignore_errors=True)
        run("/bin/sync")
    finally:
        run("/usr/bin/hdiutil", "detach", mount)


def package(folder, name, *, identity=None):
    staging = folder / "image-contents"
    staging.mkdir()
    writable = folder / "layout.dmg"
    try:
        run("/usr/bin/ditto", folder / "Nivlet.app", staging / "Nivlet.app")
        (staging / "Applications").symlink_to("/Applications")
        shutil.copyfile(folder / "Install and recovery.txt", staging / "Install and recovery.txt")
        (staging / ".background").mkdir()
        shutil.copyfile(ROOT / "scripts/dmg/background.tiff", staging / ".background/background.tiff")
        shutil.copyfile(folder / "Nivlet.app/Contents/Resources/AppIcon.icns", staging / ".VolumeIcon.icns")
        megabytes = int(output("/usr/bin/du", "-sm", staging).split()[0]) + 20
        run("/usr/bin/hdiutil", "create", "-volname", "Nivlet", "-srcfolder", staging, "-size", f"{megabytes}m",
            "-format", "UDRW", "-fs", "HFS+", writable)
        lay_out(writable)
        image = folder / name
        run("/usr/bin/hdiutil", "convert", writable, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", image)
        if identity:
            run("/usr/bin/codesign", "--sign", identity, "--timestamp", image)
            run("/usr/bin/codesign", "--verify", "--strict", image)
        run("/usr/bin/hdiutil", "verify", image)
        return image
    finally:
        shutil.rmtree(staging)
        writable.unlink(missing_ok=True)


def checksums(folder, manifest):
    image = folder / manifest["dmg"]
    manifest["dmg_sha256"] = sha256(image)
    (folder / "SHA256SUMS").write_text(f"{manifest['dmg_sha256']}  {image.name}\n")


def build(args):
    local = args.local
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", args.version):
        raise ValueError("Version must be one to three numeric components.")
    if not re.fullmatch(r"[1-9][0-9]*", args.build_number):
        raise ValueError("Build number must be a positive integer.")
    if not local:
        require_identity(args.identity, args.team)
    elif args.team:
        raise ValueError("A local build does not use a team ID.")
    folder = new_folder(args.output)
    manifest = {"format_version": 1, "status": "building", "release_ready": False,
                "source_commit": output("/usr/bin/git", "rev-parse", "HEAD"),
                "source_dirty": bool(output("/usr/bin/git", "status", "--porcelain")),
                "xcode": output("/usr/bin/xcodebuild", "-version"),
                "host_macos": output("/usr/bin/sw_vers", "-productVersion"),
                "team": args.team, "identity": args.identity, "pending_checks": PENDING}
    save_manifest(folder, manifest)
    try:
        command = ["/usr/bin/xcodebuild", "-project", "Nivlet.xcodeproj", "-scheme", "Nivlet",
                   "-configuration", "Release", "-destination", "platform=macOS,arch=arm64",
                   "-derivedDataPath", str(folder / "DerivedData"), "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES",
                   "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO", "ENABLE_HARDENED_RUNTIME=YES",
                   f"MARKETING_VERSION={args.version}", f"CURRENT_PROJECT_VERSION={args.build_number}",
                   "CODE_SIGN_IDENTITY=" + ("-" if local else args.identity)]
        if not local:
            command += [f"DEVELOPMENT_TEAM={args.team}", "CODE_SIGN_STYLE=Manual", "OTHER_CODE_SIGN_FLAGS=--timestamp"]
        with (folder / "build.log").open("wb") as log:
            result = subprocess.run(command + ["build"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f"Release build failed; inspect {folder / 'build.log'}")
        run("/usr/bin/ditto", folder / "DerivedData/Build/Products/Release/Nivlet.app", folder / "Nivlet.app")
        manifest["app"] = inspect_app(folder / "Nivlet.app", local=local, team=args.team)
        if manifest["app"]["version"] != args.version or manifest["app"]["build"] != args.build_number:
            raise ValueError("Built version differs from requested version.")
        shutil.copyfile(ROOT / "docs/distribution-install.txt", folder / "Install and recovery.txt")
        suffix = "LOCAL-UNNOTARIZED" if local else "SIGNED-UNNOTARIZED"
        name = f"Nivlet-{args.version}-{args.build_number}-arm64-{suffix}.dmg"
        manifest["dmg"] = package(folder, name, identity=args.identity).name
        manifest["status"] = "local-unnotarized" if local else "signed-unnotarized"
        checksums(folder, manifest)
        save_manifest(folder, manifest)
        print(f"Created {folder / name}\nStatus: {manifest['status']}; acceptance gates remain open.")
    except Exception:
        manifest["status"] = "build-failed"
        save_manifest(folder, manifest)
        raise


def load_candidate(folder):
    manifest = json.loads((folder / "manifest.json").read_text())
    if manifest["format_version"] != 1:
        raise ValueError("Unsupported release manifest.")
    name = manifest["dmg"]
    if Path(name).name != name or not name.endswith(".dmg"):
        raise ValueError("Unsafe disk-image name in release manifest.")
    if sha256(folder / name) != manifest["dmg_sha256"]:
        raise ValueError("Disk-image checksum differs from the manifest.")
    return manifest


def notarize(args):
    source = args.input.expanduser().resolve()
    original = load_candidate(source)
    if original["status"] != "signed-unnotarized":
        raise ValueError("Notarization requires a signed-unnotarized candidate.")
    require_identity(original["identity"], original["team"])
    inspected = inspect_app(source / "Nivlet.app", team=original["team"])
    if inspected != original["app"]:
        raise ValueError("App changed since the signed candidate was built.")
    run("/usr/bin/codesign", "--verify", "--strict", source / original["dmg"])
    folder = new_folder(args.output)
    manifest = dict(original, status="notarization-in-progress", notarization={})
    save_manifest(folder, manifest)
    try:
        run("/usr/bin/ditto", source / "Nivlet.app", folder / "Nivlet.app")
        shutil.copyfile(source / "Install and recovery.txt", folder / "Install and recovery.txt")
        upload = folder / "NotaryUpload.zip"
        run("/usr/bin/ditto", "-c", "-k", "--keepParent", folder / "Nivlet.app", upload)

        def submit(path, label):
            # Explicit command is the only upload path; profile names contain no credential material.
            result = run("/usr/bin/xcrun", "notarytool", "submit", path, "--keychain-profile",
                         args.profile, "--wait", "--output-format", "json", check=False)
            (folder / f"notary-{label}.json").write_bytes(result.stdout)
            (folder / f"notary-{label}.stderr.txt").write_bytes(result.stderr)
            report = json.loads(result.stdout)
            manifest["notarization"][label] = report
            save_manifest(folder, manifest)
            if report.get("id"):
                run("/usr/bin/xcrun", "notarytool", "log", report["id"], "--keychain-profile",
                    args.profile, folder / f"notary-{label}-log.json", check=False)
            if result.returncode or report.get("status") != "Accepted":
                raise RuntimeError(f"Notarization {label} was not accepted; see saved report.")
            run("/usr/bin/xcrun", "stapler", "staple", path if label == "dmg" else folder / "Nivlet.app")
            run("/usr/bin/xcrun", "stapler", "validate", path if label == "dmg" else folder / "Nivlet.app")

        submit(upload, "app")
        upload.unlink()
        name = original["dmg"].replace("SIGNED-UNNOTARIZED", "NOTARIZED")
        image = package(folder, name, identity=original["identity"])
        manifest["dmg"] = name
        submit(image, "dmg")
        manifest["app"] = inspect_app(folder / "Nivlet.app", team=original["team"])
        run("/usr/bin/hdiutil", "verify", image)
        run("/usr/bin/spctl", "--assess", "--type", "execute", "--verbose=4", folder / "Nivlet.app")
        run("/usr/bin/spctl", "--assess", "--type", "open", "--context",
            "context:primary-signature", "--verbose=4", image)
        manifest["status"] = "notarized"
        checksums(folder, manifest)  # Stapling changes the DMG bytes.
        save_manifest(folder, manifest)
        print(f"Notarized candidate: {image}\nClean-Mac and native gates remain open; no publication performed.")
    except Exception:
        manifest["status"] = "notarization-failed"
        save_manifest(folder, manifest)
        raise


def verify(args):
    folder = args.input.expanduser().resolve()
    manifest = load_candidate(folder)
    if manifest["status"] not in ("local-unnotarized", "signed-unnotarized", "notarized"):
        raise ValueError("Only completed candidates can be verified.")
    local = manifest["status"] == "local-unnotarized"
    expected = inspect_app(folder / "Nivlet.app", local=local, team=manifest["team"])
    if expected != manifest["app"]:
        raise ValueError("App differs from candidate manifest.")
    image = folder / manifest["dmg"]
    run("/usr/bin/hdiutil", "verify", image)
    if not local:
        run("/usr/bin/codesign", "--verify", "--strict", image)
    with tempfile.TemporaryDirectory(prefix="nivlet-package-check-") as temporary:
        temporary = Path(temporary)
        mount = temporary / "image"
        mount.mkdir()
        run("/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-noautoopen",
            "-mountpoint", mount, image)
        try:
            if os.readlink(mount / "Applications") != "/Applications":
                raise ValueError("Incorrect Applications shortcut in disk image.")
            if (mount / "Install and recovery.txt").read_bytes() != (folder / "Install and recovery.txt").read_bytes():
                raise ValueError("Installation instructions differ in the disk image.")
            if not all((mount / part).is_file() for part in (".DS_Store", ".background/background.tiff", ".VolumeIcon.icns")):
                raise ValueError("Disk image is missing its Finder layout, background or volume icon.")
            # Test the same copy boundary as a Finder installation in a disposable directory.
            installed = temporary / "Applications/Nivlet.app"
            run("/usr/bin/ditto", mount / "Nivlet.app", installed)
            if inspect_app(installed, local=local, team=manifest["team"]) != expected:
                raise ValueError("Installed app differs from the packaged candidate.")
            if manifest["status"] == "notarized":
                run("/usr/bin/xcrun", "stapler", "validate", installed)
                run("/usr/bin/xcrun", "stapler", "validate", image)
                run("/usr/bin/spctl", "--assess", "--type", "execute", "--verbose=4", installed)
        finally:
            run("/usr/bin/hdiutil", "detach", mount)
    print("Checksum, image integrity, read-only mount and disposable install copy passed.\n"
          "This does not establish clean-Mac trust or launch/update compatibility.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    builder = sub.add_parser("build")
    mode = builder.add_mutually_exclusive_group(required=True)
    mode.add_argument("--local", action="store_true", help="Ad-hoc local candidate, never a trusted download")
    mode.add_argument("--identity", help="SHA-1 of a Developer ID Application identity")
    builder.add_argument("--team")
    builder.add_argument("--version", default="0.1")
    builder.add_argument("--build-number", default="1")
    builder.add_argument("--output", type=Path, required=True, help="New directory; existing output is never replaced")
    builder.set_defaults(action=build)
    notary = sub.add_parser("notarize", help="Upload signed app and DMG to Apple, staple and assess")
    notary.add_argument("--input", type=Path, required=True)
    notary.add_argument("--output", type=Path, required=True)
    notary.add_argument("--profile", required=True, help="Existing notarytool Keychain profile name")
    notary.set_defaults(action=notarize)
    verifier = sub.add_parser("verify", help="Verify image and copy its app into a disposable install directory")
    verifier.add_argument("--input", type=Path, required=True)
    verifier.set_defaults(action=verify)
    args = parser.parse_args()
    os.environ.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    try:
        args.action(args)
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        parser.exit(1, f"Distribution stopped: {error}\n")


if __name__ == "__main__":
    main()
