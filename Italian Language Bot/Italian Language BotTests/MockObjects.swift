import Foundation
import Combine
import XCTest
@testable import Italian_Language_Bot

// MARK: - Mock LLM Session

class MockLanguageModelSession {
    var shouldFail = false
    var responseDelay: TimeInterval = 0
    var mockResponses: [String] = []
    private var responseIndex = 0
    
    init(instructions: String = "") {
        // Initialize with default mock responses
        mockResponses = [
            "Person A: Ciao! Come stai?\nPerson B: Bene, grazie! E tu?\nYOUR TURN: Respond to continue the conversation.",
            "Great job! Your pronunciation was clear. Try to use 'molto bene' instead of just 'bene' for a more complete response."
        ]
    }
    
    func respond(to prompt: String) async throws -> MockLLMResponse {
        if shouldFail {
            throw MockLLMError.networkError
        }
        
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        let response = getNextResponse()
        return MockLLMResponse(content: response)
    }
    
    private func getNextResponse() -> String {
        guard !mockResponses.isEmpty else {
            return "Default mock response"
        }
        
        let response = mockResponses[responseIndex]
        responseIndex = (responseIndex + 1) % mockResponses.count
        return response
    }
    
    func addMockResponse(_ response: String) {
        mockResponses.append(response)
    }
    
    func setMockResponses(_ responses: [String]) {
        mockResponses = responses
        responseIndex = 0
    }
}

struct MockLLMResponse {
    let content: String
}

enum MockLLMError: Error {
    case networkError
    case invalidResponse
    case timeout
}

// MARK: - Mock Speech Recognizer

class MockSpeechRecognizer {
    var isAvailable = true
    var authorizationStatus: MockSpeechRecognitionAuthorizationStatus = .authorized
    var shouldFailRecognition = false
    var mockTranscriptions: [String] = ["Ciao, come stai?", "Molto bene, grazie"]
    private var transcriptionIndex = 0
    
    func requestAuthorization(completion: @escaping (MockSpeechRecognitionAuthorizationStatus) -> Void) {
        DispatchQueue.main.async {
            completion(self.authorizationStatus)
        }
    }
    
    func startRecognition(completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.shouldFailRecognition {
                completion(.failure(MockSpeechError.recognitionFailed))
            } else {
                let transcription = self.getNextTranscription()
                completion(.success(transcription))
            }
        }
    }
    
    private func getNextTranscription() -> String {
        guard !mockTranscriptions.isEmpty else {
            return "Default transcription"
        }
        
        let transcription = mockTranscriptions[transcriptionIndex]
        transcriptionIndex = (transcriptionIndex + 1) % mockTranscriptions.count
        return transcription
    }
    
    func addMockTranscription(_ transcription: String) {
        mockTranscriptions.append(transcription)
    }
}

enum MockSpeechRecognitionAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
}

enum MockSpeechError: Error {
    case recognitionFailed
    case noMicrophoneAccess
    case timeout
}

// MARK: - Mock Audio Engine

class MockAudioEngine {
    var isRunning = false
    var shouldFailToStart = false
    
    func start() throws {
        if shouldFailToStart {
            throw MockAudioError.failedToStart
        }
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func reset() {
        isRunning = false
        shouldFailToStart = false
    }
}

enum MockAudioError: Error {
    case failedToStart
    case noInputAvailable
}

// MARK: - Mock Bundle for Testing

class MockBundle {
    private var resources: [String: String] = [:]
    
    func setMockResource(name: String, type: String, content: String) {
        let key = "\(name).\(type)"
        resources[key] = content
    }
    
    func path(forResource name: String?, ofType ext: String?) -> String? {
        guard let name = name, let ext = ext else { return nil }
        let key = "\(name).\(ext)"
        return resources[key] != nil ? "/mock/path/\(key)" : nil
    }
    
    func data(forResource name: String, withExtension ext: String) -> Data? {
        let key = "\(name).\(ext)"
        return resources[key]?.data(using: .utf8)
    }
}

// MARK: - Testable ViewModel with Mocks

@MainActor
class TestableLanguageLearningViewModelWithMocks: ObservableObject {
    @Published var selectedLanguage: Language = .italian
    @Published var selectedCEFRLevel: CEFRLevel = .a1
    @Published var selectedCategory: String = ""
    @Published var selectedScenario: String = ""
    @Published var conversations: [ConversationMessage] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var hasStartedConversation = false
    @Published var scenarioCategories: [ScenarioCategory] = []
    
    // Mock dependencies
    var mockLLMSession: MockLanguageModelSession
    var mockSpeechRecognizer: MockSpeechRecognizer
    var mockAudioEngine: MockAudioEngine
    var mockBundle: MockBundle
    
    // Test tracking
    var lastError: Error?
    var speechRecognitionStarted = false
    var speechRecognitionStopped = false
    
    var availableScenarios: [String] {
        scenarioCategories.first { $0.name == selectedCategory }?.scenarios ?? []
    }
    
    private func getRandomScenario(for category: String) -> String? {
        guard let categoryData = scenarioCategories.first(where: { $0.name == category }),
              !categoryData.scenarios.isEmpty else { return nil }
        return categoryData.scenarios.randomElement()
    }
    
    init() {
        mockLLMSession = MockLanguageModelSession()
        mockSpeechRecognizer = MockSpeechRecognizer()
        mockAudioEngine = MockAudioEngine()
        mockBundle = MockBundle()
        
        setupMockData()
    }
    
    private func setupMockData() {
        scenarioCategories = [
            ScenarioCategory(category: "Restaurant", scenarios: [
                "Order dinner at a traditional Italian restaurant",
                "Ask about menu items and dietary restrictions"
            ]),
            ScenarioCategory(category: "Travel", scenarios: [
                "Ask for directions in a new city",
                "Book a hotel room"
            ])
        ]
        
        // Setup mock JSON
        let mockJSON = """
        {
            "scenarios": [
                {
                    "category": "Restaurant",
                    "scenarios": ["Order food", "Ask about wine"]
                }
            ]
        }
        """
        mockBundle.setMockResource(name: "scenarios", type: "json", content: mockJSON)
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
        
        isProcessing = true
        hasStartedConversation = true
        conversations.removeAll()
        
        do {
            let response = try await mockLLMSession.respond(to: "Generate conversation for: \(scenarioToUse)")
            conversations.append(ConversationMessage(role: .system, text: response.content))
        } catch {
            lastError = error
            conversations.append(ConversationMessage(role: .system, text: "Error: \(error.localizedDescription)"))
        }
        
        isProcessing = false
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            try mockAudioEngine.start()
            isRecording = true
            speechRecognitionStarted = true
        } catch {
            lastError = error
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        mockAudioEngine.stop()
        isRecording = false
        speechRecognitionStopped = true
        
        // Simulate speech recognition result
        mockSpeechRecognizer.startRecognition { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self?.processSpeechResult(transcription)
                case .failure(let error):
                    self?.lastError = error
                }
            }
        }
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
        
        do {
            let response = try await mockLLMSession.respond(to: "Provide feedback for: \(userResponse)")
            conversations.append(ConversationMessage(role: .feedback, text: response.content))
        } catch {
            lastError = error
            conversations.append(ConversationMessage(role: .feedback, text: "Error: \(error.localizedDescription)"))
        }
        
        isProcessing = false
    }
    
    func resetConversation() {
        conversations.removeAll()
        hasStartedConversation = false
        isRecording = false
        isProcessing = false
        speechRecognitionStarted = false
        speechRecognitionStopped = false
        lastError = nil
    }
    
    func loadScenariosFromBundle() {
        guard let data = mockBundle.data(forResource: "scenarios", withExtension: "json") else {
            lastError = MockError.resourceNotFound
            return
        }
        
        do {
            let scenariosData = try JSONDecoder().decode(ScenariosData.self, from: data)
            self.scenarioCategories = scenariosData.scenarios
        } catch {
            lastError = error
        }
    }
}

enum MockError: Error {
    case resourceNotFound
    case invalidData
}

// MARK: - Test Helpers

extension XCTestCase {
    
    func expectAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        toNotThrow message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Expected expression to not throw, but it threw: \(error). \(message)", file: file, line: line)
            return nil
        }
    }
    
    func expectAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        toThrow expectedError: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected expression to throw \(expectedError), but it didn't throw", file: file, line: line)
        } catch {
            // Success - error was thrown as expected
        }
    }
}

// MARK: - Mock Data Factory

class MockDataFactory {
    
    static func createMockScenarios() -> [ScenarioCategory] {
        return [
            ScenarioCategory(category: "Restaurant", scenarios: [
                "Order dinner at a traditional Italian restaurant",
                "Ask about menu items and dietary restrictions",
                "Complain about service politely",
                "Make a reservation for a special occasion"
            ]),
            ScenarioCategory(category: "Travel", scenarios: [
                "Ask for directions in a new city",
                "Book a hotel room",
                "Buy train tickets at the station",
                "Check in at the airport"
            ]),
            ScenarioCategory(category: "Shopping", scenarios: [
                "Buy clothes at a boutique",
                "Return a defective item",
                "Ask for price in local market",
                "Get recommendations from shopkeeper"
            ])
        ]
    }
    
    static func createMockConversation() -> [ConversationMessage] {
        return [
            ConversationMessage(role: .system, text: "Person A: Buongiorno!\nPerson B: Buongiorno! Come sta?\nYOUR TURN: Respond appropriately"),
            ConversationMessage(role: .user, text: "Bene, grazie! E lei?"),
            ConversationMessage(role: .feedback, text: "Excellent! Your response was perfect. Good use of formal language.")
        ]
    }
    
    static func createValidScenariosJSON() -> String {
        return """
        {
            "scenarios": [
                {
                    "category": "Test Category",
                    "scenarios": [
                        "Test scenario 1",
                        "Test scenario 2"
                    ]
                }
            ]
        }
        """
    }
    
    static func createInvalidScenariosJSON() -> String {
        return """
        {
            "scenarios": "not an array"
        }
        """
    }
}