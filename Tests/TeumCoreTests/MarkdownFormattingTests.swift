import Foundation
import Testing
@testable import TeumCore

private func result(_ style: MarkdownFormatting.Style, _ text: String, _ selection: NSRange) -> (String, NSRange) {
    let edit = MarkdownFormatting.edit(style, in: text, selection: selection)!
    return ((text as NSString).replacingCharacters(in: edit.range, with: edit.replacement), edit.selection)
}

@Test func inlineFormattingWrapsAndUnwrapsSelectedText() {
    let (bold, selected) = result(.bold, "오늘 메모", NSRange(location: 3, length: 2))
    #expect(bold == "오늘 **메모**")
    #expect(selected == NSRange(location: 5, length: 2))
    #expect(result(.bold, bold, selected).0 == "오늘 메모")
    #expect(result(.bold, "**메모**", NSRange(location: 0, length: 6)).0 == "메모")
    #expect(result(.strikethrough, "취소", NSRange(location: 0, length: 2)).0 == "~~취소~~")
    #expect(result(.italic, "기울임", NSRange(location: 0, length: 3)).0 == "*기울임*")
    #expect(result(.code, "code", NSRange(location: 0, length: 4)).0 == "`code`")
}

@Test func emptySelectionPlacesCursorInsideFormattingAndKeepsUTF16Offsets() {
    let (bold, caret) = result(.bold, "🌱끝", NSRange(location: 2, length: 0))
    #expect(bold == "🌱****끝")
    #expect(caret == NSRange(location: 4, length: 0))
    let (linked, label) = result(.link, "🌱", NSRange(location: 0, length: 2))
    #expect(linked == "[🌱](https://)")
    #expect(label == NSRange(location: 1, length: 2))
}

@Test func listShortcutsFormatOnlySelectedLinesAndToggleOff() {
    let (numbered, range) = result(.numberedList, "하나\n둘\n셋", NSRange(location: 0, length: 5))
    #expect(numbered == "1. 하나\n2. 둘\n셋")
    #expect(range == NSRange(location: 0, length: 10))
    #expect(result(.numberedList, numbered, range).0 == "하나\n둘\n셋")
    #expect(result(.bulletList, "1. 하나\n2. 둘", NSRange(location: 0, length: 10)).0 == "- 하나\n- 둘")
    #expect(result(.bulletList, "빈 줄", NSRange(location: 1, length: 0)).0 == "- 빈 줄")
}
