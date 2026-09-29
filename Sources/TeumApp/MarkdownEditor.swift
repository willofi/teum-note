import AppKit
import SwiftUI
import TeumCore

/// Keeps the Markdown source and native undo/IME intact; only presentation attributes change.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = NSTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainerInset = NSSize(width: 0, height: 6)
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.setAccessibilityLabel("메모 내용")
        editor.delegate = context.coordinator
        editor.string = text
        scroll.documentView = editor
        context.coordinator.style(editor)
        DispatchQueue.main.async { [weak editor] in
            guard let editor else { return }
            editor.window?.makeFirstResponder(editor)
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView, !editor.hasMarkedText(), editor.string != text else { return }
        editor.string = text
        context.coordinator.style(editor)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            if !editor.hasMarkedText() { style(editor) }
        }

        func style(_ editor: NSTextView) {
            guard let storage = editor.textStorage else { return }
            let selection = editor.selectedRanges
            let styled = MarkdownEditingStyle.render(editor.string)
            // Attribute edits do not replace characters or register content changes in the undo stack.
            storage.beginEditing()
            storage.setAttributes(MarkdownEditingStyle.baseAttributes, range: NSRange(location: 0, length: storage.length))
            styled.enumerateAttributes(in: NSRange(location: 0, length: styled.length)) { attributes, range, _ in
                storage.setAttributes(attributes, range: range)
            }
            storage.endEditing()
            editor.selectedRanges = selection
            editor.typingAttributes = MarkdownEditingStyle.baseAttributes
            editor.insertionPointColor = MarkdownEditingStyle.ink
        }
    }
}
