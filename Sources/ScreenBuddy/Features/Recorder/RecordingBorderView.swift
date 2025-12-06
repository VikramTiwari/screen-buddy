import SwiftUI

struct RecordingBorderView: View {
    var body: some View {
        ZStack {
            // Dashed border
            RoundedRectangle(cornerRadius: 0)
                .stroke(style: StrokeStyle(lineWidth: 4, dash: [10]))
                .foregroundColor(.white)
            
            // Inner solid border for visibility
            RoundedRectangle(cornerRadius: 0)
                .stroke(style: StrokeStyle(lineWidth: 2))
                .foregroundColor(.black.opacity(0.5))
                .padding(2)
        }
        .edgesIgnoringSafeArea(.all)
    }
}
