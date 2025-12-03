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
            let config = NSImage.SymbolConfiguration(paletteColors: [.white])
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Record")?.withSymbolConfiguration(config)
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Observe recording state to update icon
        Task {
            for await isRecording in recorder.$isRecording.values {
                if let button = statusItem.button {
                    let imageName = isRecording ? "record.circle.fill" : "record.circle"
                    let color: NSColor = isRecording ? .red : .white
                    let config = NSImage.SymbolConfiguration(paletteColors: [color])
                    button.image = NSImage(systemSymbolName: imageName, accessibilityDescription: isRecording ? "Stop Recording" : "Start Recording")?.withSymbolConfiguration(config)
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
    
    var selectionWindows: [NSWindow] = []
    
    @objc func startRecording() {
        // Reset state
        selectionState.reset()
        
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
            window.level = .screenSaver
            window.backgroundColor = .clear
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
    
    func startRecordingActual() {
        closeSelectionOverlay()
        Task {
            // Do NOT reload content here, as it resets the selection!
            // await recorder.loadAvailableContent() 
            await recorder.startRecording()
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
