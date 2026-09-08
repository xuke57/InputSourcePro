import Carbon
import XCTest
@testable import Input_Source_Pro

final class MarkdownPunctuationMappingTests: XCTestCase {
    private typealias InputContext = MarkdownPunctuationMapping.InputContext

    private let pinyin = InputContext(
        sourceID: "com.apple.inputmethod.SCIM.ITABC",
        inputModeID: "com.apple.inputmethod.SCIM.ITABC",
        keyboardLayoutID: "com.apple.keylayout.PinyinKeyboard"
    )

    private let mappedKeys: [(keyCode: CGKeyCode, flags: CGEventFlags, replacement: String)] = [
        (CGKeyCode(kVK_ANSI_Grave), [], "`"),
        (CGKeyCode(kVK_ANSI_4), .maskShift, "$"),
        (CGKeyCode(kVK_ANSI_Comma), .maskShift, "《》"),
        (CGKeyCode(kVK_ANSI_Period), .maskShift, ">"),
        (CGKeyCode(kVK_ANSI_LeftBracket), [], "["),
        (CGKeyCode(kVK_ANSI_RightBracket), [], "]")
    ]

    func testMapsOnlySpecifiedKeysOnSupportedPinyinLayouts() {
        for layoutID in ["com.apple.keylayout.PinyinKeyboard", "com.apple.keylayout.ABC", "com.apple.keylayout.US"] {
            let context = InputContext(
                sourceID: pinyin.sourceID,
                inputModeID: pinyin.inputModeID,
                keyboardLayoutID: layoutID
            )

            for key in mappedKeys {
                XCTAssertEqual(
                    MarkdownPunctuationMapping.replacement(for: key.keyCode, flags: key.flags) { context },
                    key.replacement,
                    "Layout: \(layoutID), key: \(key.keyCode)"
                )
            }
        }
    }

    func testRussianLettersPassThrough() {
        for sourceID in ["com.apple.keylayout.Russian", "com.apple.keylayout.RussianWin"] {
            let context = InputContext(sourceID: sourceID, inputModeID: nil, keyboardLayoutID: sourceID)
            for key in mappedKeys {
                XCTAssertNil(MarkdownPunctuationMapping.replacement(for: key.keyCode, flags: key.flags) { context })
            }
        }
    }

    func testLatinSourcesPassThroughEvenOnSupportedLayouts() {
        for sourceID in ["com.apple.keylayout.ABC", "com.apple.keylayout.US"] {
            let context = InputContext(sourceID: sourceID, inputModeID: nil, keyboardLayoutID: sourceID)
            for key in mappedKeys {
                XCTAssertNil(MarkdownPunctuationMapping.replacement(for: key.keyCode, flags: key.flags) { context })
            }
        }
    }

    func testRequiresBothTheVerifiedSourceAndMode() {
        let contexts = [
            InputContext(sourceID: pinyin.sourceID, inputModeID: nil, keyboardLayoutID: pinyin.keyboardLayoutID),
            InputContext(sourceID: pinyin.sourceID, inputModeID: "unknown", keyboardLayoutID: pinyin.keyboardLayoutID),
            InputContext(sourceID: "unknown", inputModeID: pinyin.inputModeID, keyboardLayoutID: pinyin.keyboardLayoutID),
            InputContext(
                sourceID: "com.apple.inputmethod.TCIM.Pinyin",
                inputModeID: "com.apple.inputmethod.TCIM.Pinyin",
                keyboardLayoutID: pinyin.keyboardLayoutID
            )
        ]

        for context in contexts {
            XCTAssertNil(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift) { context })
        }
    }

    func testUnsupportedUnderlyingLayoutsPassThrough() {
        for layoutID in ["com.apple.keylayout.Russian", "com.apple.keylayout.French", "custom.layout", ""] {
            let context = InputContext(
                sourceID: pinyin.sourceID,
                inputModeID: pinyin.inputModeID,
                keyboardLayoutID: layoutID
            )
            XCTAssertNil(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift) { context })
        }
    }

    func testSourceChangesTakeEffectOnTheNextKeyInBothDirections() {
        let latin = InputContext(sourceID: "com.apple.keylayout.ABC", inputModeID: nil, keyboardLayoutID: "com.apple.keylayout.ABC")
        var context = pinyin
        var contextReads = 0
        let provider = {
            contextReads += 1
            return context
        }

        XCTAssertEqual(
            MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift, contextProvider: provider),
            "《》"
        )
        context = latin
        XCTAssertNil(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift, contextProvider: provider))
        context = pinyin
        XCTAssertEqual(
            MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift, contextProvider: provider),
            "《》"
        )
        XCTAssertEqual(contextReads, 3)
    }

    func testUnderlyingLayoutChangesTakeEffectOnTheNextKey() {
        var context = pinyin
        XCTAssertEqual(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift) { context }, "《》")

        context = InputContext(sourceID: pinyin.sourceID, inputModeID: pinyin.inputModeID, keyboardLayoutID: "custom.layout")
        XCTAssertNil(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift) { context })
    }

    func testOtherPunctuationAndShiftVariantsPassThroughWithoutReadingTheInputSource() {
        let keys: [(CGKeyCode, CGEventFlags)] = [
            (CGKeyCode(kVK_ANSI_Comma), []),
            (CGKeyCode(kVK_ANSI_Period), []),
            (CGKeyCode(kVK_ANSI_4), []),
            (CGKeyCode(kVK_ANSI_Grave), .maskShift),
            (CGKeyCode(kVK_ANSI_LeftBracket), .maskShift),
            (CGKeyCode(kVK_ANSI_RightBracket), .maskShift),
            (CGKeyCode(kVK_ANSI_Quote), []),
            (CGKeyCode(kVK_ANSI_Quote), .maskShift),
            (CGKeyCode(kVK_ANSI_Semicolon), []),
            (CGKeyCode(kVK_ANSI_A), [])
        ]

        for (keyCode, flags) in keys {
            XCTAssertNil(MarkdownPunctuationMapping.replacement(for: keyCode, flags: flags) {
                XCTFail("Unmapped key must not query the input source")
                return self.pinyin
            })
        }
    }

    func testShortcutsAndCapsLockPassThroughWithoutReadingTheInputSource() {
        let modifiers: [CGEventFlags] = [.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn, .maskAlphaShift]
        for modifier in modifiers {
            for key in mappedKeys {
                XCTAssertNil(MarkdownPunctuationMapping.replacement(for: key.keyCode, flags: key.flags.union(modifier)) {
                    XCTFail("Modified key must not query the input source")
                    return self.pinyin
                })
            }
        }
    }

    func testUnavailableInputContextPassesThrough() {
        XCTAssertNil(MarkdownPunctuationMapping.replacement(for: CGKeyCode(kVK_ANSI_Comma), flags: .maskShift) { nil })
    }
}
