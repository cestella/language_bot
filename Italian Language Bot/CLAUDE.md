# Pocket Polyglot - Project Documentation

## Project Overview

Pocket Polyglot is a macOS SwiftUI application designed for language learning. The app generates conversation scenarios using Apple's on-device LLM capabilities and provides speech recognition for pronunciation practice with real-time feedback.

## Key Features

- **Scenario Generation**: Uses FoundationModels framework to generate Italian conversation scenarios at different CEFR levels (A1-C2)
- **Speech Recognition**: Real-time Italian speech recognition with visual audio level feedback
- **On-Device Processing**: Utilizes Apple Intelligence and on-device speech recognition (iOS 26+)
- **Visual Feedback**: Audio level visualization during recording and LLM processing indicators
- **Multi-Level Learning**: Supports CEFR levels from A1 (Beginner) to C2 (Proficient)

## Technical Stack

- **Platform**: iOS 26.0+ (requires latest iOS 26 beta)
- **Framework**: SwiftUI with Combine
- **LLM Integration**: FoundationModels framework (Apple Intelligence)
- **Speech Recognition**: SFSpeechRecognizer with Italian locale (it-IT)
- **Audio Processing**: AVAudioEngine with real-time audio level monitoring
- **Language**: Swift 5.0 with modern concurrency (async/await)

## Build Requirements

### Critical Build Setup
- **Xcode**: Must use Xcode Beta (NOT regular Xcode)
- **Simulator**: iPhone 16 simulator with iOS 26.0
- **macOS**: Requires macOS with Apple Intelligence support
- **Device**: Can run on actual Mac hardware with macOS 28+ and Apple Intelligence

### Build Commands

```bash
# Build the app
cd "/Users/cstella/code/language_bot/Pocket Polyglot"
xcodebuild -project "Pocket Polyglot.xcodeproj" -scheme "Pocket Polyglot" -destination "platform=macOS" build

# Run tests
xcodebuild test -project "Pocket Polyglot.xcodeproj" -scheme "Pocket Polyglot" -destination "platform=macOS"
```

## Project Structure

```
Pocket Polyglot/
├── Pocket Polyglot/
│   ├── ContentView.swift                 # Main app file with all core functionality
│   ├── PocketPolyglotApp.swift          # App entry point
│   ├── Assets.xcassets                   # App assets
│   └── scenarios.json                    # Conversation scenarios data
├── Pocket PolyglotTests/                # Unit tests
├── Pocket Polyglot.xcodeproj/           # Xcode project
└── CLAUDE.md                            # This documentation file
```

## Core Architecture

### Main Components

1. **SpeechRecognizer Class** (`ContentView.swift:87-312`)
   - Handles Italian speech recognition with on-device processing
   - Provides real-time audio level monitoring
   - Implements proper error handling and permissions
   - Uses modern async/await patterns

2. **LanguageLearningViewModel** (`ContentView.swift:337-543`)
   - Manages app state and LLM interactions
   - Handles scenario generation and conversation flow
   - Integrates with FoundationModels for on-device LLM processing
   - Manages speech recognition lifecycle

3. **UI Components** (`ContentView.swift:547-808`)
   - SwiftUI interface with real-time visual feedback
   - Audio level visualization during recording
   - LLM processing indicators with spinner
   - Settings management for CEFR levels and categories

### Key Technical Features

- **On-Device Speech Recognition**: Forces `requiresOnDeviceRecognition = true` for Apple Intelligence systems
- **Audio Level Monitoring**: Real-time RMS calculation with -60dB to 0dB normalization
- **Platform-Specific Code**: Uses `#if os(iOS)` for iOS-specific audio session management
- **Modern Concurrency**: Extensive use of `async/await` and `@MainActor` for UI updates

## Permissions and Configuration

### Required Permissions (configured in project settings)
- `NSMicrophoneUsageDescription`: "This is so you can speak to the app"
- `NSSpeechRecognitionUsageDescription`: "So we can convert your speech to text"

### Audio Session Configuration
- **Category**: `.record` with `.spokenAudio` mode
- **Options**: `[.duckOthers, .defaultToSpeaker]`
- **Platform**: iOS-specific with proper cleanup

## Known Issues and Solutions

### Build Issues
- **Error**: "instance member 'audioLevel' cannot be used on type 'SpeechRecognizer'"
- **Solution**: Changed `prepareEngine()` from static to instance method to properly capture `self`

### Speech Recognition Issues
- **Issue**: On-device recognition not working despite Apple Intelligence
- **Solution**: Implemented intelligent fallback between on-device and cloud recognition
- **Debug**: Added comprehensive diagnostics for speech recognition capabilities

### Simulator Limitations
- **Note**: User specifically stated: "It is ABSOLUTELY not due to the simulator limitations"
- **Reality**: App works on both simulator and actual Mac hardware with Apple Intelligence

## Development Notes

### User Environment
- **Hardware**: Mac with Apple Intelligence support
- **OS**: macOS 28 with Apple Intelligence enabled
- **Development**: Prefers actual hardware over simulator for testing
- **Requirements**: Must use iOS 26.0 (NOT iOS 18 or earlier versions)

### Visual Feedback Requirements
User specifically requested restoration of:
1. **Audio Level Visualization**: Progress bar and percentage during recording
2. **LLM Processing Indicators**: Spinner with "Processing with LLM..." text
3. **Enhanced Debugging**: Console output for microphone state transitions

### Code Patterns
- **Imports**: Uses `import Accelerate` for audio processing math functions
- **Error Handling**: Custom `RecognizerError` enum with descriptive messages
- **State Management**: `@Published` properties with proper `@MainActor` usage
- **Memory Management**: Proper cleanup of audio engines and recognition tasks

## Debugging and Troubleshooting

### Common Debug Output
```
🔍 Speech Recognition Setup:
   Recognizer Available: true
   Supports On-Device: true
🎯 Speech Recognition Setup:
   Recognizer supports on-device: true
   Forcing on-device recognition: true
🎤 Starting transcription...
✅ Recognizer available, preparing engine...
🎙️ Audio engine started, creating recognition task...
```

### Test Strategy
- **Build Tests**: Ensure compilation succeeds with Xcode Beta
- **Speech Recognition**: Verify on-device recognition capabilities
- **Audio Levels**: Test real-time audio level visualization
- **LLM Integration**: Confirm FoundationModels framework integration

## Future Considerations

- **Scenario Data**: Currently uses hardcoded fallback scenarios; could expand JSON data
- **Language Support**: Architecture supports multiple languages (currently Italian only)
- **CEFR Levels**: Full A1-C2 support with appropriate content difficulty
- **Visual Polish**: Could enhance UI with additional Italian language learning features

## Important Commands Reference

```bash
# Clean build (if needed)
xcodebuild clean -project "Italian Language Bot.xcodeproj" -scheme "Italian Language Bot"

# Build with specific destination
xcodebuild -project "Italian Language Bot.xcodeproj" -scheme "Italian Language Bot" -destination "platform=iOS Simulator,name=iPhone 16,OS=26.0" build

# Run tests with coverage
xcodebuild test -project "Italian Language Bot.xcodeproj" -scheme "Italian Language Bot" -destination "platform=iOS Simulator,name=iPhone 16,OS=26.0" -enableCodeCoverage YES
```

This documentation should provide sufficient context for future development and debugging of the Pocket Polyglot application.