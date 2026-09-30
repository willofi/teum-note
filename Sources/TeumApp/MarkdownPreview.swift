import SwiftUI
import TeumCore

struct MarkdownPreview: View {
    let source: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("아직 적어둔 내용이 없어요.").foregroundStyle(.secondary)
                }
                ForEach(Array(MarkdownDocument.blocks(in: source).enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .font(.system(size: 15))
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 5)
        }
        .accessibilityLabel("마크다운 미리보기")
        .tint(Color(red: 0.22, green: 0.39, blue: 0.36))
    }

    @ViewBuilder private func blockView(_ block: MarkdownDocument.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(size: level == 1 ? 25 : level == 2 ? 21 : level == 3 ? 18 : 16, weight: .semibold))
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(inline(text)).frame(maxWidth: .infinity, alignment: .leading)
        case .listItem(let marker, let text, let indent, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let checked {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(checked ? "완료" : "미완료")
                } else {
                    Text(marker.first?.isNumber == true ? marker : "•")
                        .foregroundStyle(.secondary)
                }
                Text(inline(text)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, CGFloat(min(indent, 12)) * 6)
        case .quote(let text):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.2)).frame(width: 3)
                Text(inline(text)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let language, let text):
            VStack(alignment: .leading, spacing: 8) {
                if !language.isEmpty {
                    Text(language).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    Text(verbatim: text)
                        .font(.system(size: 12, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        case .divider:
            Rectangle().fill(.primary.opacity(0.15)).frame(height: 1).padding(.vertical, 5)
        }
    }

    private func inline(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source)
    }
}
