import Foundation
import ScreenCaptureKit
import AVFoundation
import SwiftUI

@MainActor
class ScreenRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var availableContent: SCShareableContent?
    @Published var selectedDisplay: SCDisplay?
    @Published var error: String?
    
    private var stream: SCStream?
    private var videoOutput: StreamOutput?
    
    private let cameraRecorder = CameraRecorder()
    private let audioRecorder = AudioRecorder()
    private let interactionRecorder = InteractionRecorder()
    
    func loadAvailableContent() async {
        do {
            availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            selectedDisplay = availableContent?.displays.first
        } catch {
            self.error = "Failed to load content: \(error.localizedDescription)"
        }
    }
    
    func startRecording() async {
        guard let display = selectedDisplay else {
            self.error = "No display selected"
            return
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        
        do {
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let baseFolderURL = desktopURL.appendingPathComponent("screen-buddy")
            let sessionFolderURL = baseFolderURL.appendingPathComponent("session-\(Date().timeIntervalSince1970)")
            
            try FileManager.default.createDirectory(at: sessionFolderURL, withIntermediateDirectories: true)
            
            let screenURL = sessionFolderURL.appendingPathComponent("screen.mov")
            let cameraURL = sessionFolderURL.appendingPathComponent("camera.mov")
            let audioURL = sessionFolderURL.appendingPathComponent("mic.m4a")
            let interactionsURL = sessionFolderURL.appendingPathComponent("interactions.json")
            
            // Start Screen Recording
            let output = try StreamOutput(url: screenURL, width: config.width, height: config.height)
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try await stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.screenbuddy.recorder"))
            try await stream.startCapture()
            
            self.stream = stream
            self.videoOutput = output
            
            // Start Camera Recording
            try await cameraRecorder.startRecording(to: cameraURL)
            
            // Start Audio Recording
            try await audioRecorder.startRecording(to: audioURL)
            
            // Start Interaction Recording
            interactionRecorder.startRecording(to: interactionsURL)
            
            self.isRecording = true
            print("Recording started to \(sessionFolderURL.path)")
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            // Cleanup if possible
            await stopRecording()
        }
    }
    
    func stopRecording() async {
        do {
            try await stream?.stopCapture()
            await videoOutput?.finish()
            
            await cameraRecorder.stopRecording()
            await audioRecorder.stopRecording()
            interactionRecorder.stopRecording()
            
            self.isRecording = false
            self.stream = nil
            self.videoOutput = nil
            print("Recording stopped")
        } catch {
            self.error = "Failed to stop recording: \(error.localizedDescription)"
        }
    }
}

class StreamOutput: NSObject, SCStreamOutput {
    private var assetWriter: AVAssetWriter
    private var videoInput: AVAssetWriterInput
    private var isWriting = false
    private var sessionStarted = false
    
    init(url: URL, width: Int, height: Int) throws {
        self.assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
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
        guard isWriting else { return }
        isWriting = false
        videoInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, isWriting else { return }
        
        if !sessionStarted {
            sessionStarted = true
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }
        
        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }
}
