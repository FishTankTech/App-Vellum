// CapturePanel.swift

import Cocoa



class CaptureTextView: NSTextView {
    var onEscape: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        return false
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func paste(_ sender: Any?) {
        self.pasteAsPlainText(sender)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased() {

            switch chars {
            case "z":
                if event.modifierFlags.contains(.shift) {
                    undoManager?.redo()
                } else {
                    undoManager?.undo()
                }
                return

            case "a":
                selectAll(nil)
                return

            case "c":
                copy(nil)
                return

            case "x":
                cut(nil)
                return

            case "v":
                paste(nil)
                return

            default:
                break
            }
        }

        super.keyDown(with: event)
    }
}


class CapturePanel: NSPanel, NSTextViewDelegate {

    let textView = CaptureTextView()

    private let scrollView = NSScrollView()
    private let visualEffectView = NSVisualEffectView()



    private let savedLabel = NSTextField(labelWithString: "Saved")
    private let countLabel = NSTextField(labelWithString: "")
    private let mathPreviewLabel = NSTextField(labelWithString: "")
    private let firstRunHintLabel = NSTextField(labelWithString: "")
    private let routingLabel = NSTextField(labelWithString: "")

    private let storage: NotesStorage
    private let mode: CaptureMode

    private var writeTimer: Timer?
    private var savedLabelHideTimer: Timer?
    private var mathPreviewTimer: Timer?
    private var firstRunHintHideTimer: Timer?

    var onRequestDismiss: (() -> Void)?

    
    init(mode: CaptureMode = .permanent) {

        self.mode = mode
        self.storage = NotesStorage(mode: mode)

        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: 480,
            height: 160
        )

        super.init(
            contentRect: contentRect,
            styleMask: [
                .titled,
                .closable,
                .nonactivatingPanel,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )


        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary
        ]

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true


        setupVisualEffect(contentRect: contentRect)
        setupTextView(contentRect: contentRect)
        setupSavedLabel()
        setupCountLabel()
        setupMathPreviewLabel()
        setupFirstRunHintLabel()
        setupRoutingLabel()

        centerOnActiveScreen()


        textView.onEscape = { [weak self] in
            self?.onRequestDismiss?()
        }
    }


    private func setupVisualEffect(contentRect: NSRect) {

        visualEffectView.frame = contentRect
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active

        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true

        visualEffectView.autoresizingMask = [
            .width,
            .height
        ]

        contentView = visualEffectView
    }


private func setupTextView(contentRect: NSRect) {

    // Height of the footer strip reserved for the count / saved labels.
    let footerHeight: CGFloat = 26

    let scrollFrame = NSRect(
        x: 0,
        y: footerHeight,
        width: contentRect.width,
        height: contentRect.height - footerHeight
    )

    textView.frame = scrollFrame
    textView.font = NSFont.systemFont(ofSize: 15)

    textView.isRichText = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.drawsBackground = false

    textView.textContainerInset = NSSize(width: 14, height: 14)

    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = true

    textView.allowsUndo = true
    textView.delegate = self

    scrollView.frame = scrollFrame
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.autoresizingMask = [.width, .height]

    textView.minSize = NSSize(width: 0, height: scrollFrame.height)
    textView.maxSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
    )

    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false

    textView.textContainer?.containerSize = NSSize(
        width: scrollFrame.width,
        height: CGFloat.greatestFiniteMagnitude
    )
    textView.textContainer?.widthTracksTextView = true

    scrollView.documentView = textView
    visualEffectView.addSubview(scrollView)
}


    private func setupSavedLabel() {

        savedLabel.font = NSFont.systemFont(
            ofSize: 11,
            weight: .medium
        )

        savedLabel.textColor = .secondaryLabelColor
        savedLabel.alphaValue = 0

        savedLabel.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(savedLabel)


        NSLayoutConstraint.activate([
            savedLabel.trailingAnchor.constraint(
                equalTo: visualEffectView.trailingAnchor,
                constant: -12
            ),

            savedLabel.bottomAnchor.constraint(
                equalTo: visualEffectView.bottomAnchor,
                constant: -8
            )
        ])
    }


    private func setupCountLabel() {

        countLabel.font = NSFont.systemFont(
            ofSize: 11,
            weight: .regular
        )

        countLabel.textColor = .tertiaryLabelColor

        countLabel.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(countLabel)


        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(
                equalTo: visualEffectView.leadingAnchor,
                constant: 14
            ),

            countLabel.bottomAnchor.constraint(
                equalTo: visualEffectView.bottomAnchor,
                constant: -8
            )
        ])
    }


    private func setupMathPreviewLabel() {

        mathPreviewLabel.font = NSFont.monospacedDigitSystemFont(
            ofSize: 14,
            weight: .medium
        )

        mathPreviewLabel.textColor = .secondaryLabelColor
        mathPreviewLabel.isEditable = false
        mathPreviewLabel.isSelectable = false
        mathPreviewLabel.isBezeled = false
        mathPreviewLabel.drawsBackground = false
        mathPreviewLabel.isHidden = true
        mathPreviewLabel.lineBreakMode = .byClipping

        // Added directly to the text view so its frame lives in the same
        // (flipped) coordinate space as glyph geometry from the layout
        // manager, and so it scrolls naturally with the text.
        textView.addSubview(mathPreviewLabel)
    }


    // MARK: - First Run Hint

    private func setupFirstRunHintLabel() {

        firstRunHintLabel.font = NSFont.systemFont(
            ofSize: 11,
            weight: .medium
        )

        firstRunHintLabel.textColor = .secondaryLabelColor
        firstRunHintLabel.alignment = .center
        firstRunHintLabel.alphaValue = 0
        firstRunHintLabel.isEditable = false
        firstRunHintLabel.isBezeled = false
        firstRunHintLabel.drawsBackground = false

        firstRunHintLabel.maximumNumberOfLines = 3
        firstRunHintLabel.stringValue =
            "⌥⌘N to open\nEsc to dismiss\nYour text saves automatically."

        firstRunHintLabel.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(firstRunHintLabel)


        NSLayoutConstraint.activate([
            firstRunHintLabel.centerXAnchor.constraint(
                equalTo: visualEffectView.centerXAnchor
            ),

            firstRunHintLabel.centerYAnchor.constraint(
                equalTo: visualEffectView.centerYAnchor
            )
        ])
    }


    /// Shows the onboarding hint automatically, only if it hasn't been
    /// seen before. Called from showPanel() on every open — no-op after
    /// the first time.
    func showFirstRunHintIfNeeded() {

        guard !PreferencesManager.shared.hasShownFirstRunHint else {
            return
        }

        PreferencesManager.shared.hasShownFirstRunHint = true

        animateFirstRunHint()
    }


    /// Shows the onboarding hint on demand, regardless of whether it's
    /// been seen before. Used by the "Quick Tips" menu bar item.
    func showFirstRunHint() {
        animateFirstRunHint()
    }


    private func animateFirstRunHint() {

        NSAnimationContext.runAnimationGroup { context in

            context.duration = 0.3

            firstRunHintLabel.animator().alphaValue = 1
        }


        firstRunHintHideTimer?.invalidate()


        firstRunHintHideTimer =
        Timer.scheduledTimer(
            withTimeInterval: 4.0,
            repeats: false
        ) { [weak self] _ in

            NSAnimationContext.runAnimationGroup { context in

                context.duration = 0.5

                self?.firstRunHintLabel.animator().alphaValue = 0
            }
        }
    }


    // MARK: - Routing Feedback

    private func setupRoutingLabel() {

        routingLabel.font = NSFont.systemFont(
            ofSize: 10,
            weight: .medium
        )

        routingLabel.textColor = .secondaryLabelColor
        routingLabel.alignment = .right
        routingLabel.isEditable = false
        routingLabel.isBezeled = false
        routingLabel.drawsBackground = false
        routingLabel.isHidden = true

        routingLabel.maximumNumberOfLines = 2
        routingLabel.lineBreakMode = .byWordWrapping

        routingLabel.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(routingLabel)


        NSLayoutConstraint.activate([
            routingLabel.topAnchor.constraint(
                equalTo: visualEffectView.topAnchor,
                constant: 8
            ),

            routingLabel.trailingAnchor.constraint(
                equalTo: visualEffectView.trailingAnchor,
                constant: -12
            ),

            routingLabel.widthAnchor.constraint(
                lessThanOrEqualToConstant: 200
            )
        ])
    }


    /// Updates the "→ Destination.md" indicator to reflect the tag (if
    /// any) currently at the start of the text. 
    /// IF TAG IS NOT FOUND - It always routes to notes.md and flags it
    /// explicitly, mirroring exactly what NotesStorage will do on save.
    private func updateRoutingFeedback() {

        guard mode == .permanent,
              let preview = storage.routingPreview(for: textView.string) else {
            routingLabel.isHidden = true
            return
        }

        if preview.isRecognized {
            routingLabel.textColor = .secondaryLabelColor
            routingLabel.stringValue = "→ \(preview.destinationFilename)"
        } else {
            routingLabel.textColor = .systemOrange
            routingLabel.stringValue = "→ \(preview.destinationFilename)\nUnknown tag"
        }

        routingLabel.isHidden = false
    }


    func centerOnActiveScreen() {

        guard let screen = NSScreen.main else {
            return
        }

        let frame = screen.visibleFrame

        setFrameOrigin(
            NSPoint(
                x: frame.midX - self.frame.width / 2,
                y: frame.midY - self.frame.height / 2
            )
        )
    }


    func beginNewCapture() {

        let (text, isContinuing) = storage.beginSession()

        textView.string = text

        let position = (text as NSString).length

        textView.setSelectedRange(
            NSRange(
                location: position,
                length: 0
            )
        )

        savedLabel.alphaValue = 0

        updateCountLabel()
        updateRoutingFeedback()

        mathPreviewTimer?.invalidate()
        mathPreviewLabel.isHidden = true


        if isContinuing {
            showContinuingIndicator()
        }
    }


    func flushCurrentText() {

        writeTimer?.invalidate()
        mathPreviewTimer?.invalidate()

        storage.updateSession(
            text: textView.string
        )

        storage.endSession()
    }


    func focusTextView() {
        makeFirstResponder(textView)
    }


    func animateIn() {

        alphaValue = 0

        let target = frame

        var start = target
        start.origin.y += 8

        setFrame(
            start,
            display: false
        )


        makeKeyAndOrderFront(nil)


        NSAnimationContext.runAnimationGroup { context in

            context.duration = 0.14

            animator().alphaValue = 1

            animator().setFrame(
                target,
                display: true
            )
        }
    }


    func animateOut(completion: @escaping () -> Void) {

        NSAnimationContext.runAnimationGroup({

            context in

            context.duration = 0.1

            animator().alphaValue = 0

        }) {

            self.orderOut(nil)

            self.alphaValue = 1

            completion()
        }
    }


    private func updateCountLabel() {

        let text = textView.string

        let words = text.split {
            $0.isWhitespace ||
            $0.isNewline
        }


        let wordCount = words.count
        let charCount = text.count


        if wordCount == 0 {

            countLabel.stringValue = ""

        } else if wordCount == 1 {

            countLabel.stringValue =
            "1 word · \(charCount) chars"

        } else {

            countLabel.stringValue =
            "\(wordCount) words · \(charCount) chars"
        }
    }



    func textDidChange(_ notification: Notification) {

    if handleClearCommandIfPresent() {
        return
    }

    updateCountLabel()
    updateRoutingFeedback()

    writeTimer?.invalidate()

    savedLabelHideTimer?.invalidate()

    savedLabel.animator().alphaValue = 0


    writeTimer = Timer.scheduledTimer(
        withTimeInterval: 0.3,
        repeats: false
    ) { [weak self] _ in

        guard let self else {
            return
        }

        self.storage.updateSession(
            text: self.textView.string
        )

        self.showSavedIndicator()
    }

    scheduleMathPreview()
}


    func textViewDidChangeSelection(_ notification: Notification) {
        scheduleMathPreview()
    }


    // MARK: - Inline Math

    /// Hides any stale result immediately (so we never show a result for
    /// text that no longer matches it) and, after a short pause with no
    /// further typing or cursor movement, evaluates the current line.
    private func scheduleMathPreview() {

        mathPreviewLabel.isHidden = true
        mathPreviewTimer?.invalidate()

        guard PreferencesManager.shared.inlineMathEnabled else {
            return
        }

        mathPreviewTimer = Timer.scheduledTimer(
            withTimeInterval: PreferencesManager.shared.mathPreviewDelay,
            repeats: false
        ) { [weak self] _ in
            self?.updateMathPreview()
        }
    }


    private func updateMathPreview() {

        guard PreferencesManager.shared.inlineMathEnabled else {
            mathPreviewLabel.isHidden = true
            return
        }

        let nsText = textView.string as NSString
        let caret = textView.selectedRange().location

        guard caret <= nsText.length else {
            mathPreviewLabel.isHidden = true
            return
        }

        let lineRange = nsText.lineRange(
            for: NSRange(location: caret, length: 0)
        )

        let line = nsText.substring(with: lineRange)
            .trimmingCharacters(in: .newlines)

        guard let result = MathExpressionEvaluator.evaluate(line) else {
            mathPreviewLabel.isHidden = true
            return
        }

        mathPreviewLabel.stringValue = "= \(result.formatted)"
        mathPreviewLabel.sizeToFit()

        positionMathPreview(forLineRange: lineRange)

        mathPreviewLabel.isHidden = false
    }


    private func positionMathPreview(forLineRange lineRange: NSRange) {

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        var measureRange = lineRange
        let nsText = textView.string as NSString

        if measureRange.length > 0 {
            let lastCharRange = NSRange(
                location: measureRange.location + measureRange.length - 1,
                length: 1
            )

            if nsText.substring(with: lastCharRange) == "\n" {
                measureRange.length -= 1
            }
        }

        guard measureRange.length > 0 else {
            return
        }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: measureRange,
            actualCharacterRange: nil
        )

        let lineRect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: textContainer
        )

        let origin = textView.textContainerOrigin
        let labelSize = mathPreviewLabel.frame.size

        mathPreviewLabel.frame = NSRect(
            x: origin.x + lineRect.maxX + 10,
            y: origin.y + lineRect.minY + (lineRect.height - labelSize.height) / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }


    private func showSavedIndicator() {

        savedLabel.stringValue =
        mode == .scratch ? "Scratch" : "Saved"


        NSAnimationContext.runAnimationGroup {

            context in

            context.duration = 0.15

            savedLabel.animator().alphaValue = 1
        }


        savedLabelHideTimer?.invalidate()


        savedLabelHideTimer =
        Timer.scheduledTimer(
            withTimeInterval: 1.2,
            repeats: false
        ) { [weak self] _ in

            self?.savedLabel.animator().alphaValue = 0
        }


        if PreferencesManager.shared.saveSoundEnabled {
            NSSound(named: "Tink")?.play()
        }

        if PreferencesManager.shared.saveHapticEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .default
            )
        }
    }

    // MARK: - /clear Command

private static let clearCommand = "/clear"

/// If the text now ends with "/clear" (at the start of the text or after
/// whitespace), saves everything before it, closes this panel, and
/// immediately opens a fresh blank capture. Returns true when it fired.
private func handleClearCommandIfPresent() -> Bool {

    guard mode == .permanent else {
        return false
    }

    let text = textView.string

    guard text.hasSuffix(Self.clearCommand) else {
        return false
    }

    let beforeCommand = String(text.dropLast(Self.clearCommand.count))

    // Don't fire on something like "foo/clear".
    if let last = beforeCommand.last, !last.isWhitespace {
        return false
    }

    // Drop the command and any whitespace left dangling before it.
    var cleaned = beforeCommand
    while let last = cleaned.last, last.isWhitespace {
        cleaned.removeLast()
    }

    // Programmatic changes don't re-trigger textDidChange.
    textView.string = cleaned

    flushCurrentText()          // saves the cleaned text
    storage.finishSession()     // cancels the grace window

    animateOut { [weak self] in
        guard let self else { return }
        self.beginNewCapture()  // fresh session, blank text
        self.centerOnActiveScreen()
        self.animateIn()
        self.focusTextView()
    }

    return true
}


    private func showContinuingIndicator() {

        savedLabel.stringValue = "Continuing…"

        savedLabel.alphaValue = 1
    }
}