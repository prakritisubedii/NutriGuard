//
//  HomeView.swift
//  NutriGuard_App
//
//  "Can I eat ___?" screen. Sends the question to FoodCheckService and
//  shows a verdict card. User can log the food into today's tracker.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @State private var question: String = ""
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "Can I drink whole milk?",
        "Can I eat mac and cheese?",
        "Can I have a banana?",
        "Is pizza okay tonight?"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    askBar

                    if state.profile.conditions.isEmpty {
                        emptyConditionsHint
                    }

                    if state.isChecking {
                        loadingCard
                    } else if let result = state.lastResult {
                        ResultCard(result: result) {
                            let entry = FoodEntry(
                                name: result.foodName,
                                servingDescription: result.servingDescription,
                                nutrients: result.nutrients
                            )
                            state.log(entry)
                        }
                    } else {
                        suggestionsSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("NutriGuard")
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi\(state.profile.name.isEmpty ? "" : ", \(state.profile.name)")")
                .font(.title2.weight(.semibold))
            Text("Ask me anything about a food or drink.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var askBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Can I eat…", text: $question, axis: .vertical)
                .lineLimit(1...3)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { send() }

            if !question.isEmpty {
                Button { question = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(question.isEmpty ? Color.secondary : Color.green)
            }
            .disabled(question.isEmpty || state.isChecking)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var emptyConditionsHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add your health conditions")
                    .font(.subheadline.weight(.semibold))
                Text("Open the Profile tab so answers can be tailored to you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(suggestions, id: \.self) { s in
                Button {
                    question = s
                    send()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.green)
                        Text(s)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingCard: some View {
        HStack {
            ProgressView()
            Text("Checking with NutriGuard…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func send() {
        let q = question
        inputFocused = false
        Task { await state.ask(q) }
    }
}

// MARK: - Result Card

private struct ResultCard: View {
    let result: FoodCheckResult
    let onLog: () -> Void
    @State private var logged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: result.verdict.icon)
                    .font(.title)
                    .foregroundStyle(result.verdict.color)
                VStack(alignment: .leading) {
                    Text(result.verdict.label)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(result.verdict.color)
                    Text(result.foodName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(result.reason)
                .font(.callout)

            Divider()

            HStack(spacing: 16) {
                NutrientPill(label: "kcal", value: "\(Int(result.nutrients.calories))")
                NutrientPill(label: "sugar", value: "\(Int(result.nutrients.sugarG))g")
                NutrientPill(label: "sodium", value: "\(Int(result.nutrients.sodiumMg))mg")
            }

            Text(result.servingDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: {
                guard !logged else { return }
                onLog()
                withAnimation { logged = true }
            }) {
                HStack {
                    Image(systemName: logged ? "checkmark.circle.fill" : "plus.circle.fill")
                    Text(logged ? "Logged in Today" : "Log this food")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(logged ? Color.green.opacity(0.2) : Color.green,
                            in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(logged ? Color.green : Color.white)
            }
            .disabled(logged)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(result.verdict.color.opacity(0.4), lineWidth: 1)
        )
    }
}

private struct NutrientPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView().environmentObject(AppState())
}
