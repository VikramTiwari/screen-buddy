import Foundation
import AVFoundation

class CameraRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var session: AVCaptureSession?
    private var output: AVCaptureMovieFileOutput?
    private var isRecording = false
    
    func startRecording(to url: URL) async throws {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw NSError(domain: "CameraRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera found"])
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        self.session = session
        self.output = output
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            output.startRecording(to: url, recordingDelegate: self)
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
