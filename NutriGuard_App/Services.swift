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
import ParseSwift

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
    func entriesForDate(_ date: Date) -> [FoodEntry]
    func add(_ entry: FoodEntry)
    func remove(_ entry: FoodEntry)
    func totalsToday() -> Nutrients
    func totalsForDate(_ date: Date) -> Nutrients
}

protocol BloodSugarStore {
    func all() -> [BloodSugarEntry]
    func add(_ entry: BloodSugarEntry)
    func remove(_ entry: BloodSugarEntry)
}

/// AI-powered daily analysis. NVIDIA API teammate: replace MockAnalyzeService
/// with a real implementation that calls the NVIDIA endpoint.
protocol AnalyzeService {
    func analyze(entries: [FoodEntry],
                 totals: Nutrients,
                 profile: UserProfile,
                 bloodSugar: [BloodSugarEntry]) async throws -> AnalysisReport
}

/// The report returned by the Analyze feature.
struct AnalysisReport: Identifiable, Equatable {
    let id: UUID = UUID()
    let summary: String
    let goodHabits: [String]
    let badHabits: [String]
    let suggestions: [String]
    let mealPlan: String   // Suggested next meals
}

// MARK: - App State (shared by all views)

/// Single source of truth for the UI. Inject real services into the initializer
/// once teammates have built them.
@MainActor
final class AppState: ObservableObject {
    @Published var profile: UserProfile
    @Published var entries: [FoodEntry]
    @Published var bloodSugarEntries: [BloodSugarEntry]
    @Published var lastResult: FoodCheckResult?
    @Published var isChecking: Bool = false
    @Published var selectedDate: Date = Date()
    @Published var lastAnalysis: AnalysisReport?
    @Published var isAnalyzing: Bool = false

    private let profileStore: ProfileStore
    private let tracker: FoodTracker
    private let bloodSugarStore: BloodSugarStore
    private let checker: FoodCheckService
    private let analyzer: AnalyzeService

    init(profileStore: (any ProfileStore)? = nil,
         tracker: (any FoodTracker)? = nil,
         bloodSugarStore: (any BloodSugarStore)? = nil,
         checker: (any FoodCheckService)? = nil,
         analyzer: (any AnalyzeService)? = nil) {
        let ps = profileStore ?? UserDefaultsProfileStore()
        let tr = tracker      ?? InMemoryFoodTracker()
        let bs = bloodSugarStore ?? InMemoryBloodSugarStore()
        let ch = checker      ?? MockFoodCheckService()
        let an = analyzer     ?? MockAnalyzeService()
        self.profileStore      = ps
        self.tracker           = tr
        self.bloodSugarStore   = bs
        self.checker           = ch
        self.analyzer          = an
        self.profile           = ps.load()
        self.entries           = tr.entriesToday()
        self.bloodSugarEntries = bs.all()
    }

    // Profile
    func updateProfile(_ new: UserProfile) {
        profile = new
        profileStore.save(new)
    }

    // Tracker
    var totals: Nutrients { tracker.totalsToday() }

    func entriesForSelectedDate() -> [FoodEntry] {
        tracker.entriesForDate(selectedDate)
    }

    func totalsForSelectedDate() -> Nutrients {
        tracker.totalsForDate(selectedDate)
    }

    func log(_ entry: FoodEntry) {
        tracker.add(entry)
        entries = tracker.entriesToday()
    }

    func remove(_ entry: FoodEntry) {
        tracker.remove(entry)
        entries = tracker.entriesToday()
    }

    // Blood sugar
    func logBloodSugar(_ entry: BloodSugarEntry) {
        bloodSugarStore.add(entry)
        bloodSugarEntries = bloodSugarStore.all()
    }

    func removeBloodSugar(_ entry: BloodSugarEntry) {
        bloodSugarStore.remove(entry)
        bloodSugarEntries = bloodSugarStore.all()
    }

    // Analyze
    func runAnalysis() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            lastAnalysis = try await analyzer.analyze(
                entries: entriesForSelectedDate(),
                totals: totalsForSelectedDate(),
                profile: profile,
                bloodSugar: bloodSugarEntries
            )
        } catch {
            lastAnalysis = AnalysisReport(
                summary: "Unable to generate analysis right now. Please try again.",
                goodHabits: [],
                badHabits: [],
                suggestions: ["Check your network connection and try again."],
                mealPlan: ""
            )
        }
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

// MARK: - Parse-backed profile store (production)

/// Seeded from the NutriUser fetched at login; every save(_:) pushes the
/// updated fields back to Back4App using the Parse-Swift SDK.
final class ParseProfileStore: ProfileStore {
    private var cache: UserProfile

    init(initial: UserProfile) {
        self.cache = initial
    }

    func load() -> UserProfile { cache }

    func save(_ profile: UserProfile) {
        cache = profile
        Task { @MainActor in
            guard var user = NutriUser.current else { return }
            user.displayName        = profile.name
            user.conditions         = profile.conditions.map { $0.rawValue }
            user.dailySugarLimitG   = profile.dailySugarLimitG
            user.dailySodiumLimitMg = profile.dailySodiumLimitMg
            user.dailyCalorieLimit  = profile.dailyCalorieLimit
            _ = try? await user.save()
        }
    }
}

final class InMemoryBloodSugarStore: BloodSugarStore {
    private var store: [BloodSugarEntry] = []

    init() {
        // Seed 30 days of realistic diabetic blood sugar data
        let calendar = Calendar.current
        let now = Date()

        // Deterministic but varied readings for a diabetic patient over 30 days.
        // Fasting: 110-180, Before meal: 120-170, After meal: 160-250, Bedtime: 130-200
        let seedData: [(dayOffset: Int, level: Double, context: BloodSugarEntry.MealContext)] = [
            // Day -30
            (-30, 148, .fasting), (-30, 198, .afterMeal),
            // Day -29
            (-29, 135, .fasting), (-29, 215, .afterMeal), (-29, 162, .bedtime),
            // Day -28
            (-28, 142, .fasting), (-28, 188, .afterMeal),
            // Day -27
            (-27, 158, .fasting), (-27, 230, .afterMeal), (-27, 175, .bedtime),
            // Day -26
            (-26, 130, .beforeMeal), (-26, 195, .afterMeal),
            // Day -25
            (-25, 155, .fasting), (-25, 242, .afterMeal), (-25, 185, .bedtime),
            // Day -24
            (-24, 122, .fasting), (-24, 178, .afterMeal),
            // Day -23
            (-23, 140, .fasting), (-23, 205, .afterMeal), (-23, 168, .bedtime),
            // Day -22
            (-22, 165, .fasting), (-22, 248, .afterMeal),
            // Day -21
            (-21, 138, .fasting), (-21, 192, .afterMeal), (-21, 155, .bedtime),
            // Day -20
            (-20, 145, .beforeMeal), (-20, 210, .afterMeal),
            // Day -19
            (-19, 132, .fasting), (-19, 186, .afterMeal), (-19, 160, .bedtime),
            // Day -18
            (-18, 170, .fasting), (-18, 235, .afterMeal),
            // Day -17
            (-17, 128, .fasting), (-17, 175, .afterMeal), (-17, 150, .bedtime),
            // Day -16
            (-16, 152, .fasting), (-16, 220, .afterMeal),
            // Day -15
            (-15, 118, .fasting), (-15, 168, .afterMeal), (-15, 142, .bedtime),
            // Day -14
            (-14, 160, .fasting), (-14, 238, .afterMeal),
            // Day -13
            (-13, 125, .beforeMeal), (-13, 182, .afterMeal), (-13, 158, .bedtime),
            // Day -12
            (-12, 148, .fasting), (-12, 205, .afterMeal),
            // Day -11
            (-11, 136, .fasting), (-11, 195, .afterMeal), (-11, 165, .bedtime),
            // Day -10
            (-10, 155, .fasting), (-10, 225, .afterMeal),
            // Day -9
            (-9, 142, .fasting), (-9, 190, .afterMeal), (-9, 170, .bedtime),
            // Day -8
            (-8, 130, .fasting), (-8, 178, .afterMeal),
            // Day -7
            (-7, 162, .fasting), (-7, 240, .afterMeal), (-7, 180, .bedtime),
            // Day -6
            (-6, 138, .beforeMeal), (-6, 200, .afterMeal),
            // Day -5
            (-5, 150, .fasting), (-5, 218, .afterMeal), (-5, 172, .bedtime),
            // Day -4
            (-4, 125, .fasting), (-4, 185, .afterMeal),
            // Day -3
            (-3, 158, .fasting), (-3, 232, .afterMeal), (-3, 178, .bedtime),
            // Day -2
            (-2, 140, .fasting), (-2, 195, .afterMeal),
            // Day -1 (yesterday)
            (-1, 134, .fasting), (-1, 208, .afterMeal), (-1, 165, .bedtime),
            // Day 0 (today)
            (0, 145, .fasting), (0, 215, .afterMeal),
        ]

        for item in seedData {
            // Place fasting at ~7 AM, beforeMeal ~11:30 AM, afterMeal ~1 PM, bedtime ~10 PM
            let hour: Int
            switch item.context {
            case .fasting:    hour = 7
            case .beforeMeal: hour = 11
            case .afterMeal:  hour = 13
            case .bedtime:    hour = 22
            }

            if let day = calendar.date(byAdding: .day, value: item.dayOffset, to: now),
               let entryDate = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) {
                store.append(BloodSugarEntry(level: item.level, context: item.context, recordedAt: entryDate))
            }
        }
    }

    func all() -> [BloodSugarEntry] {
        store.sorted { $0.recordedAt > $1.recordedAt }
    }
    func add(_ entry: BloodSugarEntry)    { store.append(entry) }
    func remove(_ entry: BloodSugarEntry) { store.removeAll { $0.id == entry.id } }
}

/// Backend/DB lead: replace with persistent storage. Resets on app launch for now.
final class InMemoryFoodTracker: FoodTracker {
    private var store: [FoodEntry] = []

    init() {
        // Seed realistic food entries for yesterday and today
        let calendar = Calendar.current
        let now = Date()
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }

        // Helper to create a date at a specific hour
        func dateAt(day: Date, hour: Int, minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        // ── Yesterday's meals ──
        store.append(FoodEntry(
            name: "Oatmeal with Banana",
            servingDescription: "1 bowl (350g)",
            nutrients: Nutrients(calories: 350, sugarG: 8, sodiumMg: 120, carbsG: 55, fatG: 6, proteinG: 12),
            loggedAt: dateAt(day: yesterday, hour: 7, minute: 30)
        ))
        store.append(FoodEntry(
            name: "Apple with Peanut Butter",
            servingDescription: "1 apple + 2 tbsp PB",
            nutrients: Nutrients(calories: 280, sugarG: 15, sodiumMg: 85, carbsG: 30, fatG: 16, proteinG: 7),
            loggedAt: dateAt(day: yesterday, hour: 10, minute: 0)
        ))
        store.append(FoodEntry(
            name: "Grilled Chicken Salad",
            servingDescription: "1 large bowl",
            nutrients: Nutrients(calories: 420, sugarG: 5, sodiumMg: 680, carbsG: 18, fatG: 22, proteinG: 35),
            loggedAt: dateAt(day: yesterday, hour: 12, minute: 30)
        ))
        store.append(FoodEntry(
            name: "Greek Yogurt with Berries",
            servingDescription: "1 cup (200g)",
            nutrients: Nutrients(calories: 180, sugarG: 18, sodiumMg: 55, carbsG: 24, fatG: 3, proteinG: 15),
            loggedAt: dateAt(day: yesterday, hour: 15, minute: 0)
        ))
        store.append(FoodEntry(
            name: "Salmon with Rice & Veggies",
            servingDescription: "1 plate",
            nutrients: Nutrients(calories: 550, sugarG: 4, sodiumMg: 480, carbsG: 45, fatG: 18, proteinG: 38),
            loggedAt: dateAt(day: yesterday, hour: 19, minute: 0)
        ))

        // ── Today's meals (breakfast + snack so far) ──
        store.append(FoodEntry(
            name: "Scrambled Eggs & Toast",
            servingDescription: "2 eggs + 1 slice toast",
            nutrients: Nutrients(calories: 310, sugarG: 2, sodiumMg: 420, carbsG: 22, fatG: 16, proteinG: 20),
            loggedAt: dateAt(day: now, hour: 7, minute: 45)
        ))
        store.append(FoodEntry(
            name: "Mixed Nuts",
            servingDescription: "1/4 cup (30g)",
            nutrients: Nutrients(calories: 170, sugarG: 1, sodiumMg: 95, carbsG: 6, fatG: 15, proteinG: 5),
            loggedAt: dateAt(day: now, hour: 10, minute: 15)
        ))
    }

    func entriesToday() -> [FoodEntry] {
        let cal = Calendar.current
        return store.filter { cal.isDateInToday($0.loggedAt) }
                    .sorted { $0.loggedAt > $1.loggedAt }
    }

    func entriesForDate(_ date: Date) -> [FoodEntry] {
        let cal = Calendar.current
        return store.filter { cal.isDate($0.loggedAt, inSameDayAs: date) }
                    .sorted { $0.loggedAt > $1.loggedAt }
    }

    func add(_ entry: FoodEntry) { store.append(entry) }

    func remove(_ entry: FoodEntry) { store.removeAll { $0.id == entry.id } }

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

    func totalsForDate(_ date: Date) -> Nutrients {
        entriesForDate(date).reduce(into: Nutrients()) { acc, e in
            acc.calories += e.nutrients.calories
            acc.sugarG   += e.nutrients.sugarG
            acc.sodiumMg += e.nutrients.sodiumMg
            acc.carbsG   += e.nutrients.carbsG
            acc.fatG     += e.nutrients.fatG
            acc.proteinG += e.nutrients.proteinG
        }
    }
}

// MARK: - Analyze Service (NVIDIA API stub)

/// Replace this with a real NVIDIA API-backed service.
/// The real implementation should POST to the NVIDIA endpoint with the user's
/// food log, blood sugar data, and profile, then parse the AI response into
/// an AnalysisReport.
struct MockAnalyzeService: AnalyzeService {
    func analyze(entries: [FoodEntry],
                 totals: Nutrients,
                 profile: UserProfile,
                 bloodSugar: [BloodSugarEntry]) async throws -> AnalysisReport {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        let totalCal = Int(totals.calories)
        let totalSugar = Int(totals.sugarG)
        let totalSodium = Int(totals.sodiumMg)

        return AnalysisReport(
            summary: "Based on your food log (\(totalCal) kcal, \(totalSugar)g sugar, \(totalSodium)mg sodium) and blood sugar readings, here's your personalized analysis.",
            goodHabits: [
                "Good protein intake from chicken and salmon",
                "Including fruits and vegetables regularly",
                "Balanced meal timing throughout the day",
                "Oatmeal is an excellent low-GI breakfast choice"
            ],
            badHabits: [
                "Blood sugar spikes after meals suggest portion control needed",
                "Sodium intake is approaching daily limits",
                "Sugar from yogurt and fruit snacks adds up"
            ],
            suggestions: [
                "Consider adding more fiber-rich foods to slow sugar absorption",
                "Try reducing portion sizes at dinner to lower post-meal blood sugar",
                "Swap Greek yogurt toppings to nuts instead of berries to cut sugar",
                "Add a short walk after meals to help manage blood sugar spikes",
                "Stay hydrated — aim for 8 glasses of water daily"
            ],
            mealPlan: "🍽 Suggested remaining meals:\n\n" +
                "Lunch: Grilled fish with steamed broccoli & quinoa (low GI, high protein)\n" +
                "Snack: Handful of almonds + cucumber slices with hummus\n" +
                "Dinner: Turkey stir-fry with bell peppers & brown rice (keep portion to 1 cup rice)\n\n" +
                "Tomorrow's breakfast: Steel-cut oats with chia seeds & walnuts (no added sugar)"
        )
    }
}
