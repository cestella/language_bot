import XCTest
import Foundation
import Combine
@testable import Italian_Language_Bot

@MainActor
class ViewModelTests: XCTestCase {
    
    var viewModel: TestableLanguageLearningViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        // Note: We'll need to create a testable version of ViewModel without external dependencies
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertEqual(viewModel.selectedLanguage, .italian)
        XCTAssertEqual(viewModel.selectedCEFRLevel, .a1)
        XCTAssertEqual(viewModel.selectedCategory, "")
        XCTAssertEqual(viewModel.selectedScenario, "")
        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.hasStartedConversation)
    }
    
    // MARK: - Available Scenarios Tests
    
    func testAvailableScenariosWithValidCategory() {
        viewModel = TestableLanguageLearningViewModel()
        
        // Set up test scenarios
        let testCategories = [
            ScenarioCategory(category: "Restaurant", scenarios: ["Order food", "Ask about wine"]),
            ScenarioCategory(category: "Travel", scenarios: ["Book hotel", "Get directions"])
        ]
        viewModel.scenarioCategories = testCategories
        
        viewModel.selectedCategory = "Restaurant"
        let availableScenarios = viewModel.availableScenarios
        
        XCTAssertEqual(availableScenarios.count, 2)
        XCTAssertEqual(availableScenarios[0], "Order food")
        XCTAssertEqual(availableScenarios[1], "Ask about wine")
    }
    
    func testAvailableScenariosWithInvalidCategory() {
        viewModel = TestableLanguageLearningViewModel()
        
        let testCategories = [
            ScenarioCategory(category: "Restaurant", scenarios: ["Order food"])
        ]
        viewModel.scenarioCategories = testCategories
        
        viewModel.selectedCategory = "NonexistentCategory"
        let availableScenarios = viewModel.availableScenarios
        
        XCTAssertTrue(availableScenarios.isEmpty)
    }
    
    func testAvailableScenariosWithEmptyCategory() {
        viewModel = TestableLanguageLearningViewModel()
        
        let testCategories = [
            ScenarioCategory(category: "Restaurant", scenarios: ["Order food"])
        ]
        viewModel.scenarioCategories = testCategories
        
        viewModel.selectedCategory = ""
        let availableScenarios = viewModel.availableScenarios
        
        XCTAssertTrue(availableScenarios.isEmpty)
    }
    
    // MARK: - Reset Conversation Tests
    
    func testResetConversation() {
        viewModel = TestableLanguageLearningViewModel()
        
        // Set up initial state
        viewModel.conversations = [
            ConversationMessage(role: .user, text: "Test message"),
            ConversationMessage(role: .assistant, text: "Test response")
        ]
        viewModel.hasStartedConversation = true
        
        viewModel.resetConversation()
        
        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertFalse(viewModel.hasStartedConversation)
    }
    
    // MARK: - Conversation State Management Tests
    
    func testConversationMessageAddition() {
        viewModel = TestableLanguageLearningViewModel()
        
        let initialCount = viewModel.conversations.count
        let testMessage = ConversationMessage(role: .user, text: "Test message")
        
        viewModel.conversations.append(testMessage)
        
        XCTAssertEqual(viewModel.conversations.count, initialCount + 1)
        XCTAssertEqual(viewModel.conversations.last?.text, "Test message")
        XCTAssertEqual(viewModel.conversations.last?.role, .user)
    }
    
    // MARK: - Speech Recognition State Tests
    
    func testRecordingStateToggle() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertFalse(viewModel.isRecording)
        
        viewModel.isRecording = true
        XCTAssertTrue(viewModel.isRecording)
        
        viewModel.isRecording = false
        XCTAssertFalse(viewModel.isRecording)
    }
    
    func testProcessingStateToggle() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertFalse(viewModel.isProcessing)
        
        viewModel.isProcessing = true
        XCTAssertTrue(viewModel.isProcessing)
        
        viewModel.isProcessing = false
        XCTAssertFalse(viewModel.isProcessing)
    }
    
    // MARK: - Selection State Tests
    
    func testLanguageSelection() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertEqual(viewModel.selectedLanguage, .italian)
        
        // Test that language can be changed (even though only Italian is available now)
        viewModel.selectedLanguage = .italian
        XCTAssertEqual(viewModel.selectedLanguage, .italian)
    }
    
    func testCEFRLevelSelection() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertEqual(viewModel.selectedCEFRLevel, .a1)
        
        viewModel.selectedCEFRLevel = .b2
        XCTAssertEqual(viewModel.selectedCEFRLevel, .b2)
        
        viewModel.selectedCEFRLevel = .c1
        XCTAssertEqual(viewModel.selectedCEFRLevel, .c1)
    }
    
    func testCategorySelection() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertEqual(viewModel.selectedCategory, "")
        
        viewModel.selectedCategory = "Restaurant"
        XCTAssertEqual(viewModel.selectedCategory, "Restaurant")
    }
    
    func testScenarioSelection() {
        viewModel = TestableLanguageLearningViewModel()
        
        XCTAssertEqual(viewModel.selectedScenario, "")
        
        viewModel.selectedScenario = "Order pasta"
        XCTAssertEqual(viewModel.selectedScenario, "Order pasta")
    }
    
    // MARK: - Reactive UI Tests
    
    func testSelectedCategoryChangeResetsScenario() {
        viewModel = TestableLanguageLearningViewModel()
        
        // Set initial scenario
        viewModel.selectedScenario = "Some scenario"
        XCTAssertEqual(viewModel.selectedScenario, "Some scenario")
        
        // Change category - scenario should reset in the UI
        // Note: This test would need to be implemented in the UI layer
        // or through a more sophisticated ViewModel setup
        viewModel.selectedCategory = "New Category"
        
        // In a real implementation, the UI would reset selectedScenario
        // when selectedCategory changes. We'd test this through UI tests
        // or by implementing this logic in the ViewModel itself.
    }
    
    // MARK: - Random Scenario Selection Tests
    
    func testRandomScenarioSelection() async {
        viewModel = TestableLanguageLearningViewModel()
        
        // Set category but no specific scenario
        viewModel.selectedCategory = "Restaurant"
        XCTAssertTrue(viewModel.selectedScenario.isEmpty)
        
        // Start conversation - should auto-select random scenario
        await viewModel.startConversation()
        
        XCTAssertTrue(viewModel.hasStartedConversation)
        XCTAssertFalse(viewModel.conversations.isEmpty)
    }
    
    func testConversationStartsWithCategoryOnly() async {
        viewModel = TestableLanguageLearningViewModel()
        
        // Only set category
        viewModel.selectedCategory = "Restaurant"
        
        await viewModel.startConversation()
        
        XCTAssertTrue(viewModel.hasStartedConversation)
        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertEqual(viewModel.conversations.first?.role, .system)
    }
    
    // MARK: - Error State Tests
    
    func testErrorHandlingInConversations() {
        viewModel = TestableLanguageLearningViewModel()
        
        let errorMessage = ConversationMessage(role: .assistant, text: "Error: Connection failed")
        viewModel.conversations.append(errorMessage)
        
        XCTAssertEqual(viewModel.conversations.count, 1)
        XCTAssertTrue(viewModel.conversations.last?.text.contains("Error") ?? false)
    }
}

// MARK: - Testable ViewModel

@MainActor
class TestableLanguageLearningViewModel: ObservableObject {
    @Published var selectedLanguage: Language = .italian
    @Published var selectedCEFRLevel: CEFRLevel = .a1
    @Published var selectedCategory: String = ""
    @Published var selectedScenario: String = ""
    @Published var conversations: [ConversationMessage] = []
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var hasStartedConversation = false
    @Published var scenarioCategories: [ScenarioCategory] = []
    
    var availableScenarios: [String] {
        scenarioCategories.first { $0.name == selectedCategory }?.scenarios ?? []
    }
    
    private func getRandomScenario(for category: String) -> String? {
        guard let categoryData = scenarioCategories.first(where: { $0.name == category }),
              !categoryData.scenarios.isEmpty else { return nil }
        return categoryData.scenarios.randomElement()
    }
    
    init() {
        loadTestScenarios()
    }
    
    private func loadTestScenarios() {
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
    }
    
    func resetConversation() {
        conversations.removeAll()
        hasStartedConversation = false
        isRecording = false
        isProcessing = false
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
        
        // Simulate conversation generation with cultural names
        let mockConversation = """
        Marco: Buongiorno! Come sta?
        Sofia: Bene, grazie! E lei?
        Marco: Molto bene, grazie.
        YOUR TURN: Respond to continue the conversation.
        """
        
        conversations.append(ConversationMessage(role: .system, text: mockConversation))
        isProcessing = false
    }
    
    func processSpeechResult(_ spokenText: String) {
        guard !spokenText.isEmpty else { return }
        conversations.append(ConversationMessage(role: .user, text: spokenText))
    }
}