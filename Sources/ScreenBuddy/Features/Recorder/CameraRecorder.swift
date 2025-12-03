import Foundation
import AVFoundation

class CameraRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var session: AVCaptureSession?
    private var output: AVCaptureMovieFileOutput?
    private var isRecording = false
    
    func startRecording(to url: URL) async throws {
        let session = AVCaptureSession()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("CameraRecorder: No camera found")
            return // Don't crash if no camera
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            print("CameraRecorder: Could not add input")
            return
        }
        
        // Set preset AFTER adding input to ensure compatibility
        if session.canSetSessionPreset(.hd4K3840x2160) {
            session.sessionPreset = .hd4K3840x2160
        } else {
            session.sessionPreset = .high
        }
        
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            print("CameraRecorder: Could not add output")
            return
        }
        
        self.session = session
        self.output = output
        
        // Start running session first
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            
            // Wait a bit for connections to be active
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if output.connections.first?.isActive == true {
                    output.startRecording(to: url, recordingDelegate: self)
                } else {
                    print("CameraRecorder: Output connection not active")
                }
            }
        }
        
        self.isRecording = true
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        output?.stopRecording()
        session?.stopRunning()
        isRecording = false
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Camera recording finished with error: \(error)")
        } else {
            print("Camera recording finished successfully to \(outputFileURL)")
        }
    }
}
