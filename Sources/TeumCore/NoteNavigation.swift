import Foundation

public enum NoteNavigation {
    public enum Direction { case previous, next }

    public static func adjacentID(in ids: [UUID], current: UUID?, direction: Direction) -> UUID? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return direction == .next ? ids.first : ids.last
        }
        let offset = direction == .next ? 1 : -1
        return ids[(index + offset + ids.count) % ids.count]
    }

    public static func resumeID(in ids: [UUID], lastOpened: UUID?) -> UUID? {
        if let lastOpened, ids.contains(lastOpened) { return lastOpened }
        return ids.first
    }
}
