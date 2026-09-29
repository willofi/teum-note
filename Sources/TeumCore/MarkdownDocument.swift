import Foundation

/// Lightweight note Markdown. Keeps the source untouched; no HTML or remote assets are loaded.
public enum MarkdownDocument {
    public enum Block: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case listItem(marker: String, text: String, indent: Int, checked: Bool?)
        case quote(String)
        case code(language: String, text: String)
        case divider
    }

    public static func blocks(in source: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var code: [String] = []
        var fence: (character: Character, count: Int, language: String)?

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph.removeAll()
            }
        }

        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let active = fence {
                let run = line.prefix { $0 == active.character }
                if run.count >= active.count && line.dropFirst(run.count).trimmingCharacters(in: .whitespaces).isEmpty {
                    blocks.append(.code(language: active.language, text: code.joined(separator: "\n")))
                    code.removeAll()
                    fence = nil
                } else {
                    code.append(rawLine)
                }
                continue
            }

            if let first = line.first, first == "`" || first == "~" {
                let count = line.prefix { $0 == first }.count
                if count >= 3 {
                    flushParagraph()
                    fence = (first, count, String(line.dropFirst(count)).trimmingCharacters(in: .whitespaces))
                    continue
                }
            }

            if line.isEmpty { flushParagraph(); continue }
            if let parts = captures(#"^(#{1,6})\s+(.+?)(?:\s+#+)?$"#, in: line) {
                flushParagraph()
                blocks.append(.heading(level: parts[0].count, text: parts[1]))
            } else if isDivider(line) {
                flushParagraph()
                blocks.append(.divider)
            } else if let parts = captures(#"^([-+*]|\d{1,9}[.)])\s+(.*)$"#, in: line) {
                flushParagraph()
                let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
                if let task = captures(#"^\[([ xX])\]\s*(.*)$"#, in: parts[1]) {
                    blocks.append(.listItem(marker: parts[0], text: task[1], indent: indent, checked: task[0].lowercased() == "x"))
                } else {
                    blocks.append(.listItem(marker: parts[0], text: parts[1], indent: indent, checked: nil))
                }
            } else if line.hasPrefix(">") {
                flushParagraph()
                let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if case .quote(let previous) = blocks.last {
                    blocks[blocks.count - 1] = .quote(previous + "\n" + text)
                } else {
                    blocks.append(.quote(text))
                }
            } else {
                paragraph.append(rawLine)
            }
        }
        flushParagraph()
        if let fence { blocks.append(.code(language: fence.language, text: code.joined(separator: "\n"))) }
        return blocks
    }

    public static func title(in source: String) -> String {
        guard let first = source.split(whereSeparator: \.isNewline).first else { return "새 메모" }
        let text: String
        switch blocks(in: String(first)).first {
        case .heading(_, let value), .paragraph(let value), .quote(let value), .listItem(_, let value, _, _): text = value
        default: text = String(first)
        }
        let plain = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            .map { String($0.characters) } ?? text
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "새 메모" : trimmed
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
