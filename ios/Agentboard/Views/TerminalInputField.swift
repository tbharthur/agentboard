// Agentboard/Views/TerminalInputField.swift
import SwiftUI
import UIKit

struct TerminalInputFieldRepresentable: UIViewRepresentable {
    @Binding var isFocused: Bool
    var onTextInput: (String) -> Void
    var onSpecialKey: (SpecialKey) -> Void

    func makeUIView(context: Context) -> TerminalInputField {
        let field = TerminalInputField()
        field.onTextInput = onTextInput
        field.onSpecialKey = onSpecialKey
        field.delegate = context.coordinator
        return field
    }

    func updateUIView(_ uiView: TerminalInputField, context: Context) {
        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TerminalInputFieldRepresentable

        init(_ parent: TerminalInputFieldRepresentable) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.isFocused = true
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.parent.isFocused = false
            }
        }
    }
}

enum SpecialKey {
    case backspace
    case enter
    case tab
    case escape
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
}

class TerminalInputField: UITextField {
    var onTextInput: ((String) -> Void)?
    var onSpecialKey: ((SpecialKey) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Disable all auto-correction features for terminal input
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no

        // Make invisible
        backgroundColor = .clear
        textColor = .clear
        tintColor = .clear

        // Handle text changes
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }

    @objc private func textDidChange() {
        // Forward any text to terminal and clear field
        if let text = self.text, !text.isEmpty {
            onTextInput?(text)
            self.text = ""
        }
    }

    override func deleteBackward() {
        // Send backspace to terminal
        onTextInput?("\u{7F}") // DEL character
    }

    // Handle special keys via key commands
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleEnter)),
            UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTab)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(handleEscape)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(handleArrowUp)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(handleArrowDown)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(handleArrowLeft)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(handleArrowRight)),
        ]
    }

    @objc private func handleEnter() {
        onTextInput?("\r")
    }

    @objc private func handleTab() {
        onTextInput?("\t")
    }

    @objc private func handleEscape() {
        onTextInput?("\u{1B}")
    }

    @objc private func handleArrowUp() {
        onTextInput?("\u{1B}[A")
    }

    @objc private func handleArrowDown() {
        onTextInput?("\u{1B}[B")
    }

    @objc private func handleArrowRight() {
        onTextInput?("\u{1B}[C")
    }

    @objc private func handleArrowLeft() {
        onTextInput?("\u{1B}[D")
    }
}
