"""Failure-boundary tests for release tooling; no credentials, uploads or user data."""
import argparse
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import distribute


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nivlet-distribution-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def candidate(self, status="signed-unnotarized"):
        image = self.root / "Nivlet.dmg"
        image.write_bytes(b"candidate image bytes")
        manifest = {"format_version": 1, "status": status, "dmg": image.name,
                    "dmg_sha256": distribute.sha256(image)}
        distribute.save_manifest(self.root, manifest)
        return manifest

    def test_tampered_image_is_rejected_before_upload_or_mount(self):
        self.candidate()
        (self.root / "Nivlet.dmg").write_bytes(b"tampered")
        with patch.object(distribute, "run") as command:
            with self.assertRaisesRegex(ValueError, "checksum"):
                distribute.notarize(argparse.Namespace(input=self.root, output=self.root / "notary", profile="test"))
            command.assert_not_called()
        self.assertFalse((self.root / "notary").exists())

    def test_local_or_failed_candidate_cannot_be_submitted(self):
        for status in ("local-unnotarized", "build-failed", "notarization-failed", "notarized"):
            with self.subTest(status=status):
                self.candidate(status)
                with patch.object(distribute, "run") as command:
                    with self.assertRaisesRegex(ValueError, "signed-unnotarized"):
                        distribute.notarize(argparse.Namespace(input=self.root, output=self.root / "notary", profile="test"))
                    command.assert_not_called()

    def test_manifest_cannot_reference_an_outside_image(self):
        manifest = self.candidate()
        for name in ("../escape.dmg", "/tmp/escape.dmg", "Nivlet.zip"):
            with self.subTest(name=name):
                manifest["dmg"] = name
                distribute.save_manifest(self.root, manifest)
                with self.assertRaisesRegex(ValueError, "Unsafe"):
                    distribute.load_candidate(self.root)

    def test_missing_identity_stops_before_creating_output(self):
        destination = self.root / "signed"
        with patch.object(distribute, "output", return_value="0 valid identities found"):
            with self.assertRaisesRegex(ValueError, "unavailable"):
                distribute.build(argparse.Namespace(local=False, identity="0" * 40, team="A" * 10,
                    version="0.1", build_number="2", output=destination))
        self.assertFalse(destination.exists())

    def test_identity_cannot_match_another_certificate_type_or_team(self):
        for label in ("Apple Development: Person (AAAAAAAAAA)",
                      "Developer ID Application: Person (BBBBBBBBBB)"):
            with self.subTest(label=label):
                with patch.object(distribute, "output", return_value=f'1) {"0" * 40} "{label}"'):
                    with self.assertRaisesRegex(ValueError, "unavailable"):
                        distribute.require_identity("0" * 40, "A" * 10)

    def test_existing_output_is_preserved(self):
        sentinel = self.root / "keep"
        sentinel.write_text("previous release")
        with self.assertRaises(FileExistsError):
            distribute.new_folder(self.root)
        self.assertEqual(sentinel.read_text(), "previous release")

    def inspect(self, entitlements, signature=None):
        app = self.root / "Nivlet.app"
        executable = app / "Contents/MacOS/Nivlet"
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_bytes(b"app bytes")
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleIdentifier": distribute.BUNDLE_ID, "LSUIElement": True,
            "LSMinimumSystemVersion": "14.0", "CFBundleExecutable": "Nivlet",
            "CFBundleShortVersionString": "0.1", "CFBundleVersion": "1"}))
        signature = signature or b"CodeDirectory flags=0x10002(adhoc,runtime)\nSignature=adhoc\n"

        def command(*args, **kwargs):
            stdout, stderr = b"", b""
            if "--entitlements" in args:
                stdout = plistlib.dumps(entitlements)
            elif "--display" in args:
                stderr = signature
            elif "-archs" in args:
                stdout = b"arm64\n"
            return subprocess.CompletedProcess(args, 0, stdout, stderr)

        with patch.object(distribute, "run", side_effect=command):
            return distribute.inspect_app(app, local=True)

    def test_hardened_sandbox_candidate_passes(self):
        entitlements = {"com.apple.security.app-sandbox": True,
                        "com.apple.security.files.user-selected.read-write": True}
        self.assertEqual(self.inspect(entitlements)["entitlements"], entitlements)

    def test_debugger_or_unrelated_permissions_are_rejected(self):
        for key in ("com.apple.security.get-task-allow", "com.apple.security.network.client",
                    "com.apple.security.cs.disable-library-validation"):
            with self.subTest(key=key):
                with self.assertRaisesRegex(ValueError, "Unexpected"):
                    self.inspect({"com.apple.security.app-sandbox": True,
                                  "com.apple.security.files.user-selected.read-write": True, key: True})

    def test_missing_sandbox_or_hardened_runtime_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing required"):
            self.inspect({})
        with self.assertRaisesRegex(ValueError, "Hardened Runtime"):
            self.inspect({"com.apple.security.app-sandbox": True,
                          "com.apple.security.files.user-selected.read-write": True},
                         b"CodeDirectory flags=0x2(adhoc)\nSignature=adhoc\n")


if __name__ == "__main__":
    unittest.main()
