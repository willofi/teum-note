import Foundation

public enum NoteColor: String, Codable, CaseIterable, Sendable {
    case butter, peach, sage, sky, lavender

    public static func following(_ last: NoteColor?) -> NoteColor {
        guard let last, let index = allCases.firstIndex(of: last) else { return .butter }
        return allCases[(index + 1) % allCases.count]
    }
}

public enum ScreenEdge: String, Codable, Sendable {
    case left, right
}

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var color: NoteColor
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String = "", color: NoteColor = .butter, updatedAt: Date = .now) {
        self.id = id
        self.text = text
        self.color = color
        self.updatedAt = updatedAt
    }

    public var title: String {
        MarkdownDocument.title(in: text)
    }
}

public struct Notebook: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var notes: [Note]
    public var edge: ScreenEdge

    public init(notes: [Note] = [], edge: ScreenEdge = .right) {
        self.notes = notes
        self.edge = edge
    }

    public static var welcome: Notebook {
        Notebook(notes: [
            Note(text: "생각이 머무는 작은 틈\n\n스쳐 가는 생각, 잠깐 기억할 일.\n여기에 가볍게 내려놓으세요.\n\n오른쪽 탭을 누르면 메모가 열리고,\n다시 누르면 가장자리에 쏙 들어갑니다.\n\n작성한 내용은 이 Mac에 자동 저장돼요.", color: .butter),
            Note(text: "오늘의 작은 할 일\n\n☐ 가장 중요한 일 하나\n☐ 잠깐 일어나 스트레칭\n☐ 떠오른 생각 적어두기", color: .sage),
            Note(text: "나중에 꺼내 볼 것들\n\n읽고 싶은 글, 좋아하는 문장,\n잊고 싶지 않은 링크를 모아보세요.", color: .lavender)
        ])
    }
}
