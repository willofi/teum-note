import Foundation

/// Undo and redo for changes to the note list. Text editing keeps its native undo manager.
public struct NoteListHistory {
    public enum Outcome: Equatable {
        case inserted(UUID)
        case removed(UUID)
    }

    private enum Kind { case insert, remove }

    private struct Change {
        let kind: Kind
        let note: Note
        let index: Int
        let selectionAfter: UUID?
    }

    private var undoStack: [Change] = []
    private var redoStack: [Change] = []
    private let limit = 100

    public init() {}

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public mutating func recordInsertion(_ note: Note, at index: Int, previousSelection: UUID?) {
        record(Change(kind: .remove, note: note, index: index, selectionAfter: previousSelection))
    }

    public mutating func recordRemoval(_ note: Note, at index: Int, previousSelection: UUID?) {
        record(Change(kind: .insert, note: note, index: index, selectionAfter: previousSelection))
    }

    public mutating func clearRedo() { redoStack.removeAll() }

    public mutating func undo(notes: inout [Note], selectedID: inout UUID?) -> Outcome? {
        guard let change = undoStack.popLast() else { return nil }
        guard let (inverse, outcome) = apply(change, notes: &notes, selectedID: &selectedID) else { return nil }
        redoStack.append(inverse)
        return outcome
    }

    public mutating func redo(notes: inout [Note], selectedID: inout UUID?) -> Outcome? {
        guard let change = redoStack.popLast() else { return nil }
        guard let (inverse, outcome) = apply(change, notes: &notes, selectedID: &selectedID) else { return nil }
        undoStack.append(inverse)
        return outcome
    }

    private mutating func record(_ change: Change) {
        undoStack.append(change)
        if undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func apply(_ change: Change, notes: inout [Note], selectedID: inout UUID?) -> (Change, Outcome)? {
        let previousSelection = selectedID
        switch change.kind {
        case .insert:
            guard !notes.contains(where: { $0.id == change.note.id }) else { return nil }
            let index = min(max(0, change.index), notes.count)
            notes.insert(change.note, at: index)
            selectedID = change.selectionAfter
            return (Change(kind: .remove, note: change.note, index: index, selectionAfter: previousSelection), .inserted(change.note.id))
        case .remove:
            guard let index = notes.firstIndex(where: { $0.id == change.note.id }) else { return nil }
            let note = notes.remove(at: index)
            selectedID = change.selectionAfter
            return (Change(kind: .insert, note: note, index: index, selectionAfter: previousSelection), .removed(note.id))
        }
    }
}
