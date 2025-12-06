import Foundation
import ScreenCaptureKit
import AVFoundation
import VideoToolbox
import SwiftUI
import AppKit

@MainActor
class ScreenRecorder: ObservableObject {
    static let shared = ScreenRecorder()
    
    @Published var isRecording = false
    @Published var availableContent: SCShareableContent?
    @Published var selectedDisplay: SCDisplay?
    @Published var error: String?
    
    private var stream: SCStream?
    private var videoOutput: StreamOutput?
    private var audioOutput: SystemAudioStreamOutput?
    private let recorderQueue = DispatchQueue(label: "com.screenbuddy.recorder")
    
    private let cameraRecorder = CameraRecorder()
    private let audioRecorder = AudioRecorder()
    private let interactionRecorder = InteractionRecorder()
    private var currentRecordingFolder: URL?
    
    func loadAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            selectedDisplay = availableContent?.displays.first
        } catch {
            self.error = "Failed to load content: \(error.localizedDescription)"
        }
    }
    
    @Published var selectionRect: CGRect?
    @Published var selectedWindow: SCWindow?
    
    func setSelection(rect: CGRect?) {
        self.selectionRect = rect
        self.selectedWindow = nil
    }
    
    func setSelection(window: SCWindow?) {
        self.selectedWindow = window
        self.selectionRect = nil
    }
    
    func startRecording() async {
        guard let display = selectedDisplay else {
            self.error = "No display selected"
            return
        }
        
        let filter: SCContentFilter
        let config = SCStreamConfiguration()
        
        if let window = selectedWindow {
            filter = SCContentFilter(desktopIndependentWindow: window)
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
        } else if let rect = selectionRect {
            // Find the display that contains the selection
            let displays = availableContent?.displays ?? []
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let bestDisplay = displays.first { $0.frame.contains(center) } ?? display
            
            // Exclude ScreenBuddy app
            // We need to fetch fresh content or ensure we have the app. 
            // availableContent might be stale or missing the app if it had no windows.
            let currentBundleID = Bundle.main.bundleIdentifier
            var excludedApps: [SCRunningApplication] = []
            do {
                let contentForExclusion = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                excludedApps = contentForExclusion.applications.filter { $0.bundleIdentifier == currentBundleID }
            } catch {
                print("Failed to fetch content for exclusion: \(error)")
            }
            
            filter = SCContentFilter(display: bestDisplay, excludingApplications: excludedApps, exceptingWindows: [])
            
            // Convert global rect to display-relative rect
            // SCStreamConfiguration.sourceRect is relative to the display's origin
            let relativeRect = rect.offsetBy(dx: -bestDisplay.frame.origin.x, dy: -bestDisplay.frame.origin.y)
            config.sourceRect = relativeRect
            
            config.width = Int(rect.width)
            config.height = Int(rect.height)
            
            // Scale up for Retina if possible? For now, just ensure even dimensions.
            // Ideally we'd multiply by bestDisplay.scale (if available) or similar.
            // But let's stick to 1:1 points-to-pixels for stability first.
        } else {
            // Exclude ScreenBuddy app
            let currentBundleID = Bundle.main.bundleIdentifier
            var excludedApps: [SCRunningApplication] = []
            do {
                let contentForExclusion = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                excludedApps = contentForExclusion.applications.filter { $0.bundleIdentifier == currentBundleID }
            } catch {
                print("Failed to fetch content for exclusion: \(error)")
            }
            
            filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            config.width = Int(display.width)
            config.height = Int(display.height)
        }
        
        // Ensure dimensions are even (required by some encoders)
        if config.width % 2 != 0 { config.width += 1 }
        if config.height % 2 != 0 { config.height += 1 }
        
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        
        do {
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let baseFolderURL = desktopURL.appendingPathComponent("screen-buddy")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            let folderName = "Recording \(dateFormatter.string(from: Date()))"
            let sessionFolderURL = baseFolderURL.appendingPathComponent(folderName)
            
            try FileManager.default.createDirectory(at: sessionFolderURL, withIntermediateDirectories: true)
            self.currentRecordingFolder = sessionFolderURL
            
            let screenURL = sessionFolderURL.appendingPathComponent("screen.mov")
            let cameraURL = sessionFolderURL.appendingPathComponent("camera.mov")
            let audioURL = sessionFolderURL.appendingPathComponent("mic.m4a")
            let interactionsURL = sessionFolderURL.appendingPathComponent("interactions.json")
            let systemAudioURL = sessionFolderURL.appendingPathComponent("system.m4a")
            
            // Start Screen Recording
            let output = try StreamOutput(url: screenURL, width: config.width, height: config.height, queue: recorderQueue)
            let audioOutput = try SystemAudioStreamOutput(url: systemAudioURL, queue: recorderQueue)
            
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: recorderQueue)
            try stream.addStreamOutput(audioOutput, type: .audio, sampleHandlerQueue: recorderQueue)
            
            self.stream = stream
            self.videoOutput = output
            self.audioOutput = audioOutput
            
            try await stream.startCapture()
            
            // Check if we were stopped while starting
            guard self.stream != nil else {
                try? await stream.stopCapture()
                await output.finish()
                return
            }
            
            // Start Camera Recording
            try await cameraRecorder.startRecording(to: cameraURL)
            
            // Start Audio Recording
            try await audioRecorder.startRecording(to: audioURL)
            
            // Start Interaction Recording
            interactionRecorder.startRecording(to: interactionsURL)
            
            self.isRecording = true
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            print("ScreenRecorder: Error starting recording: \(error)")
            // Cleanup if possible
            await stopRecording()
        }
    }
    
    func stopRecording() async {
        do {
            try await stream?.stopCapture()
            await videoOutput?.finish()
            await audioOutput?.finish()
            
            await cameraRecorder.stopRecording()
            await audioRecorder.stopRecording()
            interactionRecorder.stopRecording()
            
            self.isRecording = false
            self.stream = nil
            self.videoOutput = nil
            self.audioOutput = nil
            
            // Open the folder
            if let folderURL = self.currentRecordingFolder {
                NSWorkspace.shared.open(folderURL)
                self.currentRecordingFolder = nil
            }
        } catch {
            self.error = "Failed to stop recording: \(error.localizedDescription)"
            print("ScreenRecorder: Error stopping recording: \(error)")
        }
    }
}

class StreamOutput: NSObject, SCStreamOutput {
    private var assetWriter: AVAssetWriter
    private var videoInput: AVAssetWriterInput
    private var isWriting = false
    private var sessionStarted = false
    private var frameCount = 0
    private var lastSampleTime: CMTime?
    private let queue: DispatchQueue
    
    init(url: URL, width: Int, height: Int, queue: DispatchQueue) throws {
        self.queue = queue
        self.assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 2, // High bitrate calculation
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
                AVVideoExpectedSourceFrameRateKey: 60
            ]
        ]
        
        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        self.videoInput.expectsMediaDataInRealTime = true
        
        if self.assetWriter.canAdd(self.videoInput) {
            self.assetWriter.add(self.videoInput)
        } else {
            throw NSError(domain: "ScreenBuddy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add input"])
        }
        
        if self.assetWriter.startWriting() {
            self.isWriting = true
        } else {
             throw self.assetWriter.error ?? NSError(domain: "ScreenBuddy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
        }
    }
    
    func finish() async {
        // Synchronize with the sample handler queue to ensure no more samples are being processed
        let (finalTime, wasStarted) = queue.sync {
            let time = self.lastSampleTime
            let started = self.sessionStarted
            self.isWriting = false // Prevent further writing
            return (time, started)
        }
        
        if let lastTime = finalTime, wasStarted {
            if lastTime.isValid {
                assetWriter.endSession(atSourceTime: lastTime)
            } else {
                print("StreamOutput: WARNING - Last sample time is invalid, skipping endSession")
            }
        }
        
        videoInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        // This runs on 'queue'
        if !isWriting {
            return
        }
        
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            // print("StreamOutput: Dropped frame, no image buffer")
            return
        }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if let lastTime = lastSampleTime, timestamp <= lastTime {
            print("StreamOutput: Dropped frame, non-monotonic timestamp (last: \(lastTime.seconds), curr: \(timestamp.seconds))")
            return
        }
        
        if !sessionStarted {
            sessionStarted = true
            assetWriter.startSession(atSourceTime: timestamp)
        }
        
        if videoInput.isReadyForMoreMediaData {
            if videoInput.append(sampleBuffer) {
                lastSampleTime = timestamp
                frameCount += 1
            } else {
                print("StreamOutput: Failed to append frame. Error: \(String(describing: assetWriter.error))")
            }
        } else {
            print("StreamOutput: Dropped frame, input not ready")
        }
    }
}

class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private var assetWriter: AVAssetWriter
    private var audioInput: AVAssetWriterInput
    private var isWriting = false
    private var sessionStarted = false
    private let queue: DispatchQueue
    
    init(url: URL, queue: DispatchQueue) throws {
        self.queue = queue
        self.assetWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
        
        self.audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        self.audioInput.expectsMediaDataInRealTime = true
        
        if self.assetWriter.canAdd(self.audioInput) {
            self.assetWriter.add(self.audioInput)
        } else {
            throw NSError(domain: "ScreenBuddy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input"])
        }
        
        if self.assetWriter.startWriting() {
            self.isWriting = true
        } else {
            throw self.assetWriter.error ?? NSError(domain: "ScreenBuddy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing audio"])
        }
    }
    
    func finish() async {
        queue.sync {
            self.isWriting = false
        }
        
        audioInput.markAsFinished()
        await assetWriter.finishWriting()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        if !isWriting { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if !sessionStarted {
            sessionStarted = true
            assetWriter.startSession(atSourceTime: timestamp)
        }
        
        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }
}
