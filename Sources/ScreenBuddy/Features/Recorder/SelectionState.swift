import SwiftUI
import ScreenCaptureKit

class SelectionState: ObservableObject {
    enum SelectionMode {
        case none
        case screen
        case window
        case area
    }
    
    @Published var mode: SelectionMode = .none
    @Published var selectionRect: CGRect = .zero
    @Published var hoveredWindow: SCWindow?
    @Published var hoveredDisplay: SCDisplay?
    @Published var isDragging = false
    
    // Helper to reset state
    func reset() {
        mode = .none
        selectionRect = .zero
        hoveredWindow = nil
        hoveredDisplay = nil
        isDragging = false
    }
}
