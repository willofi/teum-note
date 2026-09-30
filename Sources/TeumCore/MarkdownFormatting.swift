import Foundation

/// A plain-text edit expressed in UTF-16 ranges for NSTextView.
public enum MarkdownFormatting {
    public enum Style: String, Sendable {
        case bold, italic, strikethrough, code, link, bulletList, numberedList
    }

    public struct Edit: Equatable, Sendable {
        public let range: NSRange
        public let replacement: String
        public let selection: NSRange
    }

    public static func edit(_ style: Style, in source: String, selection: NSRange) -> Edit? {
        let text = source as NSString
        guard selection.location != NSNotFound, selection.location >= 0,
              selection.length >= 0, NSMaxRange(selection) <= text.length else { return nil }
        switch style {
        case .bold: return wrap("**", in: text, selection: selection)
        case .italic: return wrap("*", in: text, selection: selection)
        case .strikethrough: return wrap("~~", in: text, selection: selection)
        case .code: return wrap("`", in: text, selection: selection)
        case .link:
            let label = selection.length == 0 ? "링크 텍스트" : text.substring(with: selection)
            let replacement = "[\(label)](https://)"
            return Edit(range: selection, replacement: replacement,
                        selection: NSRange(location: selection.location + 1, length: (label as NSString).length))
        case .bulletList: return list(in: text, selection: selection, numbered: false)
        case .numberedList: return list(in: text, selection: selection, numbered: true)
        }
    }

    private static func wrap(_ marker: String, in text: NSString, selection: NSRange) -> Edit {
        let width = (marker as NSString).length
        let selected = text.substring(with: selection)
        if selection.length >= width * 2, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = (selected as NSString).substring(with: NSRange(location: width, length: selection.length - width * 2))
            return Edit(range: selection, replacement: inner,
                        selection: NSRange(location: selection.location, length: selection.length - width * 2))
        }
        if selection.location >= width, NSMaxRange(selection) + width <= text.length,
           text.substring(with: NSRange(location: selection.location - width, length: width)) == marker,
           text.substring(with: NSRange(location: NSMaxRange(selection), length: width)) == marker {
            return Edit(range: NSRange(location: selection.location - width, length: selection.length + width * 2),
                        replacement: selected,
                        selection: NSRange(location: selection.location - width, length: selection.length))
        }
        return Edit(range: selection, replacement: marker + selected + marker,
                    selection: NSRange(location: selection.location + width, length: selection.length))
    }

    private static func list(in text: NSString, selection: NSRange, numbered: Bool) -> Edit {
        // A selection ending at the next line's start should not format that next line.
        let last = selection.length == 0 ? selection.location : NSMaxRange(selection) - 1
        let range = text.lineRange(for: NSRange(location: selection.location, length: max(0, last - selection.location)))
        let original = text.substring(with: range)
        var lines = original.components(separatedBy: "\n")
        let endsInNewline = original.hasSuffix("\n")
        if endsInNewline { lines.removeLast() }
        let pattern = try! NSRegularExpression(pattern: #"^(?:[-+*]|\d+[.)])\s+"#)
        func markerLength(_ line: String) -> Int {
            pattern.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))?.range.length ?? 0
        }
        let nonempty = lines.filter { !$0.isEmpty }
        let alreadyFormatted = !nonempty.isEmpty && nonempty.allSatisfy { line in
            if numbered { return line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) != nil }
            return line.range(of: #"^[-+*]\s+"#, options: .regularExpression) != nil
        }
        var itemNumber = 1
        var firstDelta = 0
        let changed = lines.enumerated().map { index, line -> String in
            guard !line.isEmpty || lines.count == 1 else { return line }
            let oldWidth = markerLength(line)
            let content = (line as NSString).substring(from: oldWidth)
            let prefix: String
            if alreadyFormatted { prefix = "" }
            else if numbered { prefix = "\(itemNumber). "; itemNumber += 1 }
            else { prefix = "- " }
            if index == 0 { firstDelta = (prefix as NSString).length - oldWidth }
            return prefix + content
        }.joined(separator: "\n") + (endsInNewline ? "\n" : "")
        let newLength = (changed as NSString).length
        let newSelection = selection.length == 0
            ? NSRange(location: max(range.location, selection.location + firstDelta), length: 0)
            : NSRange(location: range.location, length: newLength - (endsInNewline ? 1 : 0))
        return Edit(range: range, replacement: changed, selection: newSelection)
    }
}
