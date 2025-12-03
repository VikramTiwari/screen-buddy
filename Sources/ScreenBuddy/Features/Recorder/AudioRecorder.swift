import Foundation
import AVFoundation

class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var isRecording = false
    
    func startRecording(to url: URL) async throws {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 320000
        ]
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
            isRecording = true
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
