import Foundation
import CoreGraphics
import Testing
@testable import TeumCore

@Test func stationaryPointerKeepsOnlyOneTabOpenAtEitherEdge() {
    let first = UUID(), second = UUID()
    let rows = [first: CGRect(x: 0, y: 6, width: RailLayout.expandedWidth, height: 28), second: CGRect(x: 0, y: 40, width: RailLayout.expandedWidth, height: 28)]
    for edge in [ScreenEdge.left, .right] {
        var state = RailHoverState()
        let pointer = CGPoint(x: edge == .right ? 75 : 5, y: 20)
        for _ in 0..<120 {
            state.update(pointer: pointer, rows: rows, edge: edge)
            #expect(state.hoveredNoteID == first)
        }
        state.update(pointer: CGPoint(x: pointer.x, y: 50), rows: rows, edge: edge)
        #expect(state.hoveredNoteID == second)
    }
}

@Test func expandedTitleRetainsHoverButGapsDoNotOpenTabs() {
    let id = UUID()
    let rows = [id: CGRect(x: 0, y: 6, width: RailLayout.expandedWidth, height: 28)]
    var state = RailHoverState()
    state.update(pointer: CGPoint(x: 50, y: 20), rows: rows, edge: .right)
    #expect(state.hoveredNoteID == nil)
    state.update(pointer: CGPoint(x: 75, y: 20), rows: rows, edge: .right)
    state.update(pointer: CGPoint(x: 30, y: 20), rows: rows, edge: .right)
    #expect(state.hoveredNoteID == id)
    state.update(pointer: CGPoint(x: 50, y: 38), rows: rows, edge: .right)
    #expect(state.hoveredNoteID == nil)
    state.update(pointer: CGPoint(x: 75, y: 20), rows: rows, edge: .right)
    state.update(pointer: nil, rows: rows, edge: .right)
    #expect(state.hoveredNoteID == nil)
}

@Test func emptyRailGapsDoNotCaptureOtherAppsClicks() {
    let id = UUID()
    let rows = [id: CGRect(x: 0, y: 6, width: RailLayout.expandedWidth, height: 28)]
    #expect(RailHoverState.isOverCollapsedTab(CGPoint(x: 75, y: 20), rows: rows, edge: .right))
    #expect(!RailHoverState.isOverCollapsedTab(CGPoint(x: 75, y: 38), rows: rows, edge: .right))
    #expect(!RailHoverState.isOverCollapsedTab(CGPoint(x: 30, y: 20), rows: rows, edge: .right))
}
