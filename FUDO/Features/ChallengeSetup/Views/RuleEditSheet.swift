import SwiftUI

/// Medium sheet for editing an existing rule or composing a custom one.
/// Time rules (`.time`) get a wheel picker that rewrites the title through the
/// view model — value baked into the string, no schema change.
struct RuleEditSheet: View {
    /// nil = create a new custom rule.
    let rule: EditableRule?
    let viewModel: ChallengeSetupViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var iconName: String
    @State private var wakeTime: Date

    private var isTimeRule: Bool { rule?.valueKind == .time }

    init(rule: EditableRule?, viewModel: ChallengeSetupViewModel) {
        self.rule = rule
        self.viewModel = viewModel
        _title = State(initialValue: rule?.title ?? "")
        _iconName = State(initialValue: rule?.iconName ?? RuleIconCatalog.defaultSymbol)
        let minutes = rule?.timeMinutes ?? PresetCatalog.defaultWakeMinutes
        let base = Calendar.current.startOfDay(for: .now)
        _wakeTime = State(initialValue: base.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header

            if isTimeRule {
                timePicker
            } else {
                titleField
                iconGrid
            }

            Spacer(minLength: 0)

            saveButton
        }
        .padding(FudoSpacing.screenMargin)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text(rule == nil ? "New rule" : "Edit rule")
                .fudoFont(.title(20))
                .foregroundStyle(FudoColor.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .fudoFont(.glyph(14, weight: .semibold))
                    .foregroundStyle(FudoColor.textSecondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var titleField: some View {
        TextField("Rule name", text: $title)
            .fudoFont(.body())
            .foregroundStyle(FudoColor.textPrimary)
            .tint(FudoColor.accent)
            .padding(.horizontal, FudoSpacing.cardPadding)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .fill(FudoColor.bgCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FudoSpacing.radiusCard, style: .continuous)
                    .strokeBorder(FudoColor.border, lineWidth: 1)
            }
            .submitLabel(.done)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
                  spacing: 10) {
            ForEach(RuleIconCatalog.symbols, id: \.self) { symbol in
                Button {
                    Haptics.light()
                    iconName = symbol
                } label: {
                    Image(systemName: symbol)
                        .fudoFont(.glyph(16, weight: .medium))
                        .foregroundStyle(FudoColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                                .fill(symbol == iconName ? FudoColor.accentDeep : FudoColor.bgCard)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: FudoSpacing.radiusNested, style: .continuous)
                                .strokeBorder(symbol == iconName ? FudoColor.accent : FudoColor.border,
                                              lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up before")
                .fudoFont(.caption())
                .foregroundStyle(FudoColor.textSecondary)
            DatePicker("", selection: $wakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save")
                .fudoFont(.headline())
                .foregroundStyle(FudoColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: FudoSpacing.ctaHeight)
                .background { Capsule().fill(canSave ? FudoColor.accent : FudoColor.bgCard) }
                .overlay { Capsule().strokeBorder(canSave ? Color.clear : FudoColor.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        isTimeRule || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        Haptics.medium()
        if let rule {
            if isTimeRule {
                let components = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
                viewModel.setWakeTime(id: rule.id,
                                      minutes: (components.hour ?? 7) * 60 + (components.minute ?? 0))
            } else {
                viewModel.updateRule(id: rule.id, title: title, iconName: iconName)
            }
        } else {
            viewModel.addRule(title: title, iconName: iconName)
        }
        dismiss()
    }
}
