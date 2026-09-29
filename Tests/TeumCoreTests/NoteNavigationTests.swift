import Foundation
import Testing
@testable import TeumCore

@Test func noteNavigationWrapsInBothDirections() {
    let ids = [UUID(), UUID(), UUID()]
    #expect(NoteNavigation.adjacentID(in: ids, current: ids[0], direction: .next) == ids[1])
    #expect(NoteNavigation.adjacentID(in: ids, current: ids[2], direction: .next) == ids[0])
    #expect(NoteNavigation.adjacentID(in: ids, current: ids[0], direction: .previous) == ids[2])
    #expect(NoteNavigation.adjacentID(in: ids, current: ids[2], direction: .previous) == ids[1])
}

@Test func noteNavigationHandlesDeletedEmptyAndSingleNotes() {
    let id = UUID()
    #expect(NoteNavigation.adjacentID(in: [], current: id, direction: .next) == nil)
    #expect(NoteNavigation.adjacentID(in: [id], current: id, direction: .previous) == id)
    #expect(NoteNavigation.adjacentID(in: [id], current: id, direction: .next) == id)
    let ids = [UUID(), UUID()]
    #expect(NoteNavigation.adjacentID(in: ids, current: id, direction: .next) == ids.first)
    #expect(NoteNavigation.adjacentID(in: ids, current: nil, direction: .previous) == ids.last)
    #expect(NoteNavigation.resumeID(in: ids, lastOpened: ids[1]) == ids[1])
    #expect(NoteNavigation.resumeID(in: ids, lastOpened: id) == ids.first)
    #expect(NoteNavigation.resumeID(in: [], lastOpened: id) == nil)
}
