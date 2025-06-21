import XCTest
import Foundation
import Combine
@testable import Italian_Language_Bot

class JSONLoadingTests: XCTestCase {
    
    var testBundle: Bundle!
    
    override func setUp() {
        super.setUp()
        testBundle = Bundle(for: type(of: self))
    }
    
    override func tearDown() {
        testBundle = nil
        super.tearDown()
    }
    
    // MARK: - Bundle Resource Loading Tests
    
    func testScenariosJSONExistsInMainBundle() {
        let path = Bundle.main.path(forResource: "scenarios", ofType: "json")
        XCTAssertNotNil(path, "scenarios.json should exist in main bundle")
    }
    
    func testScenariosJSONCanBeLoaded() {
        guard let path = Bundle.main.path(forResource: "scenarios", ofType: "json") else {
            XCTFail("scenarios.json not found in main bundle")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        XCTAssertNoThrow(try Data(contentsOf: url), "Should be able to load scenarios.json as Data")
    }
    
    func testScenariosJSONValidFormat() throws {
        guard let path = Bundle.main.path(forResource: "scenarios", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            XCTFail("Could not load scenarios.json")
            return
        }
        
        let decoder = JSONDecoder()
        XCTAssertNoThrow(try decoder.decode(ScenariosData.self, from: data), 
                        "scenarios.json should be valid ScenariosData format")
    }
    
    func testScenariosJSONStructure() throws {
        guard let path = Bundle.main.path(forResource: "scenarios", ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            XCTFail("Could not load scenarios.json")
            return
        }
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: data)
        
        XCTAssertGreaterThan(scenariosData.scenarios.count, 0, "Should have at least one scenario category")
        
        for category in scenariosData.scenarios {
            XCTAssertFalse(category.category.isEmpty, "Category name should not be empty")
            XCTAssertGreaterThan(category.scenarios.count, 0, "Each category should have at least one scenario")
            
            for scenario in category.scenarios {
                XCTAssertFalse(scenario.isEmpty, "Scenario description should not be empty")
            }
        }
    }
    
    // MARK: - JSON Parsing Tests with Mock Data
    
    func testValidJSONParsing() throws {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant",
                    "scenarios": [
                        "Order dinner at a restaurant",
                        "Ask about wine recommendations"
                    ]
                },
                {
                    "category": "Travel",
                    "scenarios": [
                        "Book a hotel room",
                        "Ask for directions"
                    ]
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
    
    func testEmptyScenariosArrayParsing() throws {
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
    
    func testMalformedJSONThrowsError() {
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
    
    func testMissingRequiredFieldThrowsError() {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant"
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ScenariosData.self, from: jsonData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testInvalidJSONSyntaxThrowsError() {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant"
                    "scenarios": ["Order food"]
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(ScenariosData.self, from: jsonData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyStringInScenariosArray() throws {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant",
                    "scenarios": ["Order food", "", "Ask about wine"]
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: jsonData)
        
        XCTAssertEqual(scenariosData.scenarios[0].scenarios.count, 3)
        XCTAssertEqual(scenariosData.scenarios[0].scenarios[1], "")
    }
    
    func testUnicodeCharactersInJSON() throws {
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Ristorante",
                    "scenarios": ["Ordinare la pasta", "Chiedere il vino 🍷"]
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: jsonData)
        
        XCTAssertEqual(scenariosData.scenarios[0].category, "Ristorante")
        XCTAssertTrue(scenariosData.scenarios[0].scenarios[1].contains("🍷"))
    }
    
    func testVeryLongScenarioStrings() throws {
        let longScenario = String(repeating: "This is a very long scenario description. ", count: 100)
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Test",
                    "scenarios": ["\(longScenario)"]
                }
            ]
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let scenariosData = try decoder.decode(ScenariosData.self, from: jsonData)
        
        XCTAssertEqual(scenariosData.scenarios[0].scenarios[0], longScenario)
    }
    
    // MARK: - JSON Loading Performance Tests
    
    func testJSONLoadingPerformance() {
        guard let path = Bundle.main.path(forResource: "scenarios", ofType: "json") else {
            XCTFail("scenarios.json not found")
            return
        }
        
        measure {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let decoder = JSONDecoder()
                _ = try decoder.decode(ScenariosData.self, from: data)
            } catch {
                XCTFail("JSON loading failed: \(error)")
            }
        }
    }
}

// MARK: - Mock JSON Loading Tests

@MainActor
class MockJSONLoadingTests: XCTestCase {
    
    func testViewModelWithValidJSON() async {
        let viewModel = MockableLanguageLearningViewModel()
        
        let jsonString = """
        {
            "scenarios": [
                {
                    "category": "Restaurant",
                    "scenarios": ["Order food", "Ask about wine"]
                }
            ]
        }
        """
        
        await viewModel.loadScenariosFromString(jsonString)
        
        XCTAssertEqual(viewModel.scenarioCategories.count, 1)
        XCTAssertEqual(viewModel.scenarioCategories[0].category, "Restaurant")
        XCTAssertEqual(viewModel.scenarioCategories[0].scenarios.count, 2)
    }
    
    func testViewModelWithInvalidJSON() async {
        let viewModel = MockableLanguageLearningViewModel()
        
        let invalidJSON = "{ invalid json }"
        
        await viewModel.loadScenariosFromString(invalidJSON)
        
        // Should fall back to default scenarios
        XCTAssertGreaterThan(viewModel.scenarioCategories.count, 0)
        XCTAssertTrue(viewModel.lastLoadFailed)
    }
    
    func testViewModelWithEmptyJSON() async {
        let viewModel = MockableLanguageLearningViewModel()
        
        let emptyJSON = """
        {
            "scenarios": []
        }
        """
        
        await viewModel.loadScenariosFromString(emptyJSON)
        
        XCTAssertEqual(viewModel.scenarioCategories.count, 0)
        XCTAssertFalse(viewModel.lastLoadFailed)
    }
}

// MARK: - Mockable ViewModel for Testing

@MainActor
class MockableLanguageLearningViewModel: ObservableObject {
    @Published var scenarioCategories: [ScenarioCategory] = []
    var lastLoadFailed = false
    
    func loadScenariosFromString(_ jsonString: String) async {
        guard let data = jsonString.data(using: .utf8) else {
            loadFallbackScenarios()
            lastLoadFailed = true
            return
        }
        
        do {
            let scenariosData = try JSONDecoder().decode(ScenariosData.self, from: data)
            self.scenarioCategories = scenariosData.scenarios
            lastLoadFailed = false
        } catch {
            loadFallbackScenarios()
            lastLoadFailed = true
        }
    }
    
    private func loadFallbackScenarios() {
        scenarioCategories = [
            ScenarioCategory(category: "Meeting on the Street", scenarios: [
                "Two good friends meet in a park"
            ]),
            ScenarioCategory(category: "Ordering Food", scenarios: [
                "A customer enters a restaurant"
            ])
        ]
    }
}