#!/usr/bin/env python3
"""
Generate / update appcast.xml after a notarised DMG is built.

Sparkle pulls https://neuronflame.com/appcast.xml on every "Check for
Updates". The feed needs to:
  1. List the latest version
  2. Reference the exact DMG URL on neuronflame.com
  3. Carry the EdDSA signature so the running app can verify the DMG
     before installing it
  4. Include release notes (rendered inside the Sparkle update dialog)

This script is invoked from the Makefile after `make notarise`. It:
  - Reads CFBundleShortVersionString + CFBundleVersion from the staged
    Neuron Flame.app (so version is the source of truth, not a flag)
  - Computes file length
  - Runs `sign_update` (Sparkle's CLI) to produce the EdDSA signature
    using the private key in macOS login Keychain
  - Renders a fresh appcast.xml at the project root
  - Copies it into website/appcast.xml so `make deploy` ships it

Release notes for the latest version live in
_build/release_notes.html — keep that file fresh per release.

Usage:
    python3 _build/build_appcast.py <dmg_path> <sparkle_bin_dir>
"""
import os
import sys
import plistlib
import subprocess
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent

def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <dmg_path> <sparkle_bin_dir>", file=sys.stderr)
        sys.exit(1)

    dmg = Path(sys.argv[1]).resolve()
    sparkle_bin = Path(sys.argv[2]).resolve()
    sign_update = sparkle_bin / "sign_update"

    if not dmg.exists():
        sys.exit(f"DMG not found: {dmg}")
    if not sign_update.exists():
        sys.exit(f"sign_update tool not found: {sign_update}")

    # Pull version from the .app inside the DMG. We'd need to mount the DMG
    # to do this from the DMG itself, so instead we read from the staged
    # .app one folder up from the DMG (the Makefile leaves it at
    # .dist/Neuron Flame.app).
    app_plist = dmg.parent / "Neuron Flame.app" / "Contents" / "Info.plist"
    with open(app_plist, "rb") as f:
        info = plistlib.load(f)
    short_version = info["CFBundleShortVersionString"]
    build_number = info["CFBundleVersion"]
    min_system = info.get("LSMinimumSystemVersion", "14.4")

    length = dmg.stat().st_size

    print(f"  version:    {short_version} (build {build_number})")
    print(f"  size:       {length:,} bytes")
    print(f"  min macOS:  {min_system}")

    # Sign the DMG with the EdDSA private key in Keychain.
    sig_output = subprocess.run(
        [str(sign_update), str(dmg)],
        capture_output=True, text=True, check=True
    ).stdout.strip()
    # sign_update prints e.g.:
    #   sparkle:edSignature="..." length="..."
    print(f"  signature:  {sig_output}")

    # Release notes — pulled from the per-release HTML file. Falls back to a
    # generic placeholder if the file is missing.
    notes_path = ROOT / "_build" / "release_notes.html"
    if notes_path.exists():
        notes_html = notes_path.read_text()
    else:
        notes_html = f"<h3>v{short_version}</h3><p>Maintenance update.</p>"

    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")
    # Versioned URL for Sparkle auto-update. Every release lives at an
    # immutable URL so the CDN never serves stale bytes from a previous
    # release's cache. This was a real bug in v1.86–v1.88: Hostinger's
    # CDN aggressively cached `Neuron Flame.dmg` for 24h, so when we
    # shipped a newer version, edges kept serving the older bytes —
    # Sparkle's EdDSA signature check then correctly rejected the
    # mismatch ("downloaded archive length differs from appcast item").
    # The generic `/Neuron Flame.dmg` URL is still uploaded (and is what
    # the website Download button points at) — it's allowed to be cached
    # because manual downloaders don't verify signatures the same way.
    dmg_url = f"https://neuronflame.com/downloads/Neuron%20Flame-{short_version}.dmg"

    appcast = f"""<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Neuron Flame</title>
        <link>https://neuronflame.com/appcast.xml</link>
        <description>Voice-to-text at the speed of thought. Free, on-device dictation for macOS.</description>
        <language>en</language>
        <item>
            <title>{short_version}</title>
            <description><![CDATA[{notes_html.strip()}]]></description>
            <pubDate>{pub_date}</pubDate>
            <sparkle:version>{build_number}</sparkle:version>
            <sparkle:shortVersionString>{short_version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>{min_system}</sparkle:minimumSystemVersion>
            <enclosure url="{dmg_url}" {sig_output} type="application/octet-stream"/>
        </item>
    </channel>
</rss>
"""

    # Write to root + website tree
    (ROOT / "appcast.xml").write_text(appcast)
    website_appcast = ROOT / "website" / "appcast.xml"
    website_appcast.parent.mkdir(parents=True, exist_ok=True)
    website_appcast.write_text(appcast)

    print(f"\n  ✅ wrote appcast.xml (root + website/)")
    print(f"     SUFeedURL → https://neuronflame.com/appcast.xml")


if __name__ == "__main__":
    main()
