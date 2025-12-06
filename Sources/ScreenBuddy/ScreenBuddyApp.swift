import SwiftUI
import AppKit

@main
struct ScreenBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var recorder = ScreenRecorder.shared
    var selectionState = SelectionState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Record")
            image?.isTemplate = true // Allows automatic light/dark mode adaptation
            button.image = image
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Observe recording state to update icon
        Task {
            for await isRecording in recorder.$isRecording.values {
                if let button = statusItem.button {
                    let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: isRecording ? "Stop Recording" : "Start Recording")
                    
                    if isRecording {
                        // Red outline for recording
                        let config = NSImage.SymbolConfiguration(paletteColors: [.red])
                        button.image = image?.withSymbolConfiguration(config)
                        button.image?.isTemplate = false // Keep it red
                    } else {
                        // Standard template for idle
                        image?.isTemplate = true
                        button.image = image
                    }
                }
                
                if !isRecording {
                    self.recordingBorderWindow?.close()
                    self.recordingBorderWindow = nil
                }
            }
        }
        

    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Right click always shows menu
            showMenu(sender)
            return
        }
        
        if recorder.isRecording {
            // Stop recording immediately
            Task {
                await recorder.stopRecording()
            }
        } else {
            // Show menu to start recording
            showMenu(sender)
        }
    }
    
    func showMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        
        let startItem = NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil) // This pops up the menu
        statusItem.menu = nil // Clear it so the next click goes to our action handler again
    }
    
    var pickerWindow: NSWindow?
    var selectionWindows: [NSWindow] = []
    var recordingBorderWindow: NSWindow?
    
    @objc func startRecording() {
        // Show Content Picker
        let pickerView = ContentPickerView(
            recorder: recorder,
            onSelect: { [weak self] in
                self?.startRecordingActual()
            },
            onAreaSelect: { [weak self] in
                self?.showAreaSelectionOverlay()
            },
            onCancel: { [weak self] in
                self?.closePicker()
            }
        )
        
        let hostingController = NSHostingController(rootView: pickerView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "Choose what to share"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Ensure it's visible
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.pickerWindow = window
    }
    
    func showAreaSelectionOverlay() {
        closePicker()
        selectionState.reset()
        selectionState.mode = .area
        
        // Create a window for EACH screen
        for screen in NSScreen.screens {
            let overlayView = SelectionOverlayView(
                recorder: recorder,
                state: selectionState,
                screen: screen,
                onStartRecording: { [weak self] in
                    self?.startRecordingActual()
                },
                onCancel: { [weak self] in
                    self?.closeSelectionOverlay()
                }
            )
            
            let hostingController = NSHostingController(rootView: overlayView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.styleMask = [.borderless, .fullSizeContentView]
            window.level = NSWindow.Level.screenSaver
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            
            // Position on the specific screen
            window.setFrame(screen.frame, display: true)
            
            window.makeKeyAndOrderFront(nil)
            selectionWindows.append(window)
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closeSelectionOverlay() {
        for window in selectionWindows {
            window.close()
        }
        selectionWindows.removeAll()
    }
    
    func closePicker() {
        pickerWindow?.close()
        pickerWindow = nil
    }
    
    func startRecordingActual() {
        closePicker()
        closeSelectionOverlay()
        
        // Show border if area selection or window selection
        if let rect = recorder.selectionRect {
            showRecordingBorder(rect: rect)
        } else if recorder.selectedWindow != nil {
            // Convert window frame to global coordinates if needed, or just use the frame
            // SCWindow frame is global (top-left origin)
            // NSWindow needs bottom-left origin
            // Let's just focus on Area selection for now as requested, or try to support both.
            // The user asked "when we are recording an area", so let's prioritize that.
            // But window recording also benefits from it.
            
            // For now, let's stick to explicit area selection as it's easier to map.
            // Window tracking requires moving the border if the window moves, which is complex.
        }
        
        Task {
            await recorder.startRecording()
        }
    }
    
    func showRecordingBorder(rect: CGRect) {
        let borderView = RecordingBorderView()
        let hostingController = NSHostingController(rootView: borderView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.borderless]
        window.level = .floating // Above normal windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true // Click-through
        
        // Convert SC/Global rect (top-left) to Cocoa rect (bottom-left)
        if let screenHeight = NSScreen.screens.first?.frame.height {
            // Expand the border slightly so it's outside the recorded area
            let borderWidth: CGFloat = 4.0
            let expandedRect = rect.insetBy(dx: -borderWidth, dy: -borderWidth)
            
            let cocoaY = screenHeight - expandedRect.origin.y - expandedRect.height
            let cocoaRect = CGRect(x: expandedRect.origin.x, y: cocoaY, width: expandedRect.width, height: expandedRect.height)
            window.setFrame(cocoaRect, display: true)
        }
        
        window.makeKeyAndOrderFront(nil)
        self.recordingBorderWindow = window
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
