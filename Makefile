# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/NeuronFlame-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
# Build products MUST live outside iCloud Drive. The repo sits in
# com~apple~CloudDocs, and the fileprovider daemon stamps files there with
# extended attributes (FinderInfo/resource forks) asynchronously — codesign
# then fails with "resource fork, Finder information, or similar detritus
# not allowed". Building in $(HOME) keeps the bundle xattr-clean.
BUILD_ROOT := $(HOME)/NeuronFlame-Build
LOCAL_DERIVED_DATA := $(BUILD_ROOT)/local-derived
RELEASE_DERIVED_DATA := $(BUILD_ROOT)/release-derived
RELEASE_DIST_DIR := $(BUILD_ROOT)/dist

# Apple Developer settings for notarised release builds.
# TEAM_ID is public (Apple shows it on the Membership page).
# NOTARY_PROFILE is a Keychain-stored credentials profile created via
# `xcrun notarytool store-credentials` — see Release.xcconfig header.
TEAM_ID := 9J3G49GLLC
NOTARY_PROFILE := neuronflame-notary

# FTP deploy target (neuronflame.com via Hostinger)
FTP_HOST := 88.223.84.163
FTP_USER := u904998269.neuronflame.com
# FTP_PASS comes from the environment variable NEURONFLAME_FTP_PASS to
# keep it out of source. Set in your shell rc:
#   export NEURONFLAME_FTP_PASS='...'
# Or pass on the command line: NEURONFLAME_FTP_PASS=xxx make deploy

.PHONY: all clean whisper setup build local check healthcheck help dev run \
        release dmg notarise notarize staple verify-release deploy ship \
        notary-setup-help appcast

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug CODE_SIGN_IDENTITY="" build

# Build for local use without Apple Developer certificate
local: check setup
	@echo "Building Neuron Flame for local use (no Apple Developer certificate required)..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		CODE_SIGN_ENTITLEMENTS="$(CURDIR)/VoiceInk/VoiceInk.local.entitlements" \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Debug/VoiceInk.app" && \
	if [ -d "$$APP_PATH" ]; then \
		echo "Copying to ~/Downloads/Neuron Flame.app..."; \
		DEST="$$HOME/Downloads/Neuron Flame.app"; \
		rm -rf "$$DEST"; \
		ditto "$$APP_PATH" "$$DEST"; \
		xattr -cr "$$DEST"; \
		echo "Patching CFBundleName to 'Neuron Flame' for the macOS menu bar..."; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Neuron Flame'" "$$DEST/Contents/Info.plist"; \
		echo "Re-signing with stable Ziva AI Developer cert (preserves TCC permissions)..."; \
		codesign --force --sign "Ziva AI Developer" \
			--entitlements "$(CURDIR)/VoiceInk/VoiceInk.local.entitlements" \
			"$$DEST" 2>/dev/null || \
			codesign --force --sign - \
				--entitlements "$(CURDIR)/VoiceInk/VoiceInk.local.entitlements" \
				"$$DEST"; \
		echo ""; \
		echo "Build complete! App saved to: ~/Downloads/Neuron Flame.app"; \
		echo "Run with: open '$$HOME/Downloads/Neuron Flame.app'"; \
		echo ""; \
		echo "Limitations of local builds:"; \
		echo "  - No iCloud dictionary sync"; \
		echo "  - No automatic updates (pull new code and rebuild to update)"; \
	else \
		echo "Error: Could not find built VoiceInk.app at $$APP_PATH"; \
		exit 1; \
	fi

# ─────────────────────────────────────────────────────────────────────
#  RELEASE PIPELINE — Apple-notarised distribution
# ─────────────────────────────────────────────────────────────────────
# `make ship` runs the full chain: build → DMG → notarise → staple → deploy
# Individual steps are also targets so you can iterate on any one of them.

# Sanity-check that the Developer ID cert is installed before we waste time
# building a release that can't be signed.
verify-release:
	@if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application: Ravi Heera Lal Sharma ($(TEAM_ID))"; then \
		echo ""; \
		echo "❌ Developer ID Application certificate not found in Keychain."; \
		echo ""; \
		echo "Open Xcode → Settings → Accounts → Manage Certificates… →"; \
		echo "  + → Developer ID Application"; \
		echo ""; \
		echo "Then verify with:"; \
		echo "  security find-identity -v -p codesigning | grep \"Developer ID\""; \
		echo ""; \
		exit 1; \
	fi
	@echo "✅ Developer ID Application cert present (Team $(TEAM_ID))"

# Build the .app with hardened runtime, signed with Developer ID.
# Output goes to .release-build/, then a copy is placed in .dist/Neuron Flame.app.
release: check setup verify-release
	@echo "Building Neuron Flame for Apple-notarised distribution..."
	@rm -rf "$(RELEASE_DERIVED_DATA)" "$(RELEASE_DIST_DIR)"
	@mkdir -p "$(RELEASE_DIST_DIR)"
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Release \
		-derivedDataPath "$(RELEASE_DERIVED_DATA)" \
		-xcconfig Release.xcconfig \
		CODE_SIGN_ENTITLEMENTS="$(CURDIR)/VoiceInk/VoiceInk.release.entitlements" \
		OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime' \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) RELEASE_BUILD' \
		build
	@APP_PATH="$(RELEASE_DERIVED_DATA)/Build/Products/Release/VoiceInk.app" && \
	if [ -d "$$APP_PATH" ]; then \
		DEST="$(RELEASE_DIST_DIR)/Neuron Flame.app"; \
		ditto "$$APP_PATH" "$$DEST"; \
		xattr -cr "$$DEST"; \
		echo ""; \
		echo "Patching CFBundleName to 'Neuron Flame' (Xcode auto-derives it from"; \
		echo "PRODUCT_NAME=VoiceInk and there's no INFOPLIST_KEY_CFBundleName override).";\
		echo "This is what macOS shows in the application menu (top bar)."; \
		/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Neuron Flame'" "$$DEST/Contents/Info.plist"; \
		echo ""; \
		echo "Re-signing Sparkle nested bundles (Xcode's --deep skips them)..."; \
		./_build/sign-sparkle.sh "$$DEST" "Developer ID Application: Ravi Heera Lal Sharma ($(TEAM_ID))"; \
		echo ""; \
		echo "Re-signing app wrapper to seal Info.plist + Sparkle changes..."; \
		codesign --force --options=runtime --timestamp \
			--entitlements "$(CURDIR)/VoiceInk/VoiceInk.release.entitlements" \
			--sign "Developer ID Application: Ravi Heera Lal Sharma ($(TEAM_ID))" \
			"$$DEST"; \
		echo ""; \
		echo "Verifying full signature..."; \
		codesign --verify --strict --deep --verbose=2 "$$DEST" || { echo "❌ codesign verify failed"; exit 1; }; \
		echo ""; \
		echo "✅ Release app signed and ready at $$DEST"; \
	else \
		echo "❌ Release build did not produce VoiceInk.app at $$APP_PATH"; \
		exit 1; \
	fi

# Bundle the signed .app into a DMG.
# Uses hdiutil with UDZO compression. Includes an /Applications symlink so
# users can drag the app into place from inside the DMG window.
DMG_PATH := $(RELEASE_DIST_DIR)/Neuron Flame.dmg

dmg: release
	@echo "Building DMG..."
	@STAGING="$(RELEASE_DIST_DIR)/dmg-staging" && \
	rm -rf "$$STAGING" && \
	mkdir -p "$$STAGING" && \
	ditto "$(RELEASE_DIST_DIR)/Neuron Flame.app" "$$STAGING/Neuron Flame.app" && \
	ln -s /Applications "$$STAGING/Applications" && \
	rm -f "$(DMG_PATH)" && \
	hdiutil create \
		-volname "Neuron Flame" \
		-srcfolder "$$STAGING" \
		-ov -format UDZO -fs HFS+ \
		"$(DMG_PATH)" >/dev/null && \
	rm -rf "$$STAGING" && \
	echo "Signing DMG..." && \
	codesign --force --sign "Developer ID Application: Ravi Heera Lal Sharma ($(TEAM_ID))" \
		--timestamp \
		"$(DMG_PATH)" && \
	echo "" && \
	echo "✅ DMG built at $(DMG_PATH)" && \
	ls -lh "$(DMG_PATH)"

# Submit DMG to Apple notarisation, wait for the result, then staple.
# Requires a notarytool credentials profile in Keychain — see notary-setup-help.
notarise: dmg
	@echo "Submitting to Apple notarisation service..."
	@if ! xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" >/dev/null 2>&1; then \
		echo ""; \
		echo "❌ Notary profile '$(NOTARY_PROFILE)' not found in Keychain."; \
		echo ""; \
		$(MAKE) notary-setup-help; \
		exit 1; \
	fi
	xcrun notarytool submit "$(DMG_PATH)" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo ""
	@echo "Stapling notarisation ticket to DMG..."
	xcrun stapler staple "$(DMG_PATH)"
	@echo ""
	@echo "Verifying stapling..."
	xcrun stapler validate "$(DMG_PATH)"
	@spctl --assess --type open --context context:primary-signature -v "$(DMG_PATH)" 2>&1 || true
	@echo ""
	@echo "✅ DMG notarised and stapled — ready to distribute."

# US English alias.
notarize: notarise

# Generate appcast.xml from the notarised DMG: signs with EdDSA private key
# in Keychain, embeds release notes from _build/release_notes.html, writes
# to ./appcast.xml + website/appcast.xml. Runs automatically as part of
# `make ship` so every release updates the Sparkle feed.
appcast:
	@if [ ! -f "$(DMG_PATH)" ]; then \
		echo "❌ No DMG to sign at $(DMG_PATH) — run 'make notarise' first."; \
		exit 1; \
	fi
	@SPARKLE_BIN="$(RELEASE_DERIVED_DATA)/SourcePackages/artifacts/sparkle/Sparkle/bin"; \
	if [ ! -x "$$SPARKLE_BIN/sign_update" ]; then \
		SPARKLE_BIN="$(LOCAL_DERIVED_DATA)/SourcePackages/artifacts/sparkle/Sparkle/bin"; \
	fi; \
	if [ ! -x "$$SPARKLE_BIN/sign_update" ]; then \
		echo "❌ Sparkle's sign_update tool not found."; \
		echo "   Run 'make release' first so the package is fetched."; \
		exit 1; \
	fi; \
	echo "Generating signed appcast.xml..."; \
	python3 _build/build_appcast.py "$(DMG_PATH)" "$$SPARKLE_BIN"

# Re-staple an already-notarised DMG (rarely needed).
staple:
	xcrun stapler staple "$(DMG_PATH)"

# Copy the notarised DMG into the website tree, then FTP-upload.
deploy:
	@if [ ! -f "$(DMG_PATH)" ]; then \
		echo "❌ No DMG at $(DMG_PATH) — run 'make ship' or 'make notarise' first."; \
		exit 1; \
	fi
	@if [ -z "$$NEURONFLAME_FTP_PASS" ]; then \
		echo "❌ Set NEURONFLAME_FTP_PASS environment variable to deploy."; \
		echo "   export NEURONFLAME_FTP_PASS='...'"; \
		exit 1; \
	fi
	@command -v lftp >/dev/null 2>&1 || { echo "❌ lftp not installed (brew install lftp)"; exit 1; }
	@echo "Copying DMG into website tree..."
	@mkdir -p website/downloads
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(RELEASE_DIST_DIR)/Neuron Flame.app/Contents/Info.plist") && \
	cp "$(DMG_PATH)" "website/downloads/Neuron Flame.dmg" && \
	cp "$(DMG_PATH)" "website/downloads/Neuron Flame-$$VERSION.dmg" && \
	echo "  → versioned: website/downloads/Neuron Flame-$$VERSION.dmg" && \
	echo "  → latest:    website/downloads/Neuron Flame.dmg"
	@echo "Deploying website + DMG via FTP..."
	@cd website && lftp -u "$(FTP_USER),$$NEURONFLAME_FTP_PASS" -p 21 $(FTP_HOST) \
		-e "set ftp:passive-mode true; set ssl:verify-certificate no; \
		    mirror -R --verbose --parallel=4 --only-newer --exclude=^_build/ ./ ./; bye"
	@echo ""
	@echo "✅ Deployed. Verify at https://neuronflame.com/"

# Full ship pipeline — build, dmg, notarise, sign update, deploy.
# After deploy, the appcast.xml is live at https://neuronflame.com/appcast.xml
# and existing installs will pick up the new version on their next
# "Check for Updates" (or auto-prompt within ~24h via SUEnableAutomaticChecks).
ship: notarise appcast deploy
	@echo ""
	@echo "🚀 Shipped — neuronflame.com is live with the latest notarised DMG."
	@echo "   Existing installs will see the update via Sparkle within 24h."

# One-time setup instructions for the notarisation credentials profile.
notary-setup-help:
	@echo ""
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "  One-time notarytool credentials setup"
	@echo "──────────────────────────────────────────────────────────────────"
	@echo ""
	@echo "Run this command once on this Mac (replace placeholders):"
	@echo ""
	@echo "  xcrun notarytool store-credentials \"$(NOTARY_PROFILE)\" \\"
	@echo "      --apple-id \"YOUR_APPLE_ID@example.com\" \\"
	@echo "      --team-id  \"$(TEAM_ID)\" \\"
	@echo "      --password \"abcd-efgh-ijkl-mnop\""
	@echo ""
	@echo "  • Apple ID = the email tied to your Apple Developer Program."
	@echo "  • Password = an app-specific password. Create at"
	@echo "    https://account.apple.com/account/manage → Sign-In and"
	@echo "    Security → App-Specific Passwords → '+' → label it 'Neuron"
	@echo "    Flame Notarisation'."
	@echo ""
	@echo "The credentials are stored in your login Keychain. The profile"
	@echo "name '$(NOTARY_PROFILE)' is referenced by 'make notarise'."
	@echo ""
	@echo "Verify with:  xcrun notarytool history --keychain-profile $(NOTARY_PROFILE)"
	@echo ""

# Run application
run:
	@if [ -d "$$HOME/Downloads/Neuron Flame.app" ]; then \
		echo "Opening ~/Downloads/Neuron Flame.app..."; \
		open "$$HOME/Downloads/Neuron Flame.app"; \
	elif [ -d "$$HOME/Downloads/VoiceInk.app" ]; then \
		echo "Opening ~/Downloads/VoiceInk.app..."; \
		open "$$HOME/Downloads/VoiceInk.app"; \
	else \
		echo "Looking for app in DerivedData..."; \
		APP_PATH=$$(find "$(LOCAL_DERIVED_DATA)" "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -type d 2>/dev/null | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Found app at: $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "App not found. Please run 'make local' first."; \
			exit 1; \
		fi; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR) $(LOCAL_DERIVED_DATA) $(RELEASE_DERIVED_DATA) $(RELEASE_DIST_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Local development (no Apple Developer cert needed)"
	@echo "    local              Build self-signed app to ~/Downloads/Neuron Flame.app"
	@echo "    run                Launch the built app"
	@echo "    dev                Build and run"
	@echo ""
	@echo "  Release pipeline (requires Apple Developer Program enrolment)"
	@echo "    verify-release     Sanity-check that Developer ID cert is in Keychain"
	@echo "    release            Build hardened-runtime app signed with Developer ID"
	@echo "    dmg                release + create signed DMG"
	@echo "    notarise           dmg + submit to Apple + staple ticket"
	@echo "    deploy             FTP-upload the notarised DMG to neuronflame.com"
	@echo "    ship               Full chain: notarise + deploy in one command"
	@echo "    notary-setup-help  One-time credentials setup instructions"
	@echo ""
	@echo "  Misc"
	@echo "    setup              Build whisper.xcframework dependency"
	@echo "    clean              Remove build + dist directories"
	@echo "    help               Show this message"
