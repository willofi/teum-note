import Foundation
import CoreGraphics
import Testing
@testable import TeumCore

@Test func roundTripPreservesKoreanEmojiIdentityAndEdge() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = NotebookRepository(fileURL: directory.appendingPathComponent("nested/notes.json"))
    #expect(try repository.load() == nil)
    let notebook = Notebook(notes: [Note(text: "오늘의 생각 🌱\n한글 메모\nhttps://example.com", color: .sage)], edge: .left)
    try repository.save(notebook)
    #expect(try repository.load() == notebook)
    try repository.save(Notebook())
    #expect(try repository.load()?.notes.isEmpty == true)
}

@Test func corruptFileIsNotChangedByFailedRead() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("notes.json")
    let original = Data("broken but recoverable user text".utf8)
    try original.write(to: url)
    #expect(throws: (any Error).self) { try NotebookRepository(fileURL: url).load() }
    #expect(try Data(contentsOf: url) == original)
}

@Test func futureSchemaAndDuplicateIDsAreRejected() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = NotebookRepository(fileURL: directory.appendingPathComponent("notes.json"))
    var future = Notebook()
    future.schemaVersion = 99
    try repository.save(future)
    #expect(throws: NotebookRepository.RepositoryError.self) { try repository.load() }
    let note = Note(text: "duplicate")
    try repository.save(Notebook(notes: [note, note]))
    #expect(throws: NotebookRepository.RepositoryError.self) { try repository.load() }
}

@Test func panelsStayOnOffsetDisplaysAtBothEdges() {
    let screen = CGRect(x: -1920, y: 100, width: 1920, height: 1050)
    for edge in [ScreenEdge.left, .right] {
        for anchor in [CGFloat(-500), 500, 3000] {
            let frame = PanelPlacement.editorFrame(visibleFrame: screen, edge: edge, railWidth: RailLayout.expandedWidth, anchorY: anchor)
            #expect(screen.contains(frame))
            #expect(frame.width == 370)
            #expect(frame.height == 470)
            if edge == .left { #expect(frame.minX == screen.minX + 90) }
            else { #expect(frame.maxX == screen.maxX - 90) }
        }
    }
}

@Test func panelFitsCompactDisplay() {
    let screen = CGRect(x: 0, y: 0, width: 350, height: 400)
    #expect(screen.contains(PanelPlacement.editorFrame(visibleFrame: screen, edge: .right, railWidth: RailLayout.expandedWidth, anchorY: 0)))
}

@Test func editorFollowsSelectedTabOnEitherEdge() {
    let screen = CGRect(x: 0, y: 24, width: 1512, height: 900)
    for edge in [ScreenEdge.left, .right] {
        let firstTab = PanelPlacement.editorFrame(visibleFrame: screen, edge: edge, railWidth: RailLayout.expandedWidth, anchorY: 350)
        let nextTab = PanelPlacement.editorFrame(visibleFrame: screen, edge: edge, railWidth: RailLayout.expandedWidth, anchorY: 616)
        #expect(firstTab.midY == 350)
        #expect(nextTab.midY == 616)
        #expect(nextTab.minY > firstTab.minY)
        #expect(firstTab.minX == nextTab.minX)
    }
}

@Test func keyboardNavigationClampsSelectedTabAfterScreenResize() {
    let smaller = CGRect(x: 0, y: 24, width: 1100, height: 620)
    let frame = PanelPlacement.editorFrame(visibleFrame: smaller, edge: .right, railWidth: RailLayout.expandedWidth, anchorY: 800)
    #expect(smaller.contains(frame))
    #expect(frame.maxY == smaller.maxY - 16)
    #expect(frame.maxX == smaller.maxX - 90)
}
