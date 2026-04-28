//
//  ProfileView.swift
//  NutriGuard_App
//
//  Lets the user set their name, conditions, and daily limits. These values
//  are read by HomeView (sent to AI) and TrackerView (rings).
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var auth: AuthState
    @State private var draft: UserProfile = UserProfile()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    TextField("Your name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach(HealthCondition.allCases) { condition in
                        Toggle(isOn: bindingFor(condition)) {
                            Label {
                                Text(condition.rawValue)
                            } icon: {
                                Image(systemName: condition.icon)
                                    .foregroundStyle(condition.tint)
                            }
                        }
                    }
                } header: {
                    Text("Health conditions")
                } footer: {
                    Text("NutriGuard tailors every answer to the conditions you select.")
                }

                Section {
                    LimitStepper(title: "Sugar",
                                 value: $draft.dailySugarLimitG,
                                 range: 10...150, step: 5, unit: "g")
                    LimitStepper(title: "Sodium",
                                 value: $draft.dailySodiumLimitMg,
                                 range: 500...4000, step: 100, unit: "mg")
                    LimitStepper(title: "Calories",
                                 value: $draft.dailyCalorieLimit,
                                 range: 1000...4000, step: 50, unit: "kcal")
                } header: {
                    Text("Daily limits")
                } footer: {
                    Text("These are compared against today's intake on the Today tab.")
                }

                Section {
                    Button {
                        state.updateProfile(draft)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save changes").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(draft == state.profile)
                }

                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                if !loaded {
                    draft = state.profile
                    loaded = true
                }
            }
            .onChange(of: state.profile) { _, new in
                draft = new
            }
        }
    }

    private func bindingFor(_ c: HealthCondition) -> Binding<Bool> {
        Binding(
            get: { draft.conditions.contains(c) },
            set: { isOn in
                if isOn { draft.conditions.insert(c) }
                else { draft.conditions.remove(c) }
            }
        )
    }
}

// MARK: - Stepper row

private struct LimitStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

@MainActor
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState())
            .environmentObject(AuthState())
    }
}
