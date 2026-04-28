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
        let ch = checker      ?? NvidiaFoodCheckService()
        let an = analyzer     ?? NvidiaAnalyzeService()
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

// MARK: - NVIDIA API Client (shared)

/// Shared HTTP client for NVIDIA's OpenAI-compatible chat completions endpoint.
enum NvidiaAPIClient {
    static let apiKey = "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"
    static let endpoint = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!
    static let model = "meta/llama-3.1-70b-instruct"

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct RequestBody: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let max_tokens: Int
    }

    struct ResponseBody: Codable {
        struct Choice: Codable {
            struct Message: Codable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Send a chat completion request and return the assistant's text response.
    static func chat(system: String, user: String, temperature: Double = 0.3, maxTokens: Int = 1500) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = RequestBody(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user)
            ],
            temperature: temperature,
            max_tokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "NvidiaAPI", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API error (\(statusCode)): \(responseText)"])
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw NSError(domain: "NvidiaAPI", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Empty response from AI"])
        }
        return content
    }
}

// MARK: - NVIDIA Food Check Service

struct NvidiaFoodCheckService: FoodCheckService {
    func check(question: String,
               profile: UserProfile,
               todaysIntake: Nutrients) async throws -> FoodCheckResult {

        let conditions = profile.conditions.isEmpty
            ? "None reported"
            : profile.conditions.map { $0.rawValue }.joined(separator: ", ")

        let system = """
        You are NutriGuard, a clinical nutrition assistant. The user will ask about eating a specific food, possibly with a quantity (e.g. "Can I eat 2 slices of pizza?" or "200g of rice").

        RULES:
        1. Identify the food AND quantity from the question. If no quantity is given, assume 1 standard serving.
        2. Estimate the nutritional content for THAT SPECIFIC QUANTITY.
        3. Consider the user's health conditions and what they've already eaten today.
        4. Give a verdict: "yes" (safe), "caution" (OK in moderation), or "no" (avoid).

        Respond in EXACTLY this JSON format, no extra text:
        {
          "foodName": "Name of the food",
          "serving": "quantity description (e.g. 2 slices, 200g, 1 cup)",
          "verdict": "yes|caution|no",
          "reason": "2-3 sentence personalized explanation considering their conditions and today's intake",
          "calories": 0,
          "sugarG": 0,
          "sodiumMg": 0,
          "carbsG": 0,
          "fatG": 0,
          "proteinG": 0
        }
        """

        let user = """
        User's health conditions: \(conditions)
        Daily limits: \(Int(profile.dailyCalorieLimit)) kcal, \(Int(profile.dailySugarLimitG))g sugar, \(Int(profile.dailySodiumLimitMg))mg sodium
        Already eaten today: \(Int(todaysIntake.calories)) kcal, \(Int(todaysIntake.sugarG))g sugar, \(Int(todaysIntake.sodiumMg))mg sodium, \(Int(todaysIntake.carbsG))g carbs, \(Int(todaysIntake.fatG))g fat, \(Int(todaysIntake.proteinG))g protein

        Question: \(question)
        """

        let raw = try await NvidiaAPIClient.chat(system: system, user: user, temperature: 0.2, maxTokens: 600)
        return try parseFoodCheckResponse(raw, fallbackQuestion: question)
    }

    private func parseFoodCheckResponse(_ raw: String, fallbackQuestion: String) throws -> FoodCheckResult {
        // Extract JSON from response (handle markdown code blocks)
        let jsonString: String
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") {
            jsonString = String(raw[start...end])
        } else {
            jsonString = raw
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Parse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let foodName = json["foodName"] as? String ?? fallbackQuestion.capitalized
        let serving  = json["serving"] as? String ?? "1 serving"
        let reason   = json["reason"] as? String ?? "Unable to analyze this food."

        let verdictStr = (json["verdict"] as? String ?? "caution").lowercased()
        let verdict: FoodCheckResult.Verdict
        switch verdictStr {
        case "yes":  verdict = .yes
        case "no":   verdict = .no
        default:     verdict = .caution
        }

        let nutrients = Nutrients(
            calories: (json["calories"] as? Double) ?? Double(json["calories"] as? Int ?? 0),
            sugarG:   (json["sugarG"] as? Double) ?? Double(json["sugarG"] as? Int ?? 0),
            sodiumMg: (json["sodiumMg"] as? Double) ?? Double(json["sodiumMg"] as? Int ?? 0),
            carbsG:   (json["carbsG"] as? Double) ?? Double(json["carbsG"] as? Int ?? 0),
            fatG:     (json["fatG"] as? Double) ?? Double(json["fatG"] as? Int ?? 0),
            proteinG: (json["proteinG"] as? Double) ?? Double(json["proteinG"] as? Int ?? 0)
        )

        return FoodCheckResult(
            foodName: foodName,
            verdict: verdict,
            reason: reason,
            nutrients: nutrients,
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

// MARK: - NVIDIA Analyze Service

struct NvidiaAnalyzeService: AnalyzeService {
    func analyze(entries: [FoodEntry],
                 totals: Nutrients,
                 profile: UserProfile,
                 bloodSugar: [BloodSugarEntry]) async throws -> AnalysisReport {

        let conditions = profile.conditions.isEmpty
            ? "None reported"
            : profile.conditions.map { $0.rawValue }.joined(separator: ", ")

        // Build food log summary
        let foodLog: String
        if entries.isEmpty {
            foodLog = "No food logged for this day."
        } else {
            foodLog = entries.map { e in
                let t = e.loggedAt.formatted(.dateTime.hour().minute())
                return "- \(t): \(e.name) (\(e.servingDescription)) — \(Int(e.nutrients.calories)) kcal, \(Int(e.nutrients.sugarG))g sugar, \(Int(e.nutrients.sodiumMg))mg sodium"
            }.joined(separator: "\n")
        }

        // Build blood sugar summary (last 7 days)
        let recentBS: String
        if bloodSugar.isEmpty {
            recentBS = "No blood sugar readings available."
        } else {
            let cal = Calendar.current
            let cutoff = cal.date(byAdding: .day, value: -7, to: Date())!
            let recent = bloodSugar.filter { $0.recordedAt >= cutoff }
                .sorted { $0.recordedAt < $1.recordedAt }
            recentBS = recent.map { e in
                let t = e.recordedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute())
                let cat = e.category.label
                return "- \(t): \(Int(e.level)) mg/dL (\(e.context.rawValue)) — \(cat)"
            }.joined(separator: "\n")
        }

        let system = """
        You are NutriGuard Health Analyzer. Analyze the user's daily food intake, blood sugar readings, and health profile to provide a comprehensive health report.

        RULES:
        1. Identify GOOD habits the user is following.
        2. Identify BAD habits or concerning patterns.
        3. If blood sugar is consistently high (>180 after meals or >130 fasting) for 3+ days in a row, recommend the user talk to their doctor.
        4. Provide actionable suggestions for the remaining time of the day or the next day.
        5. Suggest specific meals that would help improve their health given their conditions.

        Respond in EXACTLY this JSON format, no extra text:
        {
          "summary": "2-3 sentence overview of overall health status for this day",
          "goodHabits": ["habit 1", "habit 2"],
          "badHabits": ["concern 1", "concern 2"],
          "suggestions": ["suggestion 1", "suggestion 2", "suggestion 3"],
          "mealPlan": "Specific meal suggestions for remaining day or next day"
        }
        """

        let user = """
        PATIENT PROFILE:
        Health conditions: \(conditions)
        Daily limits: \(Int(profile.dailyCalorieLimit)) kcal, \(Int(profile.dailySugarLimitG))g sugar, \(Int(profile.dailySodiumLimitMg))mg sodium

        TODAY'S FOOD LOG:
        Total: \(Int(totals.calories)) kcal, \(Int(totals.sugarG))g sugar, \(Int(totals.sodiumMg))mg sodium, \(Int(totals.carbsG))g carbs, \(Int(totals.fatG))g fat, \(Int(totals.proteinG))g protein
        \(foodLog)

        BLOOD SUGAR READINGS (last 7 days):
        \(recentBS)

        Please analyze and provide your report.
        """

        let raw = try await NvidiaAPIClient.chat(system: system, user: user, temperature: 0.4, maxTokens: 1200)
        return try parseAnalysisResponse(raw)
    }

    private func parseAnalysisResponse(_ raw: String) throws -> AnalysisReport {
        let jsonString: String
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") {
            jsonString = String(raw[start...end])
        } else {
            jsonString = raw
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Parse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        let summary = json["summary"] as? String ?? "Analysis complete."
        let goodHabits = json["goodHabits"] as? [String] ?? []
        let badHabits = json["badHabits"] as? [String] ?? []
        let suggestions = json["suggestions"] as? [String] ?? []
        let mealPlan = json["mealPlan"] as? String ?? ""

        return AnalysisReport(
            summary: summary,
            goodHabits: goodHabits,
            badHabits: badHabits,
            suggestions: suggestions,
            mealPlan: mealPlan
        )
    }
}
