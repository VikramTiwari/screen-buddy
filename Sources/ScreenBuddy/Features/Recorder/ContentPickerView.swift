import SwiftUI
import ScreenCaptureKit
import CoreGraphics

struct ContentPickerView: View {
    @ObservedObject var recorder: ScreenRecorder
    var onSelect: () -> Void
    var onAreaSelect: () -> Void
    var onCancel: () -> Void
    
    @State private var selectedTab: PickerTab = .screens
    @State private var selectedDisplay: SCDisplay?
    @State private var selectedWindow: SCWindow?
    @State private var thumbnails: [Int: NSImage] = [:] // ID -> Image
    
    enum PickerTab {
        case screens
        case windows
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Tabs
            HStack {
                Text("Choose what to share")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            Picker("", selection: $selectedTab) {
                Text("Screens").tag(PickerTab.screens)
                Text("Windows").tag(PickerTab.windows)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            Divider()
            
            // Content Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    if selectedTab == .screens {
                        ForEach(recorder.availableContent?.displays ?? [], id: \.displayID) { display in
                            ContentItemView(
                                title: "Display \(display.displayID)", // Better names if possible?
                                image: thumbnails[Int(display.displayID)],
                                isSelected: selectedDisplay?.displayID == display.displayID
                            )
                            .onTapGesture {
                                selectedDisplay = display
                                selectedWindow = nil
                            }
                            .task {
                                await generateThumbnail(for: display)
                            }
                        }
                    } else {
                        let excludedApps = ["Dock", "Control Center", "Window Server", "Screenshot", "ScreenBuddy", "Notification Center", "SystemUIServer", "Wallpaper"]
                        let validWindows = recorder.availableContent?.windows.filter { window in
                            // Basic visibility checks
                            guard window.isOnScreen, window.frame.width > 50, window.frame.height > 50 else { return false }
                            
                            // Layer check (0 is usually normal windows)
                            // Note: SCWindow doesn't expose windowLayer directly in all versions, but let's assume standard filtering first.
                            // Actually, SCWindow DOES NOT expose windowLayer publically in a simple way in all SDKs, 
                            // but we can rely on app name and title.
                            
                            // Title check
                            guard let title = window.title, !title.isEmpty else { return false }
                            
                            // App Name check
                            guard let appName = window.owningApplication?.applicationName else { return false }
                            guard !excludedApps.contains(appName) else { return false }
                            
                            return true
                        } ?? []
                        
                        ForEach(validWindows, id: \.windowID) { window in
                            ContentItemView(
                                title: window.owningApplication?.applicationName ?? "Unknown",
                                subtitle: window.title,
                                image: thumbnails[Int(window.windowID)],
                                isSelected: selectedWindow?.windowID == window.windowID
                            )
                            .onTapGesture {
                                selectedWindow = window
                                selectedDisplay = nil
                            }
                            .task {
                                await generateThumbnail(for: window)
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 600, minHeight: 400)
            
            Divider()
            
            // Footer
            HStack {
                Button("Select Area") {
                    onAreaSelect()
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Share") {
                    if let display = selectedDisplay {
                        recorder.selectedDisplay = display
                        recorder.setSelection(rect: nil)
                        onSelect()
                    } else if let window = selectedWindow {
                        recorder.setSelection(window: window)
                        onSelect()
                    }
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selectedDisplay == nil && selectedWindow == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task {
                await recorder.loadAvailableContent()
            }
        }
    }
    
    func generateThumbnail(for display: SCDisplay) async {
        guard thumbnails[Int(display.displayID)] == nil else { return }
        
        // Use CGDisplayCreateImage
        if let cgImage = CGDisplayCreateImage(display.displayID) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            thumbnails[Int(display.displayID)] = nsImage
        }
    }
    
    func generateThumbnail(for window: SCWindow) async {
        guard thumbnails[Int(window.windowID)] == nil else { return }
        
        // Use CGWindowListCreateImage
        // We need to match the window ID.
        // CGWindowListCreateImage(.optionIncludingWindow, windowID, ...)
        
        let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowID),
            [.boundsIgnoreFraming, .bestResolution]
        )
        
        if let cgImage = image {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            thumbnails[Int(window.windowID)] = nsImage
        }
    }
}

struct ContentItemView: View {
    let title: String
    var subtitle: String? = nil
    let image: NSImage?
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
                    .frame(height: 150)
                
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 140)
                        .cornerRadius(4)
                } else {
                    ProgressView()
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .contentShape(Rectangle()) // Make whole area tappable
    }
}
