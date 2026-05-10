#!/usr/bin/env bash
#
# Re-sign Sparkle's nested helper bundles with the Developer ID cert.
#
# Why this exists: Sparkle ships pre-built helper executables (Autoupdate,
# Updater.app, Downloader.xpc, Installer.xpc) that arrive in the framework
# pre-signed by Sparkle's own developer cert. Xcode's --deep signing pass
# does NOT recursively re-sign nested .xpc / .app bundles — it only signs
# the framework's main dylib and wrapper. The pre-existing inner signatures
# fail Apple notarisation because they're signed with the wrong cert and
# missing the required `--timestamp` flag.
#
# The fix: manually re-sign each nested component, INNERMOST FIRST. Order
# is important — once a parent is signed, you can't re-sign a child without
# breaking the parent's seal.
#
# Usage:
#   ./_build/sign-sparkle.sh "/path/to/App.app" "Developer ID Application: NAME (TEAMID)"
#
# Reference: https://sparkle-project.org/documentation/sandboxing/

set -euo pipefail

APP_PATH="${1:?Usage: sign-sparkle.sh <app-path> <signing-identity>}"
IDENTITY="${2:?Usage: sign-sparkle.sh <app-path> <signing-identity>}"

SPARKLE="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ ! -d "$SPARKLE" ]; then
    echo "❌ Sparkle.framework not found at $SPARKLE"
    exit 1
fi

# Find the active version directory (Sparkle uses /Versions/A or /Versions/B
# depending on release).
VERSION_DIR="$(readlink "$SPARKLE/Versions/Current" 2>/dev/null || echo "B")"
V="$SPARKLE/Versions/$VERSION_DIR"

if [ ! -d "$V" ]; then
    # Fall back to whichever version directory exists
    V="$(find "$SPARKLE/Versions" -maxdepth 1 -mindepth 1 -type d ! -name Current | head -1)"
fi

echo "Re-signing Sparkle components in $V..."
echo "  Identity: $IDENTITY"

# Common codesign args. --timestamp + --options=runtime are mandatory for
# notarisation. --force replaces existing signatures.
#
# CRITICAL: --preserve-metadata=identifier,entitlements,flags is required
# because Sparkle's Autoupdate ships with an embedded
# `com.apple.application-identifier = org.sparkle-project.Sparkle.Autoupdate`
# entitlement that namespaces its cache directory at ~/Library/Caches/<app>/
# org.sparkle-project.Sparkle/. Without preserving entitlements, the resign
# strips this entitlement and the running Autoupdate process fails to mkdir
# its cache directory — symptoms are:
#   "Failed to create installation cache directory in ~/Library/Caches/..."
#   "Timeout: Installer never started archive extraction"
#   "remote port connection was invalidated from the updater"
# (These were all live in v1.78–v1.80; fixed from v1.81 onwards.)
CS=(codesign --force --options=runtime --timestamp \
    --preserve-metadata=identifier,entitlements,flags \
    --sign "$IDENTITY")

# Sign innermost first.
sign_path() {
    local p="$1"
    if [ -e "$p" ]; then
        echo "  → $p"
        "${CS[@]}" "$p"
    fi
}

# 1. Inner XPC service binaries
sign_path "$V/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
sign_path "$V/XPCServices/Installer.xpc/Contents/MacOS/Installer"

# 2. The XPC wrapper bundles themselves
sign_path "$V/XPCServices/Downloader.xpc"
sign_path "$V/XPCServices/Installer.xpc"

# 3. Updater.app's inner binary
sign_path "$V/Updater.app/Contents/MacOS/Updater"

# 4. Updater.app wrapper
sign_path "$V/Updater.app"

# 5. Autoupdate executable
sign_path "$V/Autoupdate"

# 6. Sparkle main dylib (the framework's primary binary)
sign_path "$V/Sparkle"

# 7. The framework version directory itself
sign_path "$V"

# 8. The whole framework wrapper (refreshes the top-level seal)
sign_path "$SPARKLE"

echo ""
echo "Verifying Sparkle signature..."
codesign --verify --strict --verbose=2 "$SPARKLE" || {
    echo "❌ Sparkle.framework signature verification failed."
    exit 1
}

echo "✅ Sparkle re-signed cleanly."
