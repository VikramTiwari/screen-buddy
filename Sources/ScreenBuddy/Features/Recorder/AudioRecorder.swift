import Foundation
import AVFoundation

class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var isRecording = false
    
    func startRecording(to url: URL) async throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        // Check permissions
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                print("AudioRecorder: Permission denied")
                throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
        } else if status == .denied || status == .restricted {
            print("AudioRecorder: Permission denied or restricted")
            throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            
            if recorder?.record() == true {
                isRecording = true
            } else {
                throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
            }
        } catch {
            throw error
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        recorder?.stop()
        isRecording = false
    }
    

}
