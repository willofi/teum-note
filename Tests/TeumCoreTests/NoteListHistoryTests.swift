import Foundation
import Testing
@testable import TeumCore

@Test func newNotesFollowBottomColorEvenAfterDeletions() {
    #expect(NoteColor.following(nil) == .butter)
    #expect(NoteColor.following(.peach) == .sage)
    #expect(NoteColor.following(.lavender) == .butter)
    let notes = [Note(color: .sky), Note(color: .sage)]
    #expect(NoteColor.following(notes.last?.color) == .sky)
}

@Test func creatingThenUndoingAndRedoingRestoresSelectionAndCurrentText() {
    let original = Note(text: "original")
    let created = Note(color: .peach)
    var notes = [original, created]
    var selected: UUID? = created.id
    var history = NoteListHistory()
    history.recordInsertion(created, at: 1, previousSelection: original.id)

    notes[1].text = "typed after creation"
    #expect(history.undo(notes: &notes, selectedID: &selected) == .removed(created.id))
    #expect(notes == [original])
    #expect(selected == original.id)
    #expect(history.redo(notes: &notes, selectedID: &selected) == .inserted(created.id))
    #expect(notes[1].text == "typed after creation")
    #expect(selected == created.id)
}

@Test func deletingThenUndoingRestoresOriginalPositionAndContents() {
    let first = Note(text: "first"), middle = Note(text: "saved content", color: .sage), last = Note(text: "last")
    var notes = [first, last]
    var selected: UUID? = nil
    var history = NoteListHistory()
    history.recordRemoval(middle, at: 1, previousSelection: middle.id)

    #expect(history.undo(notes: &notes, selectedID: &selected) == .inserted(middle.id))
    #expect(notes == [first, middle, last])
    #expect(selected == middle.id)
    #expect(history.redo(notes: &notes, selectedID: &selected) == .removed(middle.id))
    #expect(notes == [first, last])
    #expect(selected == nil)
}

@Test func aNewListChangeClearsRedoHistory() {
    let first = Note(), second = Note()
    var notes = [first]
    var selected: UUID? = first.id
    var history = NoteListHistory()
    history.recordInsertion(first, at: 0, previousSelection: nil)
    #expect(history.undo(notes: &notes, selectedID: &selected) == .removed(first.id))
    #expect(history.canRedo)
    notes.append(second)
    history.recordInsertion(second, at: 0, previousSelection: nil)
    #expect(!history.canRedo)
}
