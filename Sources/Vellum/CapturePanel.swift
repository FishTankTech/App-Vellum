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

    private let storage: NotesStorage
    private let mode: CaptureMode

    private var writeTimer: Timer?
    private var savedLabelHideTimer: Timer?

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

        textView.frame = contentRect
        textView.font = NSFont.systemFont(ofSize: 15)

        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false

        textView.textContainerInset = NSSize(
            width: 14,
            height: 14
        )

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true

        textView.allowsUndo = true
        textView.delegate = self


        scrollView.frame = contentRect
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        scrollView.autoresizingMask = [
            .width,
            .height
        ]


        textView.minSize = NSSize(
            width: 0,
            height: contentRect.height
        )

        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false


        textView.textContainer?.containerSize = NSSize(
            width: contentRect.width,
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


        if isContinuing {
            showContinuingIndicator()
        }
    }


    func flushCurrentText() {

        writeTimer?.invalidate()

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

        updateCountLabel()

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
    }


    private func showContinuingIndicator() {

        savedLabel.stringValue = "Continuing…"

        savedLabel.alphaValue = 1
    }
}