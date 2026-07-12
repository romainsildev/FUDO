import SwiftUI

/// Two-step destructive confirmation (abandon challenge, delete data): a first alert
/// then a second "are you sure" gate. Simple alert (uncheck) is a normal `.alert`.
private struct DestructiveConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    @State private var secondStep = false

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("Continue", role: .destructive) { secondStep = true }
                Button("Cancel", role: .cancel) {}
            } message: { Text(message) }
            .alert("Are you sure?", isPresented: $secondStep) {
                Button(confirmTitle, role: .destructive) { onConfirm() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This can't be undone.") }
    }
}

extension View {
    func fudoDestructiveConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DestructiveConfirmModifier(
            isPresented: isPresented, title: title, message: message,
            confirmTitle: confirmTitle, onConfirm: onConfirm
        ))
    }

    func fudoSimpleAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button(confirmTitle, role: .destructive) { onConfirm() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(message) }
    }
}
