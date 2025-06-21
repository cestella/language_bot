import XCTest
import Foundation
@testable import Italian_Language_Bot

class DataModelTests: XCTestCase {
    
    // MARK: - Language Enum Tests
    
    func testLanguageRawValue() {
        XCTAssertEqual(Language.italian.rawValue, "Italian")
    }
    
    func testLanguageCode() {
        XCTAssertEqual(Language.italian.code, "it-IT")
    }
    
    func testLanguageID() {
        XCTAssertEqual(Language.italian.id, "Italian")
    }
    
    func testLanguageAllCases() {
        let allCases = Language.allCases
        XCTAssertEqual(allCases.count, 1)
        XCTAssertTrue(allCases.contains(.italian))
    }
    
    // MARK: - CEFRLevel Enum Tests
    
    func testCEFRLevelRawValues() {
        XCTAssertEqual(CEFRLevel.a1.rawValue, "A1")
        XCTAssertEqual(CEFRLevel.a2.rawValue, "A2")
        XCTAssertEqual(CEFRLevel.b1.rawValue, "B1")
        XCTAssertEqual(CEFRLevel.b2.rawValue, "B2")
        XCTAssertEqual(CEFRLevel.c1.rawValue, "C1")
        XCTAssertEqual(CEFRLevel.c2.rawValue, "C2")
    }
    
    func testCEFRLevelDescriptions() {
        XCTAssertEqual(CEFRLevel.a1.description, "A1 - Beginner")
        XCTAssertEqual(CEFRLevel.a2.description, "A2 - Elementary")
        XCTAssertEqual(CEFRLevel.b1.description, "B1 - Intermediate")
        XCTAssertEqual(CEFRLevel.b2.description, "B2 - Upper Intermediate")
        XCTAssertEqual(CEFRLevel.c1.description, "C1 - Advanced")
        XCTAssertEqual(CEFRLevel.c2.description, "C2 - Proficient")
    }
    
    func testCEFRLevelIDs() {
        XCTAssertEqual(CEFRLevel.a1.id, "A1")
        XCTAssertEqual(CEFRLevel.b2.id, "B2")
        XCTAssertEqual(CEFRLevel.c2.id, "C2")
    }
    
    func testCEFRLevelAllCases() {
        let allCases = CEFRLevel.allCases
        XCTAssertEqual(allCases.count, 6)
        
        let expectedOrder: [CEFRLevel] = [.a1, .a2, .b1, .b2, .c1, .c2]
        XCTAssertEqual(allCases, expectedOrder)
    }
    
    // MARK: - ScenarioCategory Model Tests
    
    func testScenarioCategoryInit() {
        let scenarios = ["Scenario 1", "Scenario 2", "Scenario 3"]
        let category = ScenarioCategory(category: "Test Category", scenarios: scenarios)
        
        XCTAssertEqual(category.category, "Test Category")
        XCTAssertEqual(category.name, "Test Category")
        XCTAssertEqual(category.scenarios, scenarios)
        XCTAssertNotNil(category.id)
    }
    
    func testScenarioCategoryNameProperty() {
        let category = ScenarioCategory(category: "Restaurant", scenarios: ["Order food"])
        XCTAssertEqual(category.name, category.category)
    }
    
    func testScenarioCategoryJSONEncoding() throws {
        let scenarios = ["Order pasta", "Ask for wine recommendations"]
        let category = ScenarioCategory(category: "Restaurant", scenarios: scenarios)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(category)
        
        // Verify we can decode it back
        let decoder = JSONDecoder()
        let decodedCategory = try decoder.decode(ScenarioCategory.self, from: data)
        
        XCTAssertEqual(decodedCategory.category, "Restaurant")
        XCTAssertEqual(decodedCategory.scenarios, scenarios)
    }
    
    func testScenarioCategoryJSONDecoding() throws {
        let jsonString = """
        {
            "category": "Travel",
            "scenarios": ["Book hotel", "Ask directions", "Buy tickets"]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let category = try decoder.decode(ScenarioCategory.self, from: jsonData)
        
        XCTAssertEqual(category.category, "Travel")
        XCTAssertEqual(category.scenarios.count, 3)
        XCTAssertEqual(category.scenarios[0], "Book hotel")
        XCTAssertEqual(category.scenarios[1], "Ask directions")
        XCTAssertEqual(category.scenarios[2], "Buy tickets")
    }
    
    func testScenarioCategoryJSONDecodingMissingField() {
        let jsonString = """
        {
            "category": "Travel"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ScenarioCategory.self, from: jsonData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testScenarioCategoryJSONDecodingInvalidJSON() {
        let jsonString = """
        {
            "category": "Travel",
            "scenarios": "not an array"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ScenarioCategory.self, from: jsonData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - ScenariosData Model Tests
    
    func testScenariosDataDecoding() throws {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant",
                    "scenarios": ["Order food", "Ask about wine"]
                },
                {
                    "category": "Travel",
                    "scenarios": ["Book hotel", "Get directions"]
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: jsonData)
        
        XCTAssertEqual(scenariosData.scenarios.count, 2)
        XCTAssertEqual(scenariosData.scenarios[0].category, "Restaurant")
        XCTAssertEqual(scenariosData.scenarios[1].category, "Travel")
        XCTAssertEqual(scenariosData.scenarios[0].scenarios.count, 2)
        XCTAssertEqual(scenariosData.scenarios[1].scenarios.count, 2)
    }
    
    func testScenariosDataDecodingEmptyArray() throws {
        let jsonString = """
        {
            "scenarios": []
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: jsonData)
        
        XCTAssertEqual(scenariosData.scenarios.count, 0)
    }
    
    func testScenariosDataDecodingMalformedJSON() {
        let jsonString = """
        {
            "scenarios": "not an array"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ScenariosData.self, from: jsonData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - ConversationMessage Model Tests
    
    func testConversationMessageInit() {
        let message = ConversationMessage(role: .user, text: "Hello, how are you?")
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.text, "Hello, how are you?")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
        
        // Timestamp should be recent (within last second)
        let now = Date()
        XCTAssertLessThan(now.timeIntervalSince(message.timestamp), 1.0)
    }
    
    func testConversationMessageRoles() {
        let systemMessage = ConversationMessage(role: .system, text: "System message")
        let userMessage = ConversationMessage(role: .user, text: "User message")
        let assistantMessage = ConversationMessage(role: .assistant, text: "Assistant message")
        let feedbackMessage = ConversationMessage(role: .feedback, text: "Feedback message")
        
        XCTAssertEqual(systemMessage.role, .system)
        XCTAssertEqual(userMessage.role, .user)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(feedbackMessage.role, .feedback)
    }
    
    func testConversationMessageIDUniqueness() {
        let message1 = ConversationMessage(role: .user, text: "Message 1")
        let message2 = ConversationMessage(role: .user, text: "Message 2")
        
        XCTAssertNotEqual(message1.id, message2.id)
    }
    
    func testConversationMessageTimestampProgression() {
        let message1 = ConversationMessage(role: .user, text: "First message")
        
        // Small delay to ensure different timestamps
        usleep(1000) // 1ms delay
        
        let message2 = ConversationMessage(role: .user, text: "Second message")
        
        XCTAssertLessThan(message1.timestamp, message2.timestamp)
    }
}