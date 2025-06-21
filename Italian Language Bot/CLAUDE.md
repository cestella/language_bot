# Pocket Polyglot - Project Documentation

## Project Overview

Pocket Polyglot is a macOS SwiftUI application designed for multi-language learning. The app generates conversation scenarios using Apple's on-device LLM capabilities and provides speech recognition for pronunciation practice with comprehensive contextual feedback.

## Key Features

- **Multi-Language Support**: Italian, Spanish, and French language learning with dynamic language switching
- **Scenario Generation**: Uses FoundationModels framework with @Generable structures for guided generation
- **Speech Recognition**: Real-time multi-language speech recognition with automatic model downloading
- **Contextual Feedback**: ✔ Grammar/Phrase analysis and 🔄 Suggested rewrites with detailed explanations
- **Conversation UI**: iMessage-style alternating bubbles with translation capabilities
- **On-Device Processing**: Utilizes Apple Intelligence and on-device speech recognition (iOS 26+)
- **Visual Feedback**: Audio level visualization and comprehensive LLM processing indicators
- **Multi-Level Learning**: Supports CEFR levels from A1 (Beginner) to C2 (Proficient)

## Technical Stack

- **Platform**: iOS 26.0+ (requires latest iOS 26 beta)
- **Framework**: SwiftUI with Combine
- **LLM Integration**: FoundationModels framework (Apple Intelligence)
- **Speech Recognition**: SpeechTranscriber/SpeechAnalyzer APIs with multi-language support (it-IT, es-ES, fr-FR)
- **Audio Processing**: AVAudioEngine with real-time audio level monitoring and automatic asset downloading
- **Language**: Swift 5.0 with modern concurrency (async/await)
- **Guided Generation**: @Generable structs with @Guide annotations for precise LLM output control

## Build Requirements

### Critical Build Setup
- **Xcode**: Must use Xcode Beta (NOT regular Xcode)
- **Simulator**: iPhone 16 simulator with iOS 26.0
- **macOS**: Requires macOS with Apple Intelligence support
- **Device**: Can run on actual Mac hardware with macOS 28+ and Apple Intelligence

### Build Commands

```bash
# Build the app
cd "/Users/cstella/code/language_bot/Italian Language Bot"
xcodebuild -project "Italian Language Bot.xcodeproj" -scheme "Italian Language Bot" -destination "platform=macOS" build

# Run tests (may require development team setup)
xcodebuild test -project "Italian Language Bot.xcodeproj" -scheme "Italian Language Bot" -destination "platform=macOS"
```

## Project Structure

```
Italian Language Bot/
├── Italian Language Bot/
│   ├── ContentView.swift                 # Main app file with all core functionality
│   ├── Italian_Language_BotApp.swift    # App entry point (PocketPolyglotApp)
│   ├── Assets.xcassets                   # App assets
│   └── scenarios.json                    # Conversation scenarios data
├── Italian Language BotTests/           # Unit tests
├── Italian Language Bot.xcodeproj/      # Xcode project
└── CLAUDE.md                            # This documentation file
```

## Core Architecture

### Main Components

1. **SpeechRecognizer Class** (`ContentView.swift:134-600`)
   - Multi-language speech recognition (Italian, Spanish, French) with SpeechTranscriber/SpeechAnalyzer APIs
   - Automatic language model downloading with AssetInventory
   - Real-time audio level monitoring and comprehensive error handling
   - Dynamic language switching with locale management
   - Uses modern async/await patterns with proper cleanup

2. **LanguageLearningViewModel** (`ContentView.swift:620-875`)
   - Manages app state and multi-language LLM interactions
   - Handles scenario generation with @Generable structures and guided generation
   - Contextual feedback system with filtered conversation context
   - Integrates with FoundationModels for on-device LLM processing
   - Smart conversation bubble role assignment for alternating UI

3. **UI Components** (`ContentView.swift:880-1516`)
   - iMessage-style conversation bubbles with alternating left/right layout
   - Translation buttons with on-demand LLM translation
   - Comprehensive loading indicators for LLM processing states
   - Language-specific text input placeholders
   - Settings management for CEFR levels, categories, and language selection

4. **Guided Generation Structures** (`ContentView.swift:105-130`)
   - **ConversationScenario**: @Generable struct for scenario creation with participant management
   - **LanguageFeedback**: @Generable struct with detailed @Guide annotations for educational feedback
   - **ScenarioMessage**: @Generable struct for natural conversation flow

### Key Technical Features

- **Multi-Language Speech Recognition**: Dynamic language switching with automatic asset downloading
- **Guided Generation**: @Generable structs with @Guide annotations for controlled LLM output
- **Contextual Feedback**: Filtered conversation context excluding system messages and feedback pollution
- **Conversation UI**: Smart role assignment for alternating bubble layout (user=right/blue, assistant=left/gray)
- **Audio Level Monitoring**: Real-time RMS calculation with -60dB to 0dB normalization
- **Platform-Specific Code**: Uses `#if os(iOS)` for iOS-specific audio session management
- **Modern Concurrency**: Extensive use of `async/await` and `@MainActor` for UI updates
- **Asset Management**: Automatic GeneralASR model downloading with comprehensive error handling

## Permissions and Configuration

### Required Permissions (configured in project settings)
- `NSMicrophoneUsageDescription`: "This is so you can speak to the app"
- `NSSpeechRecognitionUsageDescription`: "So we can convert your speech to text"

### Audio Session Configuration
- **Category**: `.record` with `.spokenAudio` mode
- **Options**: `[.duckOthers, .defaultToSpeaker]`
- **Platform**: iOS-specific with proper cleanup

## Known Issues and Solutions

### Guided Generation Issues
- **Issue**: "Inference Provider crashed with 2:5" when generating feedback
- **Solution**: Simplified @Guide annotations to be concise rather than verbose multi-line instructions
- **Pattern**: Move detailed instructions to main prompts, keep @Guide descriptions short and focused

### Multi-Language Support Issues
- **Issue**: "No GeneralASR asset for language es" error for Spanish
- **Solution**: Implemented automatic asset downloading with AssetInventory.assetInstallationRequest
- **Features**: Comprehensive error handling, fallback mechanisms, and user feedback during download

### UI Race Conditions
- **Issue**: "Index out of range" crash when resetting conversations
- **Solution**: Added proper bounds checking and immediate state clearing in resetConversation()
- **Pattern**: Use guard statements for array access and clear state immediately on main thread

### Conversation Context Quality
- **Issue**: Poor feedback quality due to polluted conversation context
- **Solution**: Filter out system messages, feedback messages, and current user response from context
- **Result**: LLM receives only clean conversation flow for better contextual analysis

## Development Notes

### User Environment
- **Hardware**: Mac with Apple Intelligence support
- **OS**: macOS 28 with Apple Intelligence enabled
- **Development**: Prefers actual hardware over simulator for testing
- **Requirements**: Must use iOS 26.0 (NOT iOS 18 or earlier versions)

### Current Feature Set (2025)
User has successfully implemented:
1. **Multi-Language Support**: Italian, Spanish, French with dynamic switching
2. **iMessage-Style UI**: Alternating conversation bubbles with proper colors
3. **Translation Features**: On-demand translation buttons for all messages
4. **Contextual Feedback**: Educational grammar/phrase analysis with detailed explanations
5. **Smart Conversation Flow**: Automatic role assignment for natural bubble alternation
6. **Loading Indicators**: Comprehensive visual feedback for all LLM operations
7. **Guided Generation**: @Generable structures with @Guide annotations for reliable output

### Code Patterns
- **Guided Generation**: @Generable structs with concise @Guide annotations for LLM output control
- **Multi-Language**: public enum Language with code/displayName properties for locale management
- **Conversation Context**: Filtered arrays excluding system/feedback messages for clean LLM input
- **UI Safety**: Bounds checking with guard statements for array access in ForEach loops
- **State Management**: @Published properties with proper @MainActor usage and immediate state clearing
- **Memory Management**: Proper cleanup of audio engines and recognition tasks
- **Error Handling**: Custom RecognizerError enum with descriptive messages and comprehensive fallbacks

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