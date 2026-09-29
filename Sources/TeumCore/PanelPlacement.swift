import Foundation
import CoreGraphics

public enum PanelPlacement {
    /// AppKit coordinates: origin is at the bottom left. Works with negative display origins.
    public static func editorFrame(visibleFrame: CGRect, edge: ScreenEdge, railWidth: CGFloat, anchorY: CGFloat) -> CGRect {
        let width = min(370, max(1, visibleFrame.width - railWidth - 20))
        let height = min(470, max(1, visibleFrame.height - 32))
        let x = edge == .right ? visibleFrame.maxX - railWidth - width - 10 : visibleFrame.minX + railWidth + 10
        let y = min(max(anchorY - height / 2, visibleFrame.minY + 16), visibleFrame.maxY - height - 16)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
