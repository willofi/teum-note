import AppKit
import Testing
@testable import TeumCore

@Test @MainActor func editingAppliesHeadingAndEmphasisWithoutChangingSource() {
    let source = "# 제목 🌱\n\n**굵게** 그리고 ~~취소~~\n`code`"
    let result = MarkdownEditingStyle.render(source)
    let text = source as NSString
    #expect(result.string == source)
    let heading = result.attribute(.font, at: text.range(of: "제목").location, effectiveRange: nil) as? NSFont
    #expect(heading?.pointSize == 25)
    let bold = result.attribute(.font, at: text.range(of: "굵게").location, effectiveRange: nil) as? NSFont
    #expect(bold.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true)
    #expect(result.attribute(.strikethroughStyle, at: text.range(of: "취소").location, effectiveRange: nil) as? Int == NSUnderlineStyle.single.rawValue)
    let code = result.attribute(.font, at: text.range(of: "code").location, effectiveRange: nil) as? NSFont
    #expect(code?.isFixedPitch == true)
}

@Test @MainActor func editingDoesNotInterpretCodeAsHeadingsOrEmphasis() {
    let source = "```\n# literal\n**literal**\n```\n## 실제 제목"
    let result = MarkdownEditingStyle.render(source)
    let text = source as NSString
    let literal = result.attribute(.font, at: text.range(of: "# literal").location, effectiveRange: nil) as? NSFont
    #expect(literal?.pointSize == 13)
    #expect(literal?.isFixedPitch == true)
    let heading = result.attribute(.font, at: text.range(of: "실제 제목").location, effectiveRange: nil) as? NSFont
    #expect(heading?.pointSize == 21)
    #expect(result.string == source)
}
