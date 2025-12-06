# ScreenBuddy

ScreenBuddy is a native macOS screen recording application built with SwiftUI and ScreenCaptureKit. It is designed to be a lightweight, high-performance tool for capturing your screen, specific windows, or custom areas.

## Features

- **Screen Recording**: Capture any connected display.
- **Window Recording**: Select and record specific application windows.
- **Area Recording**: Drag to select a custom portion of the screen to record.
  - **16:9 Aspect Ratio**: Area selection automatically enforces a 16:9 aspect ratio for standard video formatting.
- **Audio Capture**: (Implementation in progress) Support for system audio and microphone recording.
- **Camera Overlay**: (Implementation in progress) Overlay webcam feed on recordings.

## Requirements

- macOS 13.0 (Ventura) or later.

## Getting Started

### Building and Running

You can build and run the application using Swift Package Manager or Xcode.

**Using Terminal:**

```bash
swift run
```

**Using Xcode:**

1.  Open the project folder in Xcode.
2.  Select the `ScreenBuddy` scheme.
3.  Press `Cmd + R` to run.

## Architecture

The project is structured using the Feature-based architecture:

- `Sources/ScreenBuddy/Features`: Contains feature-specific logic (e.g., Recorder).
- `Sources/ScreenBuddy/UI`: Contains shared UI components.

## License

[Add License Information Here]
