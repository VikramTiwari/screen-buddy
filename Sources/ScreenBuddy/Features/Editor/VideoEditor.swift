import Foundation
import AVFoundation
import SwiftUI

@MainActor
class VideoEditor: ObservableObject {
    @Published var composition: AVMutableComposition?
    @Published var playerItem: AVPlayerItem?
    @Published var error: String?
    
    func loadVideo(from url: URL) async {
        let asset = AVURLAsset(url: url)
        // Create composition on the main actor
        let composition = AVMutableComposition()
        
        do {
            // Load tracks asynchronously
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                self.error = "No video track found"
                return
            }
            
            let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let duration = try await asset.load(.duration)
            
            try compositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
            
            self.composition = composition
            self.playerItem = AVPlayerItem(asset: composition)
        } catch {
            self.error = "Failed to load video: \(error.localizedDescription)"
        }
    }
    
    // Helper to call from synchronous context
    func loadVideoAsync(from url: URL) {
        Task {
            await loadVideo(from: url)
        }
    }
}
