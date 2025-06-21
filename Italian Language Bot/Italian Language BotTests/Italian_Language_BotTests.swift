//
//  Italian_Language_BotTests.swift
//  Italian Language BotTests
//
//  Created by Casey Stella on 6/19/25.
//

import Testing
import Speech

struct Italian_Language_BotTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testSupportedLocales() async throws {
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
        
        // Don't fail the test - this is just for information
        print("✅ Locale check completed")
    }

}
