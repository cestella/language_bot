import SwiftUI
import Combine
import FoundationModels
// Use the new SpeechAnalyzer/SpeechTranscriber APIs from Speech framework
import Speech
import AVFoundation
import Observation
import Accelerate

// MARK: - Data Models

public enum Language: String, CaseIterable, Identifiable {
    case italian = "Italian"
    case spanish = "Spanish"
    case french = "French"
    
    public var id: String { rawValue }
    public var code: String {
        switch self {
        case .italian: return "it-IT"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        }
    }
    
    public var displayName: String {
        switch self {
        case .italian: return "Italiano"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }
}

enum CEFRLevel: String, CaseIterable, Identifiable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    
    var id: String { rawValue }
    var description: String {
        switch self {
        case .a1: return "A1 - Beginner"
        case .a2: return "A2 - Elementary"
        case .b1: return "B1 - Intermediate"
        case .b2: return "B2 - Upper Intermediate"
        case .c1: return "C1 - Advanced"
        case .c2: return "C2 - Proficient"
        }
    }
}

struct ScenarioCategory: Identifiable, Codable {
    let id = UUID()
    let category: String
    let scenarios: [String]
    
    var name: String { category }
    
    enum CodingKeys: String, CodingKey {
        case category, scenarios
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decode(String.self, forKey: .category)
        scenarios = try container.decode([String].self, forKey: .scenarios)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(category, forKey: .category)
        try container.encode(scenarios, forKey: .scenarios)
    }
    
    init(category: String, scenarios: [String]) {
        self.category = category
        self.scenarios = scenarios
    }
}

struct ScenariosData: Codable {
    let scenarios: [ScenarioCategory]
}

struct ConversationMessage: Identifiable {
    enum Role { case system, user, assistant, feedback }
    let id = UUID()
    let role: Role
    let text: String
    let speaker: String?
    
    init(role: Role, text: String, speaker: String? = nil) {
        self.role = role
        self.text = text
        self.speaker = speaker
    }
}

// MARK: - Generable Structures for LLM Output

@Generable
struct ConversationScenario: Equatable {
    @Guide(description: "Exactly 2 participants with appropriate names. Second participant is the learner.")
    let participants: [String]
    
    @Guide(description: "4-6 alternating conversation exchanges. Each participant speaks 2-3 times.")
    let messages: [ScenarioMessage]
}

@Generable 
struct ScenarioMessage: Equatable {
    @Guide(description: "Must be one of the participants from the participants array")
    let speaker: String
    
    @Guide(description: "Natural conversational text appropriate for the target language and level")
    let text: String
}

@Generable
struct LanguageFeedback: Equatable {
    @Guide(description: "If you were a local language speaker, would you understand the speaker?  If not, then tell them why not.  If so, then tell them that they did a good job.  Write at least 3 sentences.")
    let grammarPhrase: String
    
    @Guide(description: "If you were a local language speaker and you were told this phrase, what would you suggest they rewrite it as?  Write at least 3 sentences.")
    let suggestedRewrite: String
}

// MARK: - Modern Speech Recognizer

@MainActor
@Observable
public class SpeechRecognizer {
    public enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        public var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    public var transcript: String = ""
    public var isRecording: Bool = false
    public var audioLevel: Float = 0.0
    private var selectedLanguage: Language = .italian
    
    public var currentLocale: String {
        return selectedLanguage.code
    }
    
    // New on-device streaming analyzer & transcriber
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var audioEngine: AVAudioEngine?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<(), Error>?
    
    public init() {
        // Nothing to preconfigure—the SpeechAnalyzer API will handle permissions
        print("🔍 SpeechAnalyzer ready (permissions will be requested on first start).")
        
        // Check supported locales
        Task {
            await checkSupportedLocales()
        }
    }
    
    private func checkSupportedLocales() async {
        print("🌍 Checking SpeechTranscriber supported locales...")
        let supportedLocales = await SpeechTranscriber.supportedLocales
        print("📋 Supported locales (\(supportedLocales.count)):")
        for locale in supportedLocales.sorted(by: { $0.identifier < $1.identifier }) {
            print("   - \(locale.identifier) (\(locale.localizedString(forIdentifier: locale.identifier) ?? "Unknown"))")
        }
        
        // Check if Italian is supported
        let italianLocale = Locale(identifier: "it-IT")
        let isItalianSupported = supportedLocales.contains { $0.identifier(.bcp47) == italianLocale.identifier(.bcp47) }
        print("🇮🇹 Italian (it-IT) supported: \(isItalianSupported)")
        
        // Also check installed locales
        let installedLocales = await SpeechTranscriber.installedLocales
        print("💾 Installed locales (\(installedLocales.count)):")
        for locale in installedLocales.sorted(by: { $0.identifier < $1.identifier }) {
            print("   - \(locale.identifier) (\(locale.localizedString(forIdentifier: locale.identifier) ?? "Unknown"))")
        }
        
        let isItalianInstalled = installedLocales.contains { $0.identifier(.bcp47) == italianLocale.identifier(.bcp47) }
        print("🇮🇹 Italian (it-IT) installed: \(isItalianInstalled)")
    }
    
    public func startTranscribing() {
        print("🎤 Starting live transcription with SpeechAnalyzer…")
        Task {
            do {
                // Determine if selected language model needs installation
                let targetLocale = Locale(identifier: selectedLanguage.code)
                let supportedLocales = await SpeechTranscriber.supportedLocales
                let installedLocales = await SpeechTranscriber.installedLocales
                
                print("🌍 Checking \(selectedLanguage.rawValue) (\(selectedLanguage.code)) support...")
                
                // Check if selected language is supported
                let isSupported = supportedLocales.contains { $0.identifier == targetLocale.identifier }
                let isInstalled = installedLocales.contains { $0.identifier == targetLocale.identifier }
                
                print("🌍 \(selectedLanguage.rawValue) supported: \(isSupported), installed: \(isInstalled)")
                
                // If language is supported but not installed, try to download it
                if isSupported && !isInstalled {
                    print("⬇️ \(selectedLanguage.rawValue) ASR model not installed, requesting download…")
                    
                    do {
                        // Create transcriber to get installation request
                        let tempTranscriber = SpeechTranscriber(locale: targetLocale,
                                                              transcriptionOptions: [],
                                                              reportingOptions: [],
                                                              attributeOptions: [])
                        
                        if let installReq = try await AssetInventory.assetInstallationRequest(supporting: [tempTranscriber]) {
                            await MainActor.run {
                                transcript = "<< Downloading \(selectedLanguage.rawValue) ASR model >>"
                            }
                            
                            try await installReq.downloadAndInstall()
                            
                            print("✅ \(selectedLanguage.rawValue) ASR model installed")
                            await MainActor.run {
                                transcript = "\(selectedLanguage.rawValue) model ready"
                            }
                        } else {
                            print("⚠️ No download required for \(selectedLanguage.rawValue)")
                        }
                    } catch {
                        print("❌ Failed to download \(selectedLanguage.rawValue) model: \(error)")
                        print("❌ Detailed error: \(error.localizedDescription)")
                        
                        // Continue anyway - some languages may work without explicit model download
                        await MainActor.run {
                            transcript = "Warning: \(selectedLanguage.rawValue) model download failed, continuing anyway..."
                        }
                    }
                } else if !isSupported {
                    print("❌ \(selectedLanguage.rawValue) is not supported on this device")
                    await MainActor.run {
                        transcript = "\(selectedLanguage.rawValue) is not supported on this device"
                    }
                    throw RecognizerError.recognizerIsUnavailable
                }
                
                // Existing critical check
                if supportedLocales.isEmpty {
                    print("❌ CRITICAL: SpeechTranscriber has no supported locales")
                    print("   This indicates SpeechTranscriber APIs are not working in this environment")
                    print("   Possible causes:")
                    print("   - iOS 26 beta issue with SpeechTranscriber")
                    print("   - Simulator limitations")
                    print("   - Missing system speech models")
                    print("   - Entitlement or permission issue")
                    await MainActor.run {
                        transcript = "SpeechTranscriber APIs not available in this environment"
                    }
                    return
                }
                
                try await setUpTranscriber()
                try await startAudioEngine()
                
                await MainActor.run {
                    isRecording = true
                    print("✅ SpeechTranscriber started")
                }
                
            } catch {
                print("❌ Unable to start SpeechTranscriber: \(error)")
                await MainActor.run {
                    transcribe(error)
                }
            }
        }
    }
    
    private func setUpTranscriber() async throws {
        // Use the selected language or fall back to English
        let preferredLocale = await getAvailableLocale()
        print("🌍 Using locale: \(preferredLocale.identifier)")
        
        // Initialize transcriber with available locale and options  
        print("🔧 Setting up transcriber with locale: \(preferredLocale.identifier)")
        print("🔧 Transcription options: []")
        print("🔧 Reporting options: [.volatileResults]") 
        print("🔧 Attribute options: []")
        
        transcriber = SpeechTranscriber(locale: preferredLocale,
                                      transcriptionOptions: [],
                                      reportingOptions: [.volatileResults],
                                      attributeOptions: [])
        
        guard let transcriber else {
            throw RecognizerError.nilRecognizer
        }
        
        // Initialize analyzer with the transcriber module
        print("🔧 Creating SpeechAnalyzer with transcriber module...")
        analyzer = SpeechAnalyzer(modules: [transcriber])
        
        // Create input stream for audio data
        print("🔧 Creating input stream for audio data...")
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        
        guard let inputSequence else {
            print("❌ Failed to create input sequence")
            throw RecognizerError.recognizerIsUnavailable
        }
        
        // Start the analyzer with the input sequence
        print("🔧 Starting analyzer with input sequence...")
        try await analyzer?.start(inputSequence: inputSequence)
        print("✅ Analyzer started successfully")
        
        // Start processing transcription results
        recognizerTask = Task {
            do {
                print("🎯 Starting to listen for transcription results...")
                for try await result in transcriber.results {
                    let text = result.text
                    print("🎯 Received transcription result:")
                    print("   - Text: '\(text.description)'")
                    print("   - Is Final: \(result.isFinal)")
                    
                    await MainActor.run {
                        // Clean the text for display
                        let cleanedText = text.description
                            .replacingOccurrences(of: "{", with: "")
                            .replacingOccurrences(of: "}", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if result.isFinal {
                            transcript = cleanedText
                            print("📝 Final transcript: '\(cleanedText)'")
                            
                            // Process the final speech result for LLM feedback
                            if !cleanedText.isEmpty && !cleanedText.hasPrefix("<<") {
                                print("🎯 Processing final speech result: '\(cleanedText)'")
                                // Signal to the view model that we have a final result
                                NotificationCenter.default.post(name: NSNotification.Name("SpeechRecognitionComplete"), object: cleanedText)
                            }
                        } else {
                            transcript = cleanedText
                            print("📝 Partial transcript: '\(cleanedText)'")
                        }
                    }
                }
                print("🎯 Transcription results stream ended")
            } catch {
                print("❌ Speech recognition failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ Error domain: \(nsError.domain)")
                    print("❌ Error code: \(nsError.code)")
                    print("❌ Error userInfo: \(nsError.userInfo)")
                }
                await MainActor.run {
                    transcribe(error)
                }
            }
        }
    }
    
    public func updateLanguage(_ language: Language) {
        selectedLanguage = language
        print("🌍 Language updated to \(language.rawValue) (\(language.code))")
    }
    
    private func getAvailableLocale() async -> Locale {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let installedLocales = await SpeechTranscriber.installedLocales
        
        // Always prefer selected language if supported (model will be auto-downloaded)
        let targetLocale = Locale(identifier: selectedLanguage.code)
        let isSupported = supportedLocales.contains { $0.identifier == targetLocale.identifier }
        let isInstalled = installedLocales.contains { $0.identifier == targetLocale.identifier }
        
        if isSupported {
            return targetLocale
        }
        
        // Fall back to English (US) which should always be available
        let englishLocale = Locale(identifier: "en-US")
        print("🇺🇸 Falling back to English (en-US)")
        return englishLocale
    }
    
    private func startAudioEngine() async throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .spokenAudio, options: [.defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        print("✅ Audio session configured")
        #endif
        
        let inputNode = audioEngine.inputNode
        guard let transcriber = transcriber else { return }

        // Get the analyzer's preferred format and the input node's native format
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            print("❌ Unable to get analyzer audio format")
            return
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎙️ Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channel(s)")
        print("🔊 Analyzer format: \(analyzerFormat.sampleRate) Hz, \(analyzerFormat.channelCount) channel(s)")

        // Use the input node's native format for tapping, then convert
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let inputBuilder = self.inputBuilder else { return }

            // Audio level visualization from channel 0
            if let channelData = buffer.floatChannelData?[0] {
                let samples = UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength))
                let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
                let avgDB = 20 * log10(rms)
                let normalized = max(0, (avgDB + 60) / 60)
                Task { @MainActor in
                    self.audioLevel = normalized
                    if normalized > 0.1 { print("🔊 Audio level:", normalized) }
                }
            }

            // Convert buffer to analyzer format if needed
            do {
                let convertedBuffer = try self.convertBuffer(buffer, to: analyzerFormat)
                let input = AnalyzerInput(buffer: convertedBuffer)
                inputBuilder.yield(input)
                
                // Log occasionally to verify audio is being sent
                if Int.random(in: 1...100) == 1 {
                    print("🔄 Sent audio buffer to analyzer: \(convertedBuffer.frameLength) frames")
                }
            } catch {
                print("❌ Audio conversion error: \(error)")
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        print("✅ Audio engine started")
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else {
            return buffer
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else {
            throw RecognizerError.recognizerIsUnavailable
        }
        
        let sampleRateRatio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let scaledInputFrameLength = Double(buffer.frameLength) * sampleRateRatio
        let frameCapacity = AVAudioFrameCount(scaledInputFrameLength.rounded(.up))
        
        guard let conversionBuffer = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: frameCapacity) else {
            throw RecognizerError.recognizerIsUnavailable
        }
        
        var nsError: NSError?
        var bufferProcessed = false
        
        let status = converter.convert(to: conversionBuffer, error: &nsError) { _, inputStatusPointer in
            defer { bufferProcessed = true }
            inputStatusPointer.pointee = bufferProcessed ? .noDataNow : .haveData
            return bufferProcessed ? nil : buffer
        }
        
        guard status != .error else {
            throw RecognizerError.recognizerIsUnavailable
        }
        
        return conversionBuffer
    }
    
    public func resetTranscript() {
        Task { @MainActor in
            transcript = ""
            audioLevel = 0.0
        }
    }
    
    public func stopTranscribing() {
        print("🛑 Stopping live transcription…")
        Task {
            // Stop audio engine first
            audioEngine?.stop()
            if let inputNode = audioEngine?.inputNode, inputNode.numberOfInputs > 0 {
                inputNode.removeTap(onBus: 0)
            }
            
            // Signal end of input
            inputBuilder?.finish()
            
            do {
                try await analyzer?.finalizeAndFinishThroughEndOfInput()
            } catch {
                print("❌ Error finalizing transcription: \(error)")
            }
            
            // Cancel recognition task
            recognizerTask?.cancel()
            recognizerTask = nil
            
            #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Error deactivating audio session: \(error)")
            }
            #endif
            
            await MainActor.run {
                isRecording = false
                audioLevel = 0.0
                print("✅ SpeechAnalyzer session ended")
            }
        }
    }
    
    private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    
    private func transcribe(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}

// Note: SpeechTranscriber uses async iteration rather than delegate pattern
// The transcription results are handled in the startTranscribing() method

// MARK: - View Models

@MainActor
@Observable
class LanguageLearningViewModel {
    var selectedLanguage: Language = .italian {
        didSet {
            speechRecognizer.updateLanguage(selectedLanguage)
        }
    }
    var selectedCEFRLevel: CEFRLevel = .a1
    var selectedCategory: String = ""
    var selectedScenario: String = ""
    var conversations: [ConversationMessage] = []
    var isProcessing = false
    var hasStartedConversation = false
    var scenarioCategories: [ScenarioCategory] = []
    var userTextInput: String = ""
    var isGeneratingScenario = false
    var isResettingConversation = false
    var currentScenario: ConversationScenario?
    
    // Modern Speech Recognition
    var speechRecognizer = SpeechRecognizer()
    
    // LLM Session
    private let session: LanguageModelSession = {
        print("🚀 Initializing LanguageModelSession...")
        let session = LanguageModelSession(instructions: "You are a helpful language learning assistant who creates realistic conversation scenarios and provides detailed feedback for language learners.")
        print("✅ LanguageModelSession initialized successfully")
        return session
    }()
    var lastError: String = ""
    
    var availableScenarios: [String] {
        scenarioCategories.first { $0.name == selectedCategory }?.scenarios ?? []
    }
    
    private func getRandomScenario(for category: String) -> String? {
        guard let categoryData = scenarioCategories.first(where: { $0.name == category }),
              !categoryData.scenarios.isEmpty else { return nil }
        return categoryData.scenarios.randomElement()
    }
    
    init() {
        print("🔧 System Info:")
        #if os(iOS)
        print("   iOS Version: \(UIDevice.current.systemVersion)")
        print("   Device Model: \(UIDevice.current.model)")
        print("   Device Name: \(UIDevice.current.name)")
        #else
        print("   macOS Platform")
        #endif
        
        loadScenarios()
        loadSavedSettings()
        
        // Initialize speech recognizer with default language
        speechRecognizer.updateLanguage(selectedLanguage)
        
        // Listen for speech recognition completion
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpeechRecognitionComplete"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let finalText = notification.object as? String {
                print("🎯 ViewModel received final speech result: '\(finalText)'")
                Task { @MainActor in
                    self?.processSpeechResult(finalText)
                    // Reset transcript after processing
                    self?.speechRecognizer.resetTranscript()
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SpeechRecognitionComplete"), object: nil)
    }
    
    private func loadSavedSettings() {
        if let savedLevel = UserDefaults.standard.object(forKey: "selectedCEFRLevel") as? String,
           let level = CEFRLevel(rawValue: savedLevel) {
            selectedCEFRLevel = level
        }
        
        let savedCategory = UserDefaults.standard.string(forKey: "selectedCategory") ?? ""
        selectedCategory = savedCategory
    }
    
    func saveSettings() {
        UserDefaults.standard.set(selectedCEFRLevel.rawValue, forKey: "selectedCEFRLevel")
        UserDefaults.standard.set(selectedCategory, forKey: "selectedCategory")
    }
    
    private func loadScenarios() {
        guard let path = Bundle.main.path(forResource: "scenarios", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("Could not load scenarios.json file")
            loadFallbackScenarios()
            return
        }
        
        do {
            let scenariosData = try JSONDecoder().decode(ScenariosData.self, from: data)
            self.scenarioCategories = scenariosData.scenarios
        } catch {
            print("Error decoding scenarios: \(error)")
            loadFallbackScenarios()
        }
    }
    
    private func loadFallbackScenarios() {
        scenarioCategories = [
            ScenarioCategory(category: "Meeting on the Street", scenarios: [
                "Two good friends meet in a park, greet each other warmly and discuss what activities they could do together in the park"
            ]),
            ScenarioCategory(category: "Ordering Food", scenarios: [
                "A customer enters a traditional Italian restaurant and asks the waiter about today's special dishes and wine recommendations"
            ])
        ]
    }
    
    func startConversation() async {
        guard !selectedCategory.isEmpty else { return }
        
        // Auto-select random scenario if none selected
        let scenarioToUse: String
        if selectedScenario.isEmpty {
            guard let randomScenario = getRandomScenario(for: selectedCategory) else { return }
            scenarioToUse = randomScenario
        } else {
            scenarioToUse = selectedScenario
        }
        
        isGeneratingScenario = true
        hasStartedConversation = true
        conversations.removeAll()
        
        let prompt = """
        Create a realistic \(selectedLanguage.rawValue) conversation at \(selectedCEFRLevel.rawValue) level for this setting: \(scenarioToUse)
        
        Generate natural dialogue appropriate for language learners.
        """
        
        do {
            print("📱 Generating conversation scenario with guided generation...")
            let response = try await session.respond(to: prompt, generating: ConversationScenario.self)
            print("✅ Scenario generated successfully")
            
            currentScenario = response.content
            
            // Convert to conversation messages with alternating sides:
            // if exactly two participants were generated, treat the second as "user-side" (blue/right)
            let participants = response.content.participants
            if participants.count == 2 {
                let learnerName = participants[1]
                for message in response.content.messages {
                    let role: ConversationMessage.Role =
                        (message.speaker == learnerName)
                            ? .user
                            : .assistant
                    conversations.append(
                        ConversationMessage(role: role,
                                            text: message.text,
                                            speaker: message.speaker)
                    )
                }
            } else {
                // fallback: everything as assistant
                for message in response.content.messages {
                    conversations.append(
                        ConversationMessage(role: .assistant,
                                            text: message.text,
                                            speaker: message.speaker)
                    )
                }
            }
            
            // Add instruction for user to respond
            conversations.append(ConversationMessage(role: .system, text: "YOUR TURN: Respond to continue the conversation naturally."))
            
            lastError = ""
        } catch {
            let errorMessage = "LLM Error: \(error)"
            print("❌ LLM Error Details:")
            print("   Error: \(error)")
            print("   Error Type: \(type(of: error))")
            print("   Error Description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   Error Domain: \(nsError.domain)")
                print("   Error Code: \(nsError.code)")
                print("   Error UserInfo: \(nsError.userInfo)")
            }
            lastError = errorMessage
            conversations.append(ConversationMessage(role: .system, text: "❌ Error generating conversation: \(error.localizedDescription)"))
        }
        
        isGeneratingScenario = false
    }
    
    func startRecording() {
        print("📱 ViewModel startRecording called")
        speechRecognizer.startTranscribing()
    }
    
    func stopRecording() {
        print("📱 ViewModel stopRecording called")
        speechRecognizer.stopTranscribing()
        
        // Note: Final transcript processing now happens automatically when 
        // the transcription engine provides the final result via notification
        print("🎯 Waiting for final transcription result...")
        
        // Reset transcript for next recording (this will be called after processing)
        // speechRecognizer.resetTranscript()
    }
    
    func processSpeechResult(_ spokenText: String) {
        guard !spokenText.isEmpty else { return }
        
        conversations.append(ConversationMessage(role: .user, text: spokenText))
        
        Task {
            await provideFeedback(for: spokenText)
        }
    }
    
    func provideFeedback(for userResponse: String) async {
        isProcessing = true
        
        // Build context from the actual conversation flow, filtering out system messages, feedback, and the current user response
        let conversationContext = conversations
            .filter { msg in
                // Only include actual conversation messages
                guard msg.role != .system && msg.role != .feedback else { return false }
                // Don't include the current user response being analyzed
                if msg.role == .user && msg.text == userResponse {
                    return false
                }
                return true
            }
            .map { msg in
                let speakerName: String
                switch msg.role {
                case .user:
                    speakerName = "You"
                case .assistant:
                    speakerName = msg.speaker ?? "Assistant"
                case .system, .feedback:
                    speakerName = "" // Should never reach here due to filter
                }
                return "\(speakerName): \(msg.text)"
            }
            .joined(separator: "\n")
        
        let prompt = """
        You are an expert \(selectedLanguage.rawValue) language teacher. Provide detailed, educational feedback on this student's response.
        
        CONVERSATION CONTEXT:
        \(conversationContext)
        
        STUDENT'S RESPONSE: "\(userResponse)" (at \(selectedCEFRLevel.rawValue) level)
        """
        //Analyze both grammar (verb conjugations, word order, etc.) and contextual fit (does it follow the conversation logically?). Be specific about what's wrong and why. If off-topic, explain what would be more appropriate given the conversation context.
        print(prompt)
        do {
            print("📱 Generating language feedback with guided generation...")
            let response = try await session.respond(to: prompt, generating: LanguageFeedback.self)
            print("✅ Feedback generated successfully")
            
            let feedback = response.content
            
            // Add structured feedback as separate messages
            conversations.append(ConversationMessage(role: .feedback, text: "✔ Grammar/Phrase:\n\(feedback.grammarPhrase)"))
            conversations.append(ConversationMessage(role: .feedback, text: "🔄 Suggested rewrite:\n\(feedback.suggestedRewrite)"))
            
            lastError = ""
        } catch {
            let errorMessage = "LLM Error: \(error)"
            print("❌ Feedback generation error: \(error)")
            lastError = errorMessage
            conversations.append(ConversationMessage(role: .feedback, text: "Error generating feedback: \(error)"))
        }
        
        isProcessing = false
    }
    
    func submitTextInput() {
        let text = userTextInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        processSpeechResult(text)
        userTextInput = ""
    }
    
    
    func resetConversation() {
        // Immediately clear the conversation to prevent UI race conditions
        conversations.removeAll()
        hasStartedConversation = false
        currentScenario = nil
        speechRecognizer.resetTranscript()
        
        isResettingConversation = true
        
        Task {
            // Add a small delay to show the loading state
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isResettingConversation = false
            }
        }
    }
}

// MARK: - Views

struct ContentView: View {
    @State private var viewModel = LanguageLearningViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content area
            VStack(spacing: 0) {
                // Header with settings
                VStack(spacing: 5) {
                    HStack {
                        Text("Pocket Polyglot")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Error indicator
                    if !viewModel.lastError.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(viewModel.lastError)
                                .font(.caption)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                .padding()
                
                if !viewModel.hasStartedConversation {
                    Spacer()
                    
                    // Category selection and start button
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Text("Select a conversation scenario:")
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            if !viewModel.scenarioCategories.isEmpty {
                                Picker("Category", selection: $viewModel.selectedCategory) {
                                    Text("Choose Category").tag("")
                                    ForEach(viewModel.scenarioCategories) { category in
                                        Text(category.name).tag(category.name)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(width: 200)
                            }
                        }
                        
                        Button("Start Conversation") {
                            Task {
                                await viewModel.startConversation()
                            }
                        }
                        .disabled(viewModel.selectedCategory.isEmpty || viewModel.isGeneratingScenario)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(viewModel.selectedCategory.isEmpty || viewModel.isGeneratingScenario ? Color.secondary : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(PlainButtonStyle())
                        
                        if viewModel.isGeneratingScenario {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generating \(viewModel.selectedLanguage.rawValue) scenario...")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Text("Creating conversation for \(viewModel.selectedCEFRLevel.rawValue) level")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: 400)
                    
                    Spacer()
                } else {
                    // Conversation view
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(viewModel.conversations.enumerated()), id: \.element.id) { index, message in
                                let previousMessage: ConversationMessage? = {
                                    guard index > 0 && index - 1 < viewModel.conversations.count else { return nil }
                                    return viewModel.conversations[index - 1]
                                }()
                                ConversationBubble(
                                    message: message,
                                    previousMessage: previousMessage
                                )
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    
                    // Recording controls
                    VStack(spacing: 20) {
                        HStack(spacing: 30) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    let currentState = viewModel.speechRecognizer.isRecording
                                    print("🎤 Microphone button tapped - Current state: \(currentState ? "Recording" : "Not Recording")")
                                    print("🔍 UI Debug - isRecording: \(currentState), audioLevel: \(viewModel.speechRecognizer.audioLevel)")
                                    if currentState {
                                        print("🛑 Stopping recording...")
                                        viewModel.stopRecording()
                                    } else {
                                        print("▶️ Starting recording...")
                                        viewModel.startRecording()
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(viewModel.speechRecognizer.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: viewModel.speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(viewModel.speechRecognizer.isRecording ? .red : .blue)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(viewModel.isProcessing || viewModel.isGeneratingScenario)
                                
                                // Recording status text
                                Text(viewModel.speechRecognizer.isRecording ? "🎙️ Recording..." : "Tap to Record")
                                    .font(.caption)
                                    .foregroundColor(viewModel.speechRecognizer.isRecording ? .red : .blue)
                                    .animation(.easeInOut, value: viewModel.speechRecognizer.isRecording)
                                
                                // Audio level visualization
                                if viewModel.speechRecognizer.isRecording {
                                    VStack(spacing: 4) {
                                        Text("Audio Level")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        ProgressView(value: viewModel.speechRecognizer.audioLevel, total: 1.0)
                                            .progressViewStyle(LinearProgressViewStyle(tint: viewModel.speechRecognizer.audioLevel > 0.1 ? .green : .secondary))
                                            .frame(width: 80, height: 6)
                                        
                                        Text("\(Int(viewModel.speechRecognizer.audioLevel * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                        }
                        
                        // Text input alternative
                        VStack(spacing: 12) {
                            Text("Or type your response:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                TextField("Type in \(viewModel.selectedLanguage.rawValue)...", text: $viewModel.userTextInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(viewModel.isProcessing || viewModel.isGeneratingScenario)
                                    .font(.body)
                                
                                Button("Send") {
                                    viewModel.submitTextInput()
                                }
                                .disabled(viewModel.userTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing || viewModel.isGeneratingScenario)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(viewModel.userTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing || viewModel.isGeneratingScenario ? Color.secondary : Color.blue)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 12)
                        
                        if viewModel.isProcessing {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Analyzing your \(viewModel.selectedLanguage.rawValue) response...")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Text("Generating contextual feedback")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Language status indicator
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Speech Language: \(viewModel.speechRecognizer.currentLocale)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        if !viewModel.speechRecognizer.transcript.isEmpty {
                            Text("Live transcript: \(viewModel.speechRecognizer.transcript)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        HStack {
                            Button("Reset Conversation") {
                                viewModel.resetConversation()
                            }
                            .disabled(viewModel.isResettingConversation)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(viewModel.isResettingConversation ? Color.secondary : Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .buttonStyle(PlainButtonStyle())
                            
                            if viewModel.isResettingConversation {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(minWidth: 500)
            
            // Sidebar with settings and info
            VStack(spacing: 20) {
                // Quick settings panel
                GroupBox("Quick Settings") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Language:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Language", selection: $viewModel.selectedLanguage) {
                                ForEach(Language.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("CEFR Level:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Level", selection: $viewModel.selectedCEFRLevel) {
                                ForEach(CEFRLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            Text("Category:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("Category", selection: $viewModel.selectedCategory) {
                                Text("None").tag("")
                                ForEach(viewModel.scenarioCategories) { category in
                                    Text(category.name).tag(category.name)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Conversation stats
                if viewModel.hasStartedConversation {
                    GroupBox("Conversation Stats") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Messages:")
                                    .font(.caption)
                                Spacer()
                                Text("\(viewModel.conversations.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("User responses:")
                                    .font(.caption)
                                Spacer()
                                Text("\(viewModel.conversations.filter { $0.role == .user }.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Speech recognition status
                GroupBox("Speech Recognition") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Language:")
                                .font(.caption)
                            Spacer()
                            Text(viewModel.selectedLanguage.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Status:")
                                .font(.caption)
                            Spacer()
                            Text(viewModel.speechRecognizer.isRecording ? "Recording" : "Ready")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(viewModel.speechRecognizer.isRecording ? .red : .green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer()
                
                // Help text
                GroupBox("Tips") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Click the translate button next to \(viewModel.selectedLanguage.rawValue) messages for English translation")
                            .font(.caption)
                        
                        Text("🎯 Your responses are graded on both grammar and conversational context")
                            .font(.caption)
                        
                        Text("🎤 Use speech or text input - both work great!")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(width: 250)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 800, minHeight: 500)
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel, isPresented: $showingSettings)
                .presentationDetents([.height(350)])
        }
    }
}

struct ConversationBubble: View {
    let message: ConversationMessage
    let previousMessage: ConversationMessage?
    @State private var showTranslation = false
    @State private var translation = ""
    @State private var isTranslating = false
    
    var body: some View {
        HStack(alignment: .top) {
            // Left side spacer for user messages (pushes them right)
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Speaker name above bubble (only if different from previous message)
                if shouldShowSpeakerName {
                    Text(message.speaker ?? roleDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    // Translation button for non-user messages (on the left)
                    if message.role != .user && (message.role == .assistant || message.role == .system) {
                        Button(action: { toggleTranslation() }) {
                            Image(systemName: showTranslation ? "eye.slash" : "translate")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isTranslating)
                    }
                    
                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                        // Main message bubble
                        Text(message.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(backgroundColorForRole(message.role))
                            .foregroundColor(textColorForRole(message.role))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .textSelection(.enabled)
                        
                        // Translation display
                        if showTranslation && !translation.isEmpty {
                            Text(translation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        if isTranslating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Translating...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Translation button for user messages (on the right)
                    if message.role == .user {
                        Button(action: { toggleTranslation() }) {
                            Image(systemName: showTranslation ? "eye.slash" : "translate")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isTranslating)
                    }
                }
            }
            
            // Right side spacer for non-user messages (pushes them left)
            if message.role != .user {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    private var shouldShowSpeakerName: Bool {
        guard let speaker = message.speaker else {
            // For messages without speaker, only show name if role changed
            return previousMessage?.role != message.role
        }
        
        // Show speaker name if it's different from previous message
        return previousMessage?.speaker != speaker
    }
    
    private var roleDisplayName: String {
        switch message.role {
        case .system: return "System"
        case .user: return "You"
        case .assistant: return "Assistant"
        case .feedback: return "Feedback"
        }
    }
    
    private func translateMessage() {
        guard !isTranslating else { return }
        
        isTranslating = true
        
        Task {
            do {
                let session = LanguageModelSession(instructions: "You are a helpful translation assistant.")
                let prompt = "Translate this Italian text to English: \"\(message.text)\""
                let response = try await session.respond(to: prompt)
                
                await MainActor.run {
                    translation = response.content
                    showTranslation = true
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    translation = "Translation failed: \(error.localizedDescription)"
                    showTranslation = true
                    isTranslating = false
                }
            }
        }
    }
    
    private func toggleTranslation() {
        if showTranslation {
            showTranslation = false
        } else {
            translateMessage()
        }
    }
    
    private func backgroundColorForRole(_ role: ConversationMessage.Role) -> Color {
        switch role {
        case .system:
            return Color.orange.opacity(0.2)
        case .user:
            return Color.blue           // User messages in blue (like iMessage)
        case .assistant:
            return Color.gray.opacity(0.2) // Assistant messages in a light gray
        case .feedback:
            return Color.purple.opacity(0.15)
        }
    }
    
    private func textColorForRole(_ role: ConversationMessage.Role) -> Color {
        switch role {
        case .system:
            return .primary
        case .user:
            return .white  // White text on blue background
        case .assistant:
            return .primary  // Dark text on gray background
        case .feedback:
            return .purple
        }
    }
}

struct SettingsView: View {
    @Bindable var viewModel: LanguageLearningViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    viewModel.saveSettings()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 8)
            
            // Settings content
            VStack(spacing: 20) {
                GroupBox("Language") {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(Language.allCases) { language in
                            HStack {
                                Text(language.displayName)
                                Text("("+language.rawValue+")")
                                    .foregroundColor(.secondary)
                            }
                            .tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                }
                
                GroupBox("CEFR Level") {
                    Picker("Level", selection: $viewModel.selectedCEFRLevel) {
                        ForEach(CEFRLevel.allCases) { level in
                            Text(level.description).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 8)
                }
                
                GroupBox("Conversation Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("None Selected").tag("")
                        ForEach(viewModel.scenarioCategories) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 8)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
