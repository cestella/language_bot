import XCTest
import Foundation
@testable import Italian_Language_Bot

class HelperTests: XCTestCase {
    
    // MARK: - Basic Helper Tests
    
    func testDateFormatterBasicFunctionality() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let testDate = Date(timeIntervalSince1970: 1640995200) // January 1, 2022, 12:00:00 UTC
        
        let timeString1 = formatter.string(from: testDate)
        let timeString2 = formatter.string(from: testDate)
        
        XCTAssertEqual(timeString1, timeString2)
        XCTAssertFalse(timeString1.isEmpty)
    }
    
    func testDateFormatterHandlesDifferentTimes() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let morning = Date(timeIntervalSince1970: 1640995200) // 12:00 UTC
        let evening = Date(timeIntervalSince1970: 1641038400) // 12:00 next day UTC
        
        let morningString = formatter.string(from: morning)
        let eveningString = formatter.string(from: evening)
        
        XCTAssertNotEqual(morningString, eveningString)
    }
    
    func testTimeFormatterWithCurrentDate() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let now = Date()
        
        let timeString = formatter.string(from: now)
        
        XCTAssertFalse(timeString.isEmpty)
        // Should contain time indicators (AM/PM or 24-hour format)
        let hasTimeIndicators = timeString.contains(":") || 
                               timeString.contains("AM") || 
                               timeString.contains("PM")
        XCTAssertTrue(hasTimeIndicators)
    }
    
    // MARK: - ConversationMessage Tests
    
    func testConversationMessageCreation() {
        // Since ConversationMessage.Role has actor isolation requirements,
        // we test the logic by creating messages and checking expected behavior
        
        let systemMessage = ConversationMessage(role: .system, text: "System message")
        let userMessage = ConversationMessage(role: .user, text: "User message")
        let assistantMessage = ConversationMessage(role: .assistant, text: "Assistant message")
        let feedbackMessage = ConversationMessage(role: .feedback, text: "Feedback message")
        
        // Test message properties
        XCTAssertEqual(systemMessage.text, "System message")
        XCTAssertEqual(userMessage.text, "User message")
        XCTAssertEqual(assistantMessage.text, "Assistant message")
        XCTAssertEqual(feedbackMessage.text, "Feedback message")
        
        // Test that messages have IDs and timestamps
        XCTAssertNotNil(systemMessage.id)
        XCTAssertNotNil(systemMessage.timestamp)
    }
    
    // MARK: - Language Code Tests
    
    func testLanguageCodeGeneration() {
        let italian = Language.italian
        XCTAssertEqual(italian.code, "it-IT")
        
        // Test that code is consistent
        XCTAssertEqual(italian.code, Language.italian.code)
    }
    
    func testLanguageCodeFormatting() {
        let code = Language.italian.code
        
        // Should be in format "xx-XX"
        let components = code.split(separator: "-")
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].count, 2)
        XCTAssertEqual(components[1].count, 2)
        
        // Should be lowercase-uppercase
        XCTAssertEqual(String(components[0]), String(components[0]).lowercased())
        XCTAssertEqual(String(components[1]), String(components[1]).uppercased())
    }
    
    // MARK: - CEFR Level Validation Tests
    
    func testCEFRLevelOrdering() {
        let allLevels = CEFRLevel.allCases
        
        // Test that levels are in ascending difficulty order
        XCTAssertEqual(allLevels[0], .a1)
        XCTAssertEqual(allLevels[1], .a2)
        XCTAssertEqual(allLevels[2], .b1)
        XCTAssertEqual(allLevels[3], .b2)
        XCTAssertEqual(allLevels[4], .c1)
        XCTAssertEqual(allLevels[5], .c2)
    }
    
    func testCEFRLevelDescriptionConsistency() {
        for level in CEFRLevel.allCases {
            let description = level.description
            
            // Should contain the level code
            XCTAssertTrue(description.contains(level.rawValue))
            
            // Should contain a dash separator
            XCTAssertTrue(description.contains(" - "))
            
            // Should not be empty
            XCTAssertFalse(description.isEmpty)
        }
    }
    
    // MARK: - Scenario Category Helper Tests
    
    func testScenarioCategoryNameProperty() {
        let category = ScenarioCategory(category: "Test Category", scenarios: ["Test scenario"])
        
        // Name should be same as category
        XCTAssertEqual(category.name, category.category)
        
        // Test with different values
        let restaurant = ScenarioCategory(category: "Restaurant", scenarios: ["Order food"])
        XCTAssertEqual(restaurant.name, "Restaurant")
    }
    
    func testScenarioCategoryIDUniqueness() {
        let category1 = ScenarioCategory(category: "Same Name", scenarios: ["Scenario 1"])
        let category2 = ScenarioCategory(category: "Same Name", scenarios: ["Scenario 2"])
        
        // Even with same category name, IDs should be different
        XCTAssertNotEqual(category1.id, category2.id)
    }
    
    // MARK: - UUID Generation Tests
    
    func testUUIDUniqueness() {
        var uuids: Set<UUID> = []
        
        // Generate multiple UUIDs and ensure they're all unique
        for _ in 0..<100 {
            let message = ConversationMessage(role: .user, text: "Test")
            XCTAssertFalse(uuids.contains(message.id), "UUID should be unique")
            uuids.insert(message.id)
        }
        
        XCTAssertEqual(uuids.count, 100)
    }
    
    // MARK: - Text Validation Helpers
    
    func testEmptyStringValidation() {
        let emptyString = ""
        let whitespaceString = "   "
        let validString = "Hello"
        
        XCTAssertTrue(emptyString.isEmpty)
        XCTAssertFalse(whitespaceString.isEmpty)
        XCTAssertTrue(whitespaceString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(validString.isEmpty)
        XCTAssertFalse(validString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // MARK: - Performance Helper Tests
    
    func testMessageCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = ConversationMessage(role: .user, text: "Performance test message")
            }
        }
    }
    
    func testScenarioCategoryCreationPerformance() {
        let scenarios = Array(repeating: "Test scenario", count: 100)
        
        measure {
            for i in 0..<100 {
                _ = ScenarioCategory(category: "Category \(i)", scenarios: scenarios)
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMessageCreationAndDeallocation() {
        // Since ConversationMessage is a struct (value type), it doesn't have reference semantics
        // Instead, test that we can create and use many instances without issues
        var messages: [ConversationMessage] = []
        
        autoreleasepool {
            for i in 0..<1000 {
                let message = ConversationMessage(role: .user, text: "Test message \(i)")
                messages.append(message)
            }
            XCTAssertEqual(messages.count, 1000)
        }
        
        // Clear the array
        messages.removeAll()
        XCTAssertEqual(messages.count, 0)
    }
    
    func testScenarioCategoryCreationAndDeallocation() {
        // Since ScenarioCategory is a struct (value type), test large-scale creation
        var categories: [ScenarioCategory] = []
        
        autoreleasepool {
            for i in 0..<100 {
                let category = ScenarioCategory(category: "Test \(i)", scenarios: ["Test scenario \(i)"])
                categories.append(category)
            }
            XCTAssertEqual(categories.count, 100)
        }
        
        // Clear the array
        categories.removeAll()
        XCTAssertEqual(categories.count, 0)
    }
}