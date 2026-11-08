import AppKit
import SwiftUI

extension View {
    /// Shows `inspector` as a pane on the trailing side of this view, with a handle at its leading edge that changes
    /// its width (`InspectorWidth.min` to `InspectorWidth.max`). This view keeps `minContentWidth`.
    ///
    /// Use it instead of `.inspector` in the detail column of a `NavigationSplitView`. On macOS 27 the split view that
    /// `.inspector` adds there loops its layout until AppKit stops the app when the sidebar comes back in a narrow window.
    func resizableInspector<Inspector: View>(
        isPresented: Bool,
        minContentWidth: CGFloat,
        @ViewBuilder inspector: () -> Inspector
    ) -> some View {
        modifier(ResizableInspector(isPresented: isPresented, minContentWidth: minContentWidth, inspector: inspector()))
    }
}

/// The limits of the inspector width, in points.
private enum InspectorWidth {
    static let min: CGFloat = 320
    static let ideal: CGFloat = 420
    static let max: CGFloat = 720
}

/// The content, then the handle and the inspector when `isPresented` is true. The width is not saved:
/// each start uses `InspectorWidth.ideal`.
private struct ResizableInspector<Inspector: View>: ViewModifier {
    /// The coordinate space of the content and the inspector together. The handle reads the pointer location in it.
    static var coordinateSpace: String { "resizableInspector" }

    let isPresented: Bool
    let minContentWidth: CGFloat
    let inspector: Inspector
    @State private var inspectorWidth = InspectorWidth.ideal
    /// The width of the content and the inspector together. It limits the handle.
    @State private var totalWidth: CGFloat = 0

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
            if isPresented {
                InspectorResizeHandle(
                    width: $inspectorWidth,
                    totalWidth: totalWidth,
                    minContentWidth: minContentWidth,
                    coordinateSpace: Self.coordinateSpace
                )
                inspector
                    .frame(width: inspectorWidth)
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { totalWidth = $0 }
    }
}

/// The line at the leading edge of the inspector. A drag puts the line under the pointer, with the inspector width
/// between `InspectorWidth.min` and `InspectorWidth.max`. The content keeps `minContentWidth`.
///
/// The line is 1 pt. The hit area is 8 pt wide and ends at the right edge of the line, so it is over the content:
/// the scroll view of the inspector gets the clicks on the right of the line.
private struct InspectorResizeHandle: View {
    @Binding var width: CGFloat
    /// The width of the content and the inspector together.
    let totalWidth: CGFloat
    let minContentWidth: CGFloat
    let coordinateSpace: String

    var body: some View {
        Divider()
            .overlay(alignment: .trailing) {
                Color.clear
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .onHover { isInside in
                        if isInside {
                            Self.resizeCursor.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        // The width comes from the pointer location, not from a start width:
                        // a start width kept in state can stay from an earlier drag.
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))
                            .onChanged { drag in
                                width = clamped(totalWidth - drag.location.x - 1)
                            }
                    )
                    .accessibilityRepresentation {
                        Slider(
                            value: Binding(get: { width }, set: { width = clamped($0) }),
                            in: InspectorWidth.min...upperLimit,
                            step: 20
                        ) {
                            Text("Inspector width")
                        }
                    }
                    .accessibilityValue("\(Int(width)) points")
            }
            .zIndex(1)
    }

    /// The widest inspector that leaves the content its minimum width, but not more than `InspectorWidth.max`.
    private var upperLimit: CGFloat {
        let widthLeftByContent = totalWidth - minContentWidth - 1
        return Swift.max(InspectorWidth.min, Swift.min(InspectorWidth.max, widthLeftByContent))
    }

    private func clamped(_ proposedWidth: CGFloat) -> CGFloat {
        Swift.min(Swift.max(proposedWidth, InspectorWidth.min), upperLimit)
    }

    /// The column-resize cursor (macOS 15 and later), else the left-right resize cursor.
    private static var resizeCursor: NSCursor {
        if #available(macOS 15, *) {
            return .columnResize
        }
        return .resizeLeftRight
    }
}
