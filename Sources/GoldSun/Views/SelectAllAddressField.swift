import AppKit
import SwiftUI

struct SelectAllAddressField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = SelectAllNSTextField()
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.submit(_:))
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.lineBreakMode = .byTruncatingMiddle
        textField.cell?.usesSingleLineMode = true
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.parent = self
        textField.placeholderString = placeholder

        if textField.stringValue != text {
            textField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SelectAllAddressField

        init(parent: SelectAllAddressField) {
            self.parent = parent
        }

        @objc func submit(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit()
            sender.window?.makeFirstResponder(nil)
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
            selectAll(in: notification)
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            parent.text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false

            guard let textField = notification.object as? NSTextField else {
                return
            }

            parent.text = textField.stringValue
        }

        private func selectAll(in notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            DispatchQueue.main.async {
                textField.currentEditor()?.selectAll(nil)
            }
        }
    }
}

private final class SelectAllNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let becameFirstResponder = super.becomeFirstResponder()

        if becameFirstResponder {
            DispatchQueue.main.async { [weak self] in
                self?.currentEditor()?.selectAll(nil)
            }
        }

        return becameFirstResponder
    }
}
