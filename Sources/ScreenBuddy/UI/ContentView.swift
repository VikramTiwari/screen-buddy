import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    @StateObject private var recorder = ScreenRecorder()
    
    @State private var showEditor = false

    var body: some View {
        VStack {
            Image(systemName: "video.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Screen Buddy")
                .font(.title)
                .padding()
            
            if let error = recorder.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
            
            if recorder.isRecording {
                Text("Recording...")
                    .foregroundColor(.red)
                    .font(.headline)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        if recorder.isRecording {
                            await recorder.stopRecording()
                        } else {
                            await recorder.startRecording()
                        }
                    }
                }) {
                    Label(recorder.isRecording ? "Stop Recording" : "Record", systemImage: recorder.isRecording ? "stop.circle" : "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.isRecording ? .red : .blue)
                
                Button(action: {
                    showEditor = true
                }) {
                    Label("Editor", systemImage: "scissors")
                }
                .disabled(recorder.isRecording)
            }
            .sheet(isPresented: $showEditor) {
                EditorView()
                    .frame(minWidth: 600, minHeight: 400)
            }
            
            if let content = recorder.availableContent {
                Picker("Display", selection: $recorder.selectedDisplay) {
                    ForEach(content.displays, id: \.self) { display in
                        Text("Display \(display.displayID) (\(display.width)x\(display.height))").tag(display as SCDisplay?)
                    }
                }
                .pickerStyle(.menu)
                .padding()
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .task {
            await recorder.loadAvailableContent()
        }
    }
}

#Preview {
    ContentView()
}
