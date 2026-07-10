import Foundation
import AppKit
import Carbon
import os

private let logger = Logger(subsystem: "com.neuronflame.app", category: "CursorPaster")

class CursorPaster {
    private typealias ClipboardSnapshot = [(NSPasteboard.PasteboardType, Data)]

    static func pasteAtCursor(_ text: String) {
        Task {
            await MainActor.run {
                startPasteAtCursor(text)
            }.value
        }
    }

    @MainActor
    @discardableResult
    static func startPasteAtCursor(_ text: String) -> Task<Void, Never> {
        // Secure input (password fields, some terminals with secure keyboard
        // entry, unlock dialogs) swallows ALL synthetic keyboard events —
        // both the Cmd+V CGEvents and unicode direct-typing. Attempting to
        // insert would silently drop the transcription. Instead: park the
        // text on the clipboard (non-transient, so it survives), play the
        // esc cue, and let the user paste with a real ⌘V keypress — real
        // keystrokes are exactly what secure input still allows.
        if IsSecureEventInputEnabled() {
            _ = ClipboardManager.setClipboard(text, transient: false)
            SoundManager.shared.playEscSound()
            logger.error("Secure input active — transcription parked on clipboard; press ⌘V to paste")
            return Task { @MainActor in }
        }

        // Resolve insertion mode BEFORE touching the clipboard. In "type" mode
        // we bypass the clipboard entirely — writing to it would be wasted
        // work and would needlessly stomp on the user's clipboard contents.
        let mode = resolvedInsertionMode()

        if mode == .type {
            return Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                typeTextDirectly(text)
            }
        }

        let pasteboard = NSPasteboard.general
        let shouldRestoreClipboard = UserDefaults.standard.bool(forKey: "restoreClipboardAfterPaste")
        let savedContents = shouldRestoreClipboard ? snapshotClipboard(from: pasteboard) : []

        _ = ClipboardManager.setClipboard(text, transient: shouldRestoreClipboard)

        return Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            postPasteCommand()

            if shouldRestoreClipboard {
                scheduleClipboardRestore(savedContents, on: pasteboard)
            }
        }
    }

    // MARK: - Insertion mode resolution

    private enum ResolvedInsertionMode { case paste, type }

    /// Bundle ID prefixes of apps where Cmd+V doesn't survive — the local
    /// client eats the Cmd modifier and only the bare V keystroke is
    /// forwarded to the remote machine. For these we type characters
    /// directly via CGEvent.keyboardSetUnicodeString so every character
    /// gets forwarded as a regular keystroke.
    private static let remoteDesktopBundlePrefixes: [String] = [
        "com.apple.ScreenSharing",
        "com.apple.RemoteDesktop",          // Apple Remote Desktop (admin)
        "com.microsoft.rdc",                // Microsoft Remote Desktop (any platform suffix)
        "com.parallels.",                   // Parallels Desktop / Client / RAS
        "com.vmware.fusion",
        "com.vmware.horizon",
        "com.anydesk.AnyDesk",
        "com.teamviewer.TeamViewer",
        "com.citrix.",                      // Citrix Workspace / Receiver
        "com.jumpdesktop.viewer",
        "com.p5sys.jump",                   // older Jump Desktop bundle
        "com.realvnc.vncviewer",
        "com.tigervnc.vncviewer",
        "com.devolutions.remotedesktopmanager",
        "com.nulana.rdmmac",                // Remotix
        "com.splashtop.",
        "com.nomachine.nxplayer",
        "com.google.chromeremotedesktop",
        "com.chrome.remote-desktop",
    ]

    private static var frontmostIsRemoteDesktop: Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return remoteDesktopBundlePrefixes.contains { bundleID.hasPrefix($0) }
    }

    private static func resolvedInsertionMode() -> ResolvedInsertionMode {
        let raw = UserDefaults.standard.string(forKey: "insertionMode") ?? "auto"
        switch raw {
        case "paste":
            return .paste
        case "type":
            return .type
        default:
            // Auto: detect remote-desktop / VM client in the foreground.
            if frontmostIsRemoteDesktop {
                logger.notice("Auto-insertion: remote desktop detected, typing directly")
                return .type
            }
            return .paste
        }
    }

    // MARK: - Direct typing (bypass clipboard for remote desktop / VM apps)

    /// Posts the text as a sequence of CGEvents using keyboardSetUnicodeString,
    /// in small chunks. Each chunk becomes one synthetic keydown event carrying
    /// the unicode payload — no modifier keys involved, so remote-desktop
    /// clients forward every character intact to the remote machine.
    ///
    /// Chunk size 20 keeps each event well under the documented practical
    /// limit; the 3 ms inter-chunk pause lets remote-forwarding pipelines
    /// drain before the next event arrives.
    private static func typeTextDirectly(_ text: String) {
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility not trusted — cannot type directly")
            return
        }
        guard !text.isEmpty else { return }

        let source = CGEventSource(stateID: .privateState)
        let utf16 = Array(text.utf16)
        let chunkSize = 20
        var index = 0

        while index < utf16.count {
            let end = min(index + chunkSize, utf16.count)
            let chunk = Array(utf16[index..<end])

            // Both keyDown AND keyUp are required. Without a matching keyUp,
            // macOS treats the keyDown as "key is being held" and triggers the
            // press-and-hold accent picker on the receiving app (you see
            // "à á â ä ǎ æ ã å ā" pop up over the input field instead of the
            // text being typed). Posting keyDown immediately followed by keyUp
            // is the standard pattern.
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            chunk.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                down?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: base)
                up?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: base)
            }

            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)

            usleep(3_000) // 3 ms between chunks
            index = end
        }

        logger.notice("Typed \(text.count) characters directly")
    }

    @MainActor
    static func pasteAtCursorAndWaitUntilPosted(_ text: String) async {
        await startPasteAtCursor(text).value
    }

    private static func snapshotClipboard(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        var savedContents: ClipboardSnapshot = []
        let currentItems = pasteboard.pasteboardItems ?? []

        for item in currentItems {
            for type in item.types {
                if let data = item.data(forType: type) {
                    savedContents.append((type, data))
                }
            }
        }

        return savedContents
    }

    private static func postPasteCommand() {
        if UserDefaults.standard.bool(forKey: "useAppleScriptPaste") {
            pasteUsingAppleScript()
        } else {
            pasteFromClipboard()
        }
    }

    private static func scheduleClipboardRestore(_ savedContents: ClipboardSnapshot, on pasteboard: NSPasteboard) {
        let restoreDelay = UserDefaults.standard.double(forKey: "clipboardRestoreDelay")
        let delay = max(restoreDelay, 0.25)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if !savedContents.isEmpty {
                pasteboard.clearContents()
                for (type, data) in savedContents {
                    pasteboard.setData(data, forType: type)
                }
            }
        }
    }

    // MARK: - AppleScript paste

    // "X – QWERTY ⌘" layouts remap to QWERTY when Command is held, so keystroke "v" resolves
    // the wrong key code. key code 9 (physical V) bypasses layout translation for those layouts.
    private static func makeScript(_ source: String) -> NSAppleScript? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.compileAndReturnError(&error)
        return script
    }

    private static let pasteScriptKeystroke = makeScript("tell application \"System Events\" to keystroke \"v\" using command down")
    private static let pasteScriptKeyCode   = makeScript("tell application \"System Events\" to key code 9 using command down")

    private static var layoutSwitchesToQWERTYOnCommand: Bool {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let nameRef = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return false }
        return (Unmanaged<CFString>.fromOpaque(nameRef).takeUnretainedValue() as String).hasSuffix("⌘")
    }

    private static func pasteUsingAppleScript() {
        let script = layoutSwitchesToQWERTYOnCommand ? pasteScriptKeyCode : pasteScriptKeystroke
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            logger.error("AppleScript paste failed: \(error, privacy: .public)")
        }
    }

    // MARK: - CGEvent paste

    // Posts Cmd+V via CGEvent without modifying the active input source.
    private static func pasteFromClipboard() {
        guard AXIsProcessTrusted() else {
            logger.error("Accessibility not trusted — cannot paste")
            return
        }

        let source = CGEventSource(stateID: .privateState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp     = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags   = .maskCommand
        vUp?.flags     = .maskCommand

        // Tiny gaps between the modifier and the key let some remote-desktop
        // or virtualisation clients register the Cmd state before the V key
        // arrives. Without them, those clients occasionally see a bare "v".
        cmdDown?.post(tap: .cghidEventTap)
        usleep(2_000)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        usleep(2_000)
        cmdUp?.post(tap: .cghidEventTap)

        logger.notice("CGEvents posted for Cmd+V")
    }

    // MARK: - Auto Send Keys

    static func performAutoSend(_ key: AutoSendKey) {
        guard key.isEnabled else { return }
        guard AXIsProcessTrusted() else { return }

        let source = CGEventSource(stateID: .privateState)
        let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
        let enterUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)

        switch key {
        case .none: return
        case .enter: break
        case .shiftEnter:
            enterDown?.flags = .maskShift
            enterUp?.flags   = .maskShift
        case .commandEnter:
            enterDown?.flags = .maskCommand
            enterUp?.flags   = .maskCommand
        }

        enterDown?.post(tap: .cghidEventTap)
        enterUp?.post(tap: .cghidEventTap)
    }
}
