//
//  Services.swift
//  NutriGuard_App
//
//  Protocol contracts the UI depends on, plus mock implementations so the
//  app runs end-to-end while teammates wire up the real backends.
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │  TEAMMATE PLUG-IN POINTS                                            │
//  │  • AI / API teammate:   replace MockFoodCheckService with one that  │
//  │                         calls USDA + Gemini.                        │
//  │  • Data / Logic teammate: extend AppState (totals, limit math).     │
//  │  • Backend / DB lead:    swap in persistent ProfileStore / Tracker  │
//  │                         (e.g. SwiftData, CoreData, server).         │
//  │  The UI never imports anything else from your modules — it only    │
//  │  talks to the protocols below, so you can iterate independently.    │
//  └─────────────────────────────────────────────────────────────────────┘
//

import Foundation
import SwiftUI
import Combine

// MARK: - Protocols (the contract)

protocol FoodCheckService {
    /// Given the user's question + profile + what they've already eaten today,
    /// return a personalized verdict. AI/API teammate implements this.
    func check(question: String,
               profile: UserProfile,
               todaysIntake: Nutrients) async throws -> FoodCheckResult
}

protocol ProfileStore {
    func load() -> UserProfile
    func save(_ profile: UserProfile)
}

protocol FoodTracker {
    func entriesToday() -> [FoodEntry]
    func add(_ entry: FoodEntry)
    func remove(_ entry: FoodEntry)
    func totalsToday() -> Nutrients
}

// MARK: - App State (shared by all views)

/// Single source of truth for the UI. Inject real services into the initializer
/// once teammates have built them.
@MainActor
final class AppState: ObservableObject {
    @Published var profile: UserProfile
    @Published var entries: [FoodEntry]
    @Published var lastResult: FoodCheckResult?
    @Published var isChecking: Bool = false

    private let profileStore: ProfileStore
    private let tracker: FoodTracker
    private let checker: FoodCheckService

    init(profileStore: ProfileStore = UserDefaultsProfileStore(),
         tracker: FoodTracker = InMemoryFoodTracker(),
         checker: FoodCheckService = RealFoodCheckService()) {
        self.profileStore = profileStore
        self.tracker = tracker
        self.checker = checker
        self.profile = profileStore.load()
        self.entries = tracker.entriesToday()
    }

    // Profile
    func updateProfile(_ new: UserProfile) {
        profile = new
        profileStore.save(new)
    }

    // Tracker
    var totals: Nutrients { tracker.totalsToday() }

    func log(_ entry: FoodEntry) {
        tracker.add(entry)
        entries = tracker.entriesToday()
    }

    func remove(_ entry: FoodEntry) {
        tracker.remove(entry)
        entries = tracker.entriesToday()
    }

    // AI check
    func ask(_ question: String) async {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isChecking = true
        defer { isChecking = false }
        do {
            lastResult = try await checker.check(
                question: question,
                profile: profile,
                todaysIntake: totals
            )
        } catch {
            print("❌ FoodCheckService error: \(error)")
            lastResult = FoodCheckResult(
                foodName: question,
                verdict: .caution,
                reason: "Couldn't reach the assistant right now. Please try again.",
                nutrients: Nutrients(),
                servingDescription: "—"
            )
        }
    }
}

// MARK: - Mock implementations (replace these)

/// AI/API teammate: replace this with a real Gemini + USDA backed service.
/// The mock just gives plausible-looking answers so the UI is testable.
struct MockFoodCheckService: FoodCheckService {
    func check(question: String,
               profile: UserProfile,
               todaysIntake: Nutrients) async throws -> FoodCheckResult {
        try? await Task.sleep(nanoseconds: 600_000_000)

        let foodName = question
            .replacingOccurrences(of: "can i eat", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "can i drink", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized

        let lower = question.lowercased()
        let mockNutrients: Nutrients
        let verdict: FoodCheckResult.Verdict
        let reason: String
        let serving: String

        if lower.contains("water") || lower.contains("salad") {
            mockNutrients = Nutrients(calories: 15, sugarG: 1, sodiumMg: 10, carbsG: 3, fatG: 0, proteinG: 1)
            verdict = .yes
            reason = "Low in sugar and sodium — safe for your conditions and well within today's limits."
            serving = "1 serving"
        } else if lower.contains("milk") {
            mockNutrients = Nutrients(calories: 150, sugarG: 12, sodiumMg: 105, carbsG: 12, fatG: 8, proteinG: 8)
            verdict = profile.conditions.contains(.diabetes) ? .caution : .yes
            reason = profile.conditions.contains(.diabetes)
                ? "Whole milk has 12g of natural sugar (lactose). You've already had \(Int(todaysIntake.sugarG))g today — one cup is OK but watch the rest of the day."
                : "Reasonable choice — moderate calories and protein."
            serving = "1 cup (240 ml)"
        } else if lower.contains("mac") || lower.contains("cheese") || lower.contains("pizza") {
            mockNutrients = Nutrients(calories: 410, sugarG: 6, sodiumMg: 820, carbsG: 48, fatG: 18, proteinG: 14)
            verdict = profile.conditions.contains(.hypertension) ? .no : .caution
            reason = profile.conditions.contains(.hypertension)
                ? "One serving has ~820mg sodium — that's already 35% of your daily limit and you've had \(Int(todaysIntake.sodiumMg))mg today. Better to skip or pick a low-sodium option."
                : "High in sodium and refined carbs. Fine occasionally, but not every day."
            serving = "1 cup (220 g)"
        } else {
            mockNutrients = Nutrients(calories: 200, sugarG: 8, sodiumMg: 300, carbsG: 25, fatG: 7, proteinG: 6)
            verdict = .caution
            reason = "Moderate nutritional impact. Real reasoning will come from Gemini once the AI service is wired in."
            serving = "1 serving"
        }

        return FoodCheckResult(
            foodName: foodName.isEmpty ? "This food" : foodName,
            verdict: verdict,
            reason: reason,
            nutrients: mockNutrients,
            servingDescription: serving
        )
    }
}

/// Backend/DB lead: replace with SwiftData / CoreData / server-backed storage.
struct UserDefaultsProfileStore: ProfileStore {
    private let key = "nutriguard.profile.v1"

    func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return UserProfile() }
        return decoded
    }

    func save(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Backend/DB lead: replace with persistent storage. Resets on app launch for now.
final class InMemoryFoodTracker: FoodTracker {
    private var all: [FoodEntry] = []

    func entriesToday() -> [FoodEntry] {
        let cal = Calendar.current
        return all.filter { cal.isDateInToday($0.loggedAt) }
                  .sorted { $0.loggedAt > $1.loggedAt }
    }

    func add(_ entry: FoodEntry) { all.append(entry) }

    func remove(_ entry: FoodEntry) { all.removeAll { $0.id == entry.id } }

    func totalsToday() -> Nutrients {
        entriesToday().reduce(into: Nutrients()) { acc, e in
            acc.calories += e.nutrients.calories
            acc.sugarG   += e.nutrients.sugarG
            acc.sodiumMg += e.nutrients.sodiumMg
            acc.carbsG   += e.nutrients.carbsG
            acc.fatG     += e.nutrients.fatG
            acc.proteinG += e.nutrients.proteinG
        }
    }
}
