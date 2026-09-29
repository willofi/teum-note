import SwiftUI
import TeumCore

extension NoteColor {
    var paper: Color {
        switch self {
        case .butter: Color(red: 0.98, green: 0.94, blue: 0.78)
        case .peach: Color(red: 0.98, green: 0.86, blue: 0.79)
        case .sage: Color(red: 0.86, green: 0.92, blue: 0.82)
        case .sky: Color(red: 0.83, green: 0.91, blue: 0.96)
        case .lavender: Color(red: 0.91, green: 0.87, blue: 0.96)
        }
    }

    var name: String {
        switch self {
        case .butter: "버터"
        case .peach: "복숭아"
        case .sage: "세이지"
        case .sky: "하늘"
        case .lavender: "라벤더"
        }
    }
}

private let ink = Color(red: 0.23, green: 0.25, blue: 0.22)

enum RailItem: Hashable {
    case note(UUID)
    case add
}

private struct RailFramesKey: PreferenceKey {
    static let defaultValue: [RailItem: CGRect] = [:]
    static func reduce(value: inout [RailItem: CGRect], nextValue: () -> [RailItem: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct RailFrameReader: View {
    let item: RailItem
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: RailFramesKey.self, value: [item: geometry.frame(in: .named("rail"))])
        }
    }
}

struct EdgeRailView: View {
    @Bindable var store: NotebookStore
    let open: (UUID) -> Void
    let add: () -> Void
    let framesChanged: ([RailItem: CGRect]) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var alignment: HorizontalAlignment { store.notebook.edge == .right ? .trailing : .leading }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView(.vertical) {
                VStack(alignment: alignment, spacing: 6) {
                    ForEach(store.notes) { note in
                        let selected = store.selectedID == note.id
                        let expanded = store.hoveredNoteID == note.id
                        Button { open(note.id) } label: {
                            Text(note.title)
                                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: RailLayout.expandedWidth - 24, alignment: .leading)
                                .padding(.horizontal, 12)
                                .opacity(expanded ? 1 : 0)
                                .frame(width: expanded ? RailLayout.expandedWidth : RailLayout.collapsedWidth, height: 28)
                                .clipped()
                                .foregroundStyle(ink)
                                .background(note.color.paper, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(selected ? 0.28 : 0), lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help(note.title)
                        .accessibilityLabel("메모 열기: \(note.title)")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .frame(width: RailLayout.expandedWidth, height: 28, alignment: store.notebook.edge == .right ? .trailing : .leading)
                        .background(RailFrameReader(item: .note(note.id)))
                        .id(note.id)
                    }
                    Button(action: add) {
                        Image(systemName: store.loadFailed ? "exclamationmark.triangle" : "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ink)
                            .frame(width: 18, height: 22)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(store.loadFailed ? "메모 파일 오류 확인" : "새 메모")
                    .accessibilityLabel(store.loadFailed ? "메모 파일 오류 확인" : "새 메모")
                    .background(RailFrameReader(item: .add))
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: store.notebook.edge == .right ? .trailing : .leading)
            }
            .scrollIndicators(.hidden)
            .frame(width: RailLayout.expandedWidth)
            .coordinateSpace(name: "rail")
            .onPreferenceChange(RailFramesKey.self, perform: framesChanged)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.hoveredNoteID)
            .onChange(of: store.scrollRequest) { _, request in
                guard let request else { return }
                scroll.scrollTo(request.noteID, anchor: .center)
            }
            .environment(\.colorScheme, .light)
        }
    }
}

struct NoteEditorView: View {
    @Bindable var store: NotebookStore
    let close: () -> Void
    let add: () -> Void
    let delete: (UUID) -> Void
    @State private var preview = true

    var body: some View {
        if let note = store.selectedNote {
            VStack(spacing: 0) {
                Group {
                    if preview {
                        MarkdownPreview(source: note.text)
                            .onTapGesture(count: 2) { preview = false }
                    } else {
                        editor(for: note)
                    }
                }
                .padding(.horizontal, 19).padding(.top, 24).padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 6) {
                    ForEach(NoteColor.allCases, id: \.self) { color in
                        Button { store.updateColor(color, id: note.id) } label: {
                            Circle().fill(color.paper)
                                .overlay(Circle().strokeBorder(ink.opacity(note.color == color ? 0.4 : 0.15)))
                                .overlay {
                                    if note.color == color {
                                        Circle().fill(ink.opacity(0.6)).frame(width: 4, height: 4)
                                    }
                                }
                                .frame(width: 14, height: 14)
                        }
                        .accessibilityLabel("\(color.name) 색상")
                        .help(color.name)
                    }
                    Spacer(minLength: 8)
                    Button {
                        preview.toggle()
                    } label: {
                        Image(systemName: preview ? "pencil" : "eye")
                            .frame(width: 28, height: 28)
                            .background(preview ? ink.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                    .help(preview ? "편집으로 돌아가기 · ⌘⇧M" : "마크다운 미리보기 · ⌘⇧M")
                    .accessibilityLabel(preview ? "메모 편집" : "마크다운 미리보기")
                    Menu {
                        Text(store.saveState)
                        Text("\(note.text.count)자")
                        Divider()
                        Button("메모 삭제…", role: .destructive) { delete(note.id) }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 24, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("메모 옵션")
                    .accessibilityLabel("메모 옵션")
                    Button(action: add) {
                        Image(systemName: "plus").frame(width: 28, height: 28)
                    }
                    .help("새 메모")
                    .accessibilityLabel("새 메모")
                    Button(action: close) {
                        Image(systemName: store.notebook.edge == .right ? "arrow.right.to.line" : "arrow.left.to.line")
                            .frame(width: 28, height: 28)
                    }
                    .help("가장자리에 접기 · Esc")
                    .accessibilityLabel("메모 접기")
                }
                .font(.system(size: 12))
                .foregroundStyle(ink.opacity(0.65))
                .padding(.horizontal, 23).padding(.bottom, 16)

                if store.errorMessage != nil {
                    Text(store.saveState)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(.bottom, 12)
                }
            }
            .foregroundStyle(ink)
            .buttonStyle(.plain)
            .background(note.color.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.5)))
            .environment(\.colorScheme, .light)
            .onChange(of: note.id) { _, _ in
                preview = !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .onAppear { preview = !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            VStack(spacing: 14) {
                Text("메모가 없습니다")
                    .font(.system(size: 15, weight: .medium))
                Button("새 메모 만들기", action: add)
                    .font(.system(size: 12))
                Text("⌘N으로 새 메모 · ⌘Z로 되돌리기")
                    .font(.system(size: 11))
                    .foregroundStyle(ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(ink)
            .buttonStyle(.plain)
            .background(NoteColor.butter.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .environment(\.colorScheme, .light)
        }
    }

    private func editor(for note: Note) -> some View {
        ZStack(alignment: .topLeading) {
            if note.text.isEmpty {
                Text("지금 떠오른 생각은?")
                    .font(.system(size: 16)).foregroundStyle(ink.opacity(0.35))
                    .padding(.horizontal, 5).padding(.top, 8)
                    .allowsHitTesting(false)
            }
            MarkdownEditor(text: Binding(
                get: { store.notes.first(where: { $0.id == note.id })?.text ?? "" },
                set: { store.updateText($0, id: note.id) }
            ))
            .id(note.id)
            .accessibilityLabel("메모 내용")
        }
    }
}
