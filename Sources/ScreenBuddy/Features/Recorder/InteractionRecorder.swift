import Foundation
import AppKit
import CoreGraphics

struct InteractionEvent: Codable {
    let timestamp: TimeInterval
    let type: String
    let x: Double?
    let y: Double?
    let key: String?
}

class InteractionRecorder {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRecording = false
    private var events: [InteractionEvent] = []
    private var startTime: TimeInterval = 0
    private var outputURL: URL?
    private var mouseTimer: Timer?
    
    func startRecording(to url: URL) {
        self.outputURL = url
        self.events = []
        self.startTime = Date().timeIntervalSince1970
        
        // Start mouse position timer
        DispatchQueue.main.async {
            self.mouseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.recordMousePosition()
            }
        }
        
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.rightMouseDown.rawValue) |
                        (1 << CGEventType.keyDown.rawValue)
        
        func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<InteractionRecorder>.fromOpaque(refcon).takeUnretainedValue()
            recorder.handleEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }
        
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(eventMask),
                                          callback: callback,
                                          userInfo: observer) else {
            print("Failed to create event tap")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        self.isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        mouseTimer?.invalidate()
        mouseTimer = nil
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.eventTap = nil
        }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            self.runLoopSource = nil
        }
        
        saveEvents()
        isRecording = false
    }
    
    private func handleEvent(type: CGEventType, event: CGEvent) {
        let timestamp = Date().timeIntervalSince1970 - startTime
        var eventType = "unknown"
        var x: Double?
        var y: Double?
        var key: String?
        
        switch type {
        case .leftMouseDown:
            eventType = "click_left"
            let location = event.location
            x = location.x
            y = location.y
        case .rightMouseDown:
            eventType = "click_right"
            let location = event.location
            x = location.x
            y = location.y
        case .keyDown:
            eventType = "keydown"
            // Simple key logging (not comprehensive)
            if let nsEvent = NSEvent(cgEvent: event) {
                key = nsEvent.charactersIgnoringModifiers
            }
        default:
            break
        }
        
        let interaction = InteractionEvent(timestamp: timestamp, type: eventType, x: x, y: y, key: key)
        events.append(interaction)
    }
    
    private func recordMousePosition() {
        guard let event = CGEvent(source: nil) else { return }
        let location = event.location
        let timestamp = Date().timeIntervalSince1970 - startTime
        
        let interaction = InteractionEvent(timestamp: timestamp, type: "mouse_position", x: location.x, y: location.y, key: nil)
        events.append(interaction)
    }
    
    private func saveEvents() {
        guard let url = outputURL else { return }
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: url)
        } catch {
            print("Failed to save interactions: \(error)")
        }
    }
}
