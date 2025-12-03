
import SwiftUI
import ScreenCaptureKit

struct SelectionOverlayView: View {
    @ObservedObject var recorder: ScreenRecorder
    @ObservedObject var state: SelectionState
    let screen: NSScreen
    
    var onStartRecording: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background & Interaction Layer
            GeometryReader { geometry in
                // Dimmed background
                Color.black.opacity(0.5)
                    .mask(
                        ZStack {
                            Rectangle()
                            
                            // Cutouts based on mode
                            if state.mode == .area, state.selectionRect != .zero {
                                // Convert global selection rect to local window coordinates
                                let localRect = globalToLocal(state.selectionRect)
                                Rectangle()
                                    .frame(width: localRect.width, height: localRect.height)
                                    .position(x: localRect.midX, y: localRect.midY)
                                    .blendMode(.destinationOut)
                            } else if state.mode == .window, let window = state.hoveredWindow {
                                let localRect = globalToLocal(window.frame)
                                Rectangle()
                                    .frame(width: localRect.width, height: localRect.height)
                                    .position(x: localRect.midX, y: localRect.midY)
                                    .blendMode(.destinationOut)
                            } else if state.mode == .screen, let display = state.hoveredDisplay {
                                let localRect = globalToLocal(display.frame)
                                Rectangle()
                                    .frame(width: localRect.width, height: localRect.height)
                                    .position(x: localRect.midX, y: localRect.midY)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                    )
                    // Area Selection Gesture
                    .gesture(
                        state.mode == .area ?
                        DragGesture()
                            .onChanged { value in
                                state.isDragging = true
                                
                                // Convert local gesture coordinates to global coordinates
                                let startGlobal = localToGlobal(value.startLocation)
                                let currentGlobal = localToGlobal(value.location)
                                
                                state.selectionRect = CGRect(x: min(startGlobal.x, currentGlobal.x),
                                                             y: min(startGlobal.y, currentGlobal.y),
                                                             width: abs(currentGlobal.x - startGlobal.x),
                                                             height: abs(currentGlobal.y - startGlobal.y))
                            }
                            .onEnded { _ in
                                state.isDragging = false
                            }
                        : nil
                    )
            }
            // Continuous Hover for Window/Screen
            .onContinuousHover { phase in
                guard !state.isDragging else { return }
                
                switch phase {
                case .active(let localPoint):
                    let globalPoint = localToGlobal(localPoint)
                    
                    if state.mode == .window {
                        if let windows = recorder.availableContent?.windows {
                            let validWindows = windows.filter { $0.isOnScreen && $0.frame.width > 50 && $0.frame.height > 50 }
                            if let hitWindow = validWindows.first(where: { $0.frame.contains(globalPoint) }) {
                                state.hoveredWindow = hitWindow
                            } else {
                                state.hoveredWindow = nil
                            }
                        }
                    } else if state.mode == .screen {
                        if let displays = recorder.availableContent?.displays {
                            if let hitDisplay = displays.first(where: { $0.frame.contains(globalPoint) }) {
                                state.hoveredDisplay = hitDisplay
                            }
                        }
                    }
                case .ended:
                    // Only clear if we are the screen that lost hover? 
                    // Actually, shared state means if we clear it here, it clears for everyone.
                    // But onContinuousHover .ended might fire when moving between screens.
                    // Let's rely on the new screen picking it up.
                    // Or maybe we should clear it? Let's try clearing for now.
                    // state.hoveredWindow = nil
                    // state.hoveredDisplay = nil
                    break
                }
            }
            .onTapGesture {
                if state.mode == .window, let window = state.hoveredWindow {
                    recorder.setSelection(window: window)
                    onStartRecording()
                } else if state.mode == .screen, let display = state.hoveredDisplay {
                    recorder.selectedDisplay = display
                    recorder.setSelection(rect: nil) // Full screen
                    onStartRecording()
                }
            }
            
            // UI Controls - Only show on the screen that has the mouse? 
            // Or show on all screens? Showing on all is easier for now.
            // But we only want one set of controls to be interactive?
            // Let's show on all for visibility.
            
            VStack {
                if state.mode == .none {
                    // Mode Selection
                    HStack(spacing: 30) {
                        Button(action: { state.mode = .screen }) {
                            VStack {
                                Image(systemName: "display")
                                    .font(.system(size: 40))
                                Text("Screen")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.mode = .window }) {
                            VStack {
                                Image(systemName: "macwindow")
                                    .font(.system(size: 40))
                                Text("Window")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { state.mode = .area }) {
                            VStack {
                                Image(systemName: "selection.pin.in.out")
                                    .font(.system(size: 40))
                                Text("Area")
                                    .font(.headline)
                            }
                            .frame(width: 120, height: 120)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(.top, 20)
                    
                } else {
                    // Active Mode Controls
                    Spacer()
                    HStack(spacing: 20) {
                        Button("Back") {
                            state.reset()
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        
                        if state.mode == .area && state.selectionRect != .zero {
                            Button("Record Area") {
                                recorder.setSelection(rect: state.selectionRect)
                                onStartRecording()
                            }
                            .keyboardShortcut(.return, modifiers: [])
                        } else if state.mode == .window, let window = state.hoveredWindow {
                            Text("Selected: \(window.owningApplication?.applicationName ?? "Unknown")")
                                .foregroundColor(.white)
                        } else if state.mode == .screen, let display = state.hoveredDisplay {
                            Text("Selected: Display \(display.displayID)")
                                .foregroundColor(.white)
                        } else {
                            Text(state.mode == .area ? "Drag to select area" : (state.mode == .window ? "Select a window" : "Select a screen"))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
                    .padding(.bottom, 50)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            Task {
                await recorder.loadAvailableContent()
            }
        }
    }
    
    // Coordinate Conversion Helpers
    // SCWindow/SCDisplay use global coordinates (origin at top-left of main screen, Y increases down)
    // NSScreen frame uses global coordinates (origin at bottom-left of main screen, Y increases up)
    // SwiftUI uses local coordinates (origin at top-left of the view/window, Y increases down)
    
    // We need to map:
    // Global (SC) -> Local (SwiftUI) for drawing rectangles
    // Local (SwiftUI) -> Global (SC) for hit testing and selection
    
    func globalToLocal(_ rect: CGRect) -> CGRect {
        // 1. Flip Y from SC (top-left origin) to Cocoa (bottom-left origin)
        // SC Y is distance from top of main screen.
        // Cocoa Y is distance from bottom of main screen.
        // relationship: scY + cocoaY = mainScreenHeight (roughly, but screens can be arranged variously)
        
        // Actually, let's use the screen frame provided by NSScreen.
        // The window is positioned at screen.frame.origin (bottom-left global).
        // The window content is SwiftUI, so (0,0) is top-left of the window.
        
        // Let's find the global top-left of this screen/window.
        // NSScreen frame is (x, y, w, h) where (x,y) is bottom-left in global Cocoa space.
        // Top-left of this screen in global Cocoa space is (x, y + h).
        
        // But SC coordinates are "Quartz" coordinates (top-left origin).
        // We need to convert SC rect to Cocoa rect first?
        // Or just work with relative positions.
        
        // Let's assume SC coordinates match CGWindow coordinates.
        // And we know the window is covering 'screen'.
        
        // We can use NSWindow.convertPoint(fromScreen:) but we are in SwiftUI.
        // Let's do it manually.
        
        // Get main screen height for flipping if needed.
        guard let mainScreenHeight = NSScreen.screens.first?.frame.height else { return rect }
        
        // Convert SC rect (top-left origin) to Cocoa Global rect (bottom-left origin)
        // SC: (x, y, w, h) -> Cocoa Global: (x, mainScreenHeight - y - h, w, h)
        let cocoaGlobalY = mainScreenHeight - rect.origin.y - rect.height
        let cocoaGlobalOrigin = CGPoint(x: rect.origin.x, y: cocoaGlobalY)
        
        // Now convert Cocoa Global to Window Local (bottom-left origin)
        // Window origin is at screen.frame.origin
        let windowLocalOriginX = cocoaGlobalOrigin.x - screen.frame.origin.x
        let windowLocalOriginY = cocoaGlobalOrigin.y - screen.frame.origin.y
        
        // Now convert Window Local (bottom-left) to SwiftUI Local (top-left)
        // SwiftUI (0,0) is top-left of window.
        // Window height is screen.frame.height
        let swiftUIY = screen.frame.height - windowLocalOriginY - rect.height
        
        return CGRect(x: windowLocalOriginX, y: swiftUIY, width: rect.width, height: rect.height)
    }
    
    func localToGlobal(_ point: CGPoint) -> CGPoint {
        // Reverse the above
        // SwiftUI Local (top-left) -> Window Local (bottom-left)
        let windowLocalY = screen.frame.height - point.y
        
        // Window Local -> Cocoa Global
        let cocoaGlobalX = point.x + screen.frame.origin.x
        let cocoaGlobalY = windowLocalY + screen.frame.origin.y
        
        // Cocoa Global -> SC Global (top-left origin)
        guard let mainScreenHeight = NSScreen.screens.first?.frame.height else { return point }
        let scY = mainScreenHeight - cocoaGlobalY
        
        return CGPoint(x: cocoaGlobalX, y: scY)
    }
}
