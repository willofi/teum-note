import AppKit

@MainActor public enum MarkdownEditingStyle {
    public static let ink = NSColor(calibratedRed: 0.23, green: 0.25, blue: 0.22, alpha: 1)
    public static var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        return [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: ink, .paragraphStyle: paragraph]
    }

    public static func render(_ source: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source, attributes: baseAttributes)
        let string = source as NSString
        let full = NSRange(location: 0, length: string.length)
        var fence: (Character, Int)?
        for lineMatch in matches(#"(?m)^.*$"#, source, full) {
            let range = lineMatch.range
            let line = string.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if let active = fence {
                codeStyle(result, range)
                let run = line.prefix { $0 == active.0 }
                if run.count >= active.1 && line.dropFirst(run.count).trimmingCharacters(in: .whitespaces).isEmpty { fence = nil }
                continue
            }
            if let first = line.first, first == "`" || first == "~", line.prefix(while: { $0 == first }).count >= 3 {
                fence = (first, line.prefix { $0 == first }.count)
                codeStyle(result, range)
                continue
            }
            if let heading = matches(#"(?m)^[ \t]{0,3}(#{1,6})[ \t]+"#, source, range).first {
                let level = heading.range(at: 1).length
                let size: CGFloat = level == 1 ? 25 : level == 2 ? 21 : level == 3 ? 18 : 16
                result.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .semibold), range: range)
                result.addAttribute(.foregroundColor, value: ink.withAlphaComponent(0.35), range: heading.range)
            }
            if line.hasPrefix(">") { result.addAttribute(.foregroundColor, value: ink.withAlphaComponent(0.65), range: range) }
            let codes = matches(#"(`+)(.+?)\1"#, source, range)
            for (pattern, trait) in [
                (#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#, NSFontTraitMask.boldFontMask),
                (#"(?<!\*)(\*)(?!\*)(?=\S)(.+?)(?<=\S)\1(?!\*)"#, NSFontTraitMask.italicFontMask),
                (#"(?<!\w)(_)(?!_)(?=\S)(.+?)(?<=\S)\1(?!\w)"#, NSFontTraitMask.italicFontMask)
            ] {
                for match in matches(pattern, source, range) where !codes.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) {
                    let current = result.attribute(.font, at: match.range.location, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: 15)
                    result.addAttribute(.font, value: NSFontManager.shared.convert(current, toHaveTrait: trait), range: match.range)
                    dimDelimiters(result, match)
                }
            }
            for match in matches(#"(~~)(.+?)\1"#, source, range) where !codes.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) {
                result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 2))
                dimDelimiters(result, match)
            }
            for match in codes {
                codeStyle(result, match.range)
                dimDelimiters(result, match)
            }
        }
        return result
    }

    private static func codeStyle(_ result: NSMutableAttributedString, _ range: NSRange) {
        result.addAttributes([.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .backgroundColor: ink.withAlphaComponent(0.055)], range: range)
    }

    private static func dimDelimiters(_ result: NSMutableAttributedString, _ match: NSTextCheckingResult) {
        let opening = match.range(at: 1)
        result.addAttribute(.foregroundColor, value: ink.withAlphaComponent(0.35), range: opening)
        result.addAttribute(.foregroundColor, value: ink.withAlphaComponent(0.35), range: NSRange(location: NSMaxRange(match.range) - opening.length, length: opening.length))
    }

    private static func matches(_ pattern: String, _ source: String, _ range: NSRange) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern))?.matches(in: source, options: [.withTransparentBounds, .withoutAnchoringBounds], range: range) ?? []
    }
}
