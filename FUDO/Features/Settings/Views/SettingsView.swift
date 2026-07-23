import SwiftUI

/// Thin environment reader → hands the store to `SettingsScreen`, which needs it
/// at init to build its view model (same shim pattern as the Home tab). AppState
/// and openURL are read from the environment inside the screen.
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(EntitlementStore.self) private var entitlements: EntitlementStore?

    var body: some View {
        SettingsScreen(store: store, entitlements: entitlements)
    }
}

/// The real Settings tab (PRD 09). Native inset-grouped list, dark by design —
/// functional, not rich. Sections: challenge · notifications · subscription ·
/// legal & support · data, plus the DEBUG menu in DEBUG builds.
struct SettingsScreen: View {
    private let store: GameStore
    @State private var viewModel: SettingsViewModel

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var safariLink: SafariLink?

    // Two-step destructive confirmations (friction is the point).
    @State private var showAbandonSheet = false
    @State private var showAbandonAlert = false
    @State private var showEraseSheet = false
    @State private var showEraseAlert = false

    init(store: GameStore, entitlements: EntitlementStore? = nil) {
        self.store = store
        _viewModel = State(initialValue: SettingsViewModel(store: store, entitlements: entitlements))
    }

    private enum Route: Hashable { case editRules }

    // Legal URLs live in AppConfig (single source — the paywall footer links the
    // same ones). Only the app-specific rows keep local constants.
    private static let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    private static let contactURL = URL(string: "mailto:thepixelwar.contact@gmail.com")!

    var body: some View {
        List {
            if viewModel.hasActiveChallenge {
                challengeSection
            }
            notificationsSection
            subscriptionSection
            legalSection
            dataSection

            #if DEBUG
            Section {
                DebugMenuSection()
                    .listRowBackground(FudoColor.bgPrimary)
                    .listRowInsets(EdgeInsets(top: 12, leading: FudoSpacing.screenMargin,
                                              bottom: 12, trailing: FudoSpacing.screenMargin))
            } header: {
                sectionHeader("DEBUG")
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(FudoColor.bgPrimary.ignoresSafeArea())
        .navigationTitle("Settings")
        .toolbarBackground(FudoColor.bgPrimary, for: .navigationBar)
        .tint(FudoColor.accent)
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .editRules: EditRulesView(store: store)
            }
        }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .alert("Restore purchases", isPresented: restoreAlertBinding) {
            Button("OK") { viewModel.restoreMessage = nil }
        } message: {
            Text(viewModel.restoreMessage ?? "")
        }
    }

    // MARK: - §CHALLENGE

    @ViewBuilder
    private var challengeSection: some View {
        Section {
            if viewModel.canEditRules {
                NavigationLink(value: Route.editRules) {
                    rowLabel("Edit rules", systemImage: "slider.horizontal.3")
                }
                .listRowBackground(FudoColor.bgCard)
            }

            DatePicker(selection: reminderTimeBinding, displayedComponents: .hourAndMinute) {
                rowLabel("Reminder time", systemImage: "bell.badge")
            }
            .listRowBackground(FudoColor.bgCard)

            Button(role: .destructive) {
                showAbandonSheet = true
            } label: {
                Text("Abandon challenge")
                    .fudoFont(.body())
                    .foregroundStyle(FudoColor.negative)
            }
            .listRowBackground(FudoColor.bgCard)
        } header: {
            sectionHeader("Challenge")
        } footer: {
            sectionFooter(viewModel.challengeSummary ?? "")
        }
        .confirmationDialog("Abandon this challenge?", isPresented: $showAbandonSheet,
                            titleVisibility: .visible) {
            Button("Abandon", role: .destructive) { showAbandonAlert = true }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your progress so far stays, but the run ends here.")
        }
        .alert("This can't be undone", isPresented: $showAbandonAlert) {
            Button("Abandon", role: .destructive) { viewModel.abandonChallenge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your OVR takes the day's penalty and your streak breaks.")
        }
    }

    // MARK: - §NOTIFICATIONS

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            ForEach(NotificationPreferences.Category.allCases) { category in
                Toggle(isOn: toggleBinding(category)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .fudoFont(.body())
                            .foregroundStyle(FudoColor.textPrimary)
                        Text(category.subtitle)
                            .fudoFont(.caption())
                            .foregroundStyle(FudoColor.textSecondary)
                    }
                }
                .tint(FudoColor.accent)
                .listRowBackground(FudoColor.bgCard)
            }
        } header: {
            sectionHeader("Notifications")
        } footer: {
            sectionFooter("FUDO sends at most 2 notifications a day.")
        }
    }

    // MARK: - §SUBSCRIPTION

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            Button {
                openURL(Self.manageSubscriptionURL)
            } label: {
                rowLabel("Manage subscription", systemImage: "creditcard")
            }
            .listRowBackground(FudoColor.bgCard)

            Button {
                viewModel.restorePurchases()
            } label: {
                HStack {
                    rowLabel("Restore purchases", systemImage: "arrow.clockwise")
                    Spacer()
                    if viewModel.isRestoring {
                        ProgressView()
                            .controlSize(.small)
                            .tint(FudoColor.textSecondary)
                    }
                }
            }
            .disabled(viewModel.isRestoring)
            .listRowBackground(FudoColor.bgCard)
        } header: {
            sectionHeader("Subscription")
        } footer: {
            sectionFooter("Restore reconnects a past purchase to this device.")
        }
    }

    // MARK: - §LEGAL & SUPPORT

    @ViewBuilder
    private var legalSection: some View {
        Section {
            Button { safariLink = SafariLink(url: AppConfig.privacyURL) } label: {
                rowLabel("Privacy Policy", systemImage: "hand.raised")
            }
            .listRowBackground(FudoColor.bgCard)

            Button { safariLink = SafariLink(url: AppConfig.termsURL) } label: {
                rowLabel("Terms of Use", systemImage: "doc.text")
            }
            .listRowBackground(FudoColor.bgCard)

            Button { openURL(Self.contactURL) } label: {
                rowLabel("Contact us", systemImage: "envelope")
            }
            .listRowBackground(FudoColor.bgCard)

            HStack {
                rowLabel("Version", systemImage: "info.circle")
                Spacer()
                Text(viewModel.appVersion)
                    .fudoFont(.body())
                    .foregroundStyle(FudoColor.textSecondary)
            }
            .listRowBackground(FudoColor.bgCard)
        } header: {
            sectionHeader("Legal & support")
        }
    }

    // MARK: - §DATA

    @ViewBuilder
    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showEraseSheet = true
            } label: {
                Text("Erase all my data")
                    .fudoFont(.body())
                    .foregroundStyle(FudoColor.negative)
            }
            .listRowBackground(FudoColor.bgCard)
        } header: {
            sectionHeader("Data")
        } footer: {
            sectionFooter("No account. Your progress lives on your phone.")
        }
        .confirmationDialog("Erase all your data?", isPresented: $showEraseSheet,
                            titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { showEraseAlert = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your challenge, OVR, streak and history — all of it.")
        }
        .alert("This is permanent", isPresented: $showEraseAlert) {
            Button("Erase", role: .destructive) { eraseEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("There's no backup and no account to restore from. You'll start over from onboarding.")
        }
    }

    private func eraseEverything() {
        viewModel.eraseAllData()
        // Hand routing back to the funnel — RootView re-renders onboarding as root.
        appState.hasCompletedOnboarding = false
    }

    // MARK: - Bindings

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.restoreMessage != nil },
            set: { if !$0 { viewModel.restoreMessage = nil } })
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let base = Calendar.current.startOfDay(for: .now)
                return base.addingTimeInterval(TimeInterval(viewModel.reminderMinutes * 60))
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                viewModel.updateReminderMinutes((c.hour ?? 7) * 60 + (c.minute ?? 0))
            })
    }

    private func toggleBinding(_ category: NotificationPreferences.Category) -> Binding<Bool> {
        Binding(
            get: {
                switch category {
                case .dailyReminder: return viewModel.dailyReminderEnabled
                case .eveningReminders: return viewModel.eveningRemindersEnabled
                case .rankCelebrations: return viewModel.rankCelebrationsEnabled
                }
            },
            set: { viewModel.setEnabled($0, for: category) })
    }

    // MARK: - Row helpers

    private func rowLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
                .fudoFont(.body())
                .foregroundStyle(FudoColor.textPrimary)
        } icon: {
            Image(systemName: systemImage)
                .fudoFont(.glyph(16))
                .foregroundStyle(FudoColor.accent)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .fudoFont(.label(12, weight: .bold))
            .kerning(1.0)
            .foregroundStyle(FudoColor.textSecondary)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .fudoFont(.caption())
            .foregroundStyle(FudoColor.textSecondary)
    }
}
