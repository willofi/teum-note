import Testing
@testable import TeumCore

@Test func markdownSupportsCommonNoteBlocks() {
    let source = "# 오늘\n\n**굵게** 그리고 [링크](https://example.com)\n\n- 하나\n  - 둘\n3. 셋\n- [ ] 아직\n- [X] 완료\n\n> 기억할 말\n> 다음 줄\n\n---"
    #expect(MarkdownDocument.blocks(in: source) == [
        .heading(level: 1, text: "오늘"),
        .paragraph("**굵게** 그리고 [링크](https://example.com)"),
        .listItem(marker: "-", text: "하나", indent: 0, checked: nil),
        .listItem(marker: "-", text: "둘", indent: 2, checked: nil),
        .listItem(marker: "3.", text: "셋", indent: 0, checked: nil),
        .listItem(marker: "-", text: "아직", indent: 0, checked: false),
        .listItem(marker: "-", text: "완료", indent: 0, checked: true),
        .quote("기억할 말\n다음 줄"), .divider
    ])
}

@Test func fencedCodePreservesWhitespaceAndMarkdownLiterals() {
    #expect(MarkdownDocument.blocks(in: "````swift\n  # literal\n\n```\n- list\n````\n끝") == [
        .code(language: "swift", text: "  # literal\n\n```\n- list"), .paragraph("끝")
    ])
    #expect(MarkdownDocument.blocks(in: "~~~\r\none\r\ntwo\r\n~~~") == [.code(language: "", text: "one\ntwo")])
    #expect(MarkdownDocument.blocks(in: "```\nunclosed") == [.code(language: "", text: "unclosed")])
}

@Test func plainNotesRemainReadableAndTitlesHideMarkdown() {
    #expect(MarkdownDocument.blocks(in: "첫 줄\n두 번째 🌱\n\n다음 문단") == [.paragraph("첫 줄\n두 번째 🌱"), .paragraph("다음 문단")])
    #expect(Note(text: "## **오늘 할 일**\n내용").title == "오늘 할 일")
    #expect(Note(text: "- [ ] [읽을 글](https://example.com)").title == "읽을 글")
    #expect(Note(text: "\n").title == "새 메모")
    #expect(Note(text: "#해시태그").title == "#해시태그")
}
