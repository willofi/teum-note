import Foundation
import CoreGraphics

/// Hit regions are fixed in rail coordinates, independent of animated tab widths.
public struct RailHoverState {
    public private(set) var hoveredNoteID: UUID?
    public init() {}

    public mutating func update(pointer: CGPoint?, rows: [UUID: CGRect], edge: ScreenEdge) {
        guard let pointer else { hoveredNoteID = nil; return }
        if let id = hoveredNoteID, let row = rows[id], row.contains(pointer) { return }
        hoveredNoteID = rows.first { _, row in Self.collapsedTab(row, edge: edge).contains(pointer) }?.key
    }

    public static func isOverCollapsedTab(_ pointer: CGPoint, rows: [UUID: CGRect], edge: ScreenEdge) -> Bool {
        rows.values.contains { collapsedTab($0, edge: edge).contains(pointer) }
    }

    private static func collapsedTab(_ row: CGRect, edge: ScreenEdge) -> CGRect {
        let x = edge == .right ? row.maxX - RailLayout.collapsedWidth : row.minX
        return CGRect(x: x, y: row.minY, width: RailLayout.collapsedWidth, height: row.height)
    }
}
