import XCTest
@testable import Agentboard

final class MarkdownParserTests: XCTestCase {

    // MARK: - Headers

    func testHeader1() {
        let result = MarkdownParser.parse("# Hello World")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .header(level: 1, [.text("Hello World")]))
    }

    func testHeader2() {
        let result = MarkdownParser.parse("## Section Title")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .header(level: 2, [.text("Section Title")]))
    }

    func testHeader6() {
        let result = MarkdownParser.parse("###### Smallest Header")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .header(level: 6, [.text("Smallest Header")]))
    }

    func testHeaderWithInlineFormatting() {
        let result = MarkdownParser.parse("# Hello **World**")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .header(level: 1, [.text("Hello "), .bold("World")]))
    }

    // MARK: - Code Blocks

    func testCodeBlockWithLanguage() {
        let input = """
        ```swift
        let x = 42
        print(x)
        ```
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .codeBlock(let lang, let code) = result[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertTrue(code.contains("let x = 42"))
            XCTAssertTrue(code.contains("print(x)"))
        } else {
            XCTFail("Expected code block")
        }
    }

    func testCodeBlockWithoutLanguage() {
        let input = """
        ```
        some code
        ```
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .codeBlock(let lang, let code) = result[0] {
            XCTAssertNil(lang)
            XCTAssertTrue(code.contains("some code"))
        } else {
            XCTFail("Expected code block")
        }
    }

    // MARK: - Tables

    func testSimpleTable() {
        let input = """
        | Name | Age |
        |------|-----|
        | Alice | 30 |
        | Bob | 25 |
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .table(let headers, let rows) = result[0] {
            XCTAssertEqual(headers, ["Name", "Age"])
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0], ["Alice", "30"])
            XCTAssertEqual(rows[1], ["Bob", "25"])
        } else {
            XCTFail("Expected table block")
        }
    }

    // MARK: - Bullet Lists

    func testBulletList() {
        let input = """
        - First item
        - Second item
        - Third item
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .bulletList(let items) = result[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(items[0], [.text("First item")])
            XCTAssertEqual(items[1], [.text("Second item")])
            XCTAssertEqual(items[2], [.text("Third item")])
        } else {
            XCTFail("Expected bullet list")
        }
    }

    func testBulletListWithFormatting() {
        let input = """
        - **Bold** item
        - Item with `code`
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .bulletList(let items) = result[0] {
            XCTAssertEqual(items.count, 2)
            XCTAssertEqual(items[0], [.bold("Bold"), .text(" item")])
            XCTAssertEqual(items[1], [.text("Item with "), .code("code")])
        } else {
            XCTFail("Expected bullet list")
        }
    }

    // MARK: - Numbered Lists

    func testNumberedList() {
        let input = """
        1. First
        2. Second
        3. Third
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .numberedList(let items) = result[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(items[0], [.text("First")])
            XCTAssertEqual(items[1], [.text("Second")])
            XCTAssertEqual(items[2], [.text("Third")])
        } else {
            XCTFail("Expected numbered list")
        }
    }

    // MARK: - Horizontal Rule

    func testHorizontalRule() {
        let result = MarkdownParser.parse("---")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .horizontalRule)
    }

    func testHorizontalRuleWithAsterisks() {
        let result = MarkdownParser.parse("***")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .horizontalRule)
    }

    // MARK: - Inline Spans

    func testBoldText() {
        let spans = MarkdownSpanParser.parse("Hello **world**")
        XCTAssertEqual(spans, [.text("Hello "), .bold("world")])
    }

    func testItalicText() {
        let spans = MarkdownSpanParser.parse("Hello *world*")
        XCTAssertEqual(spans, [.text("Hello "), .italic("world")])
    }

    func testBoldItalicText() {
        let spans = MarkdownSpanParser.parse("Hello ***world***")
        XCTAssertEqual(spans, [.text("Hello "), .boldItalic("world")])
    }

    func testInlineCode() {
        let spans = MarkdownSpanParser.parse("Use `print()` here")
        XCTAssertEqual(spans, [.text("Use "), .code("print()"), .text(" here")])
    }

    func testLink() {
        let spans = MarkdownSpanParser.parse("Visit [Google](https://google.com) now")
        XCTAssertEqual(spans, [
            .text("Visit "),
            .link(text: "Google", url: "https://google.com"),
            .text(" now")
        ])
    }

    // MARK: - Mixed Content

    func testMixedParagraph() {
        let input = "This has **bold**, *italic*, and `code` inline."
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 1)
        if case .paragraph(let spans) = result[0] {
            XCTAssertEqual(spans, [
                .text("This has "),
                .bold("bold"),
                .text(", "),
                .italic("italic"),
                .text(", and "),
                .code("code"),
                .text(" inline.")
            ])
        } else {
            XCTFail("Expected paragraph")
        }
    }

    func testMultipleBlocks() {
        let input = """
        # Title

        Some paragraph text.

        - Item one
        - Item two
        """
        let result = MarkdownParser.parse(input)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], .header(level: 1, [.text("Title")]))
        if case .paragraph(let spans) = result[1] {
            XCTAssertEqual(spans, [.text("Some paragraph text.")])
        } else {
            XCTFail("Expected paragraph")
        }
        if case .bulletList(let items) = result[2] {
            XCTAssertEqual(items.count, 2)
        } else {
            XCTFail("Expected bullet list")
        }
    }

    func testPlainText() {
        let result = MarkdownParser.parse("Just some plain text")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], .paragraph([.text("Just some plain text")]))
    }
}
