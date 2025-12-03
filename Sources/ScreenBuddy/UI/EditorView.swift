import SwiftUI
import AVKit

struct EditorView: View {
    @StateObject private var editor = VideoEditor()
    @State private var isImporting = false
    
    var body: some View {
        VStack {
            if let playerItem = editor.playerItem {
                VideoPlayer(player: AVPlayer(playerItem: playerItem))
                    .frame(height: 400)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Video Loaded")
                        .font(.title2)
                        .bold()
                    Text("Import a video to start editing")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 400)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            HStack {
                Button("Import Video") {
                    isImporting = true
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie]) { result in
                    switch result {
                    case .success(let url):
                        editor.loadVideoAsync(from: url)
                    case .failure(let error):
                        print("Import failed: \(error.localizedDescription)")
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}
