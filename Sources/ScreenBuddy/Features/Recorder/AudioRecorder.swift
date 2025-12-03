import Foundation
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var isRecording = false
    
    func startRecording(to url: URL) async throws {
        print("AudioRecorder: Starting recording to \(url.path)")
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
            recorder?.delegate = self
            recorder?.prepareToRecord()
            
            if recorder?.record() == true {
                print("AudioRecorder: Successfully started recording")
                isRecording = true
            } else {
                print("AudioRecorder: Failed to start recording (record() returned false)")
                throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
            }
        } catch {
            print("AudioRecorder: Error setting up recording: \(error)")
            throw error
        }
    }
    
    func stopRecording() async {
        guard isRecording else { 
            print("AudioRecorder: Stop called but not recording")
            return 
        }
        print("AudioRecorder: Stopping recording...")
        recorder?.stop()
        isRecording = false
        
        if let url = recorder?.url {
            do {
                let resources = try url.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resources.fileSize {
                    print("AudioRecorder: Recording finished. File size: \(fileSize) bytes")
                } else {
                    print("AudioRecorder: Recording finished but file size is unknown")
                }
            } catch {
                print("AudioRecorder: Failed to get file size: \(error)")
            }
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("AudioRecorder: audioRecorderDidFinishRecording success=\(flag)")
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("AudioRecorder: Encode error occurred: \(error)")
        } else {
            print("AudioRecorder: Encode error occurred (unknown error)")
        }
    }
}
