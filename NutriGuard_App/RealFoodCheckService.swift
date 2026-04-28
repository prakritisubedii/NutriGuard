//
//  RealFoodCheckService.swift
//  NutriGuard_App
//
//  Implements FoodCheckService using USDA FoodData Central (nutrients)
//  and Gemini (personalized verdict). Replaces MockFoodCheckService.
//

import Foundation

struct RealFoodCheckService: FoodCheckService {

    func check(question: String,
               profile: UserProfile,
               todaysIntake: Nutrients) async throws -> FoodCheckResult {
        let foodName = extractFoodName(from: question)
        let (nutrients, serving) = (try? await fetchNutrients(for: foodName)) ?? (Nutrients(), "1 serving")
        return try await geminiVerdict(
            question: question,
            foodName: foodName,
            nutrients: nutrients,
            serving: serving,
            profile: profile,
            todaysIntake: todaysIntake
        )
    }

    // MARK: - Food name extraction

    private func extractFoodName(from question: String) -> String {
        var text = question.lowercased()
        let strip = ["can i eat", "can i drink", "can i have", "is it okay to eat",
                     "is it okay to drink", "should i eat", "should i drink", "tonight", "?"]
        strip.forEach { text = text.replacingOccurrences(of: $0, with: "") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }

    // MARK: - USDA FoodData Central

    private func fetchNutrients(for food: String) async throws -> (Nutrients, String) {
        var comps = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query",    value: food),
            URLQueryItem(name: "api_key",  value: Secrets.usdaKey),
            URLQueryItem(name: "pageSize", value: "1")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response  = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        guard let item = response.foods.first else { return (Nutrients(), "1 serving") }

        var n = Nutrients()
        for nutrient in item.foodNutrients {
            let name = nutrient.nutrientName.lowercased()
            let val  = nutrient.value ?? 0
            if name.contains("energy") && nutrient.unitName?.uppercased() == "KCAL" {
                n.calories = val
            } else if name.contains("total sugars") || (name.contains("sugar") && !name.contains("added")) {
                n.sugarG = val
            } else if name.contains("sodium") {
                n.sodiumMg = val
            } else if name.contains("carbohydrate") {
                n.carbsG = val
            } else if name.contains("total lipid") || (name.contains("fat") && !name.contains("fatty")) {
                n.fatG = val
            } else if name == "protein" {
                n.proteinG = val
            }
        }
        return (n, "100g")
    }

    // MARK: - Gemini

    private func geminiVerdict(question: String,
                               foodName: String,
                               nutrients: Nutrients,
                               serving: String,
                               profile: UserProfile,
                               todaysIntake: Nutrients) async throws -> FoodCheckResult {
        let conditions = profile.conditions.isEmpty
            ? "none"
            : profile.conditions.map(\.rawValue).joined(separator: ", ")

        let prompt = """
        You are a nutrition advisor for the NutriGuard health app.

        User asked: "\(question)"
        Health conditions: \(conditions)
        Daily limits — sugar: \(Int(profile.dailySugarLimitG))g, sodium: \(Int(profile.dailySodiumLimitMg))mg, calories: \(Int(profile.dailyCalorieLimit))kcal
        Already eaten today — sugar: \(Int(todaysIntake.sugarG))g, sodium: \(Int(todaysIntake.sodiumMg))mg, calories: \(Int(todaysIntake.calories))kcal

        Food: \(foodName) (per \(serving))
        Calories: \(Int(nutrients.calories))kcal | Sugar: \(String(format: "%.1f", nutrients.sugarG))g | Sodium: \(Int(nutrients.sodiumMg))mg | Carbs: \(String(format: "%.1f", nutrients.carbsG))g | Fat: \(String(format: "%.1f", nutrients.fatG))g | Protein: \(String(format: "%.1f", nutrients.proteinG))g

        Assess whether the user should eat this food given their conditions and remaining daily budget.
        Reply with ONLY a raw JSON object (no markdown, no extra text):
        {"verdict": "yes" or "caution" or "no", "reason": "2-3 sentence personalized explanation referencing their specific conditions and remaining limits"}
        """

        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=\(Secrets.geminiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        print("🔵 Gemini raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
        let gemini = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let raw = gemini.candidates.first?.content.parts.first?.text else {
            throw URLError(.badServerResponse)
        }

        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let displayName = foodName.isEmpty ? "This food" : foodName

        if let parsed = try? JSONDecoder().decode(GeminiVerdict.self, from: Data(clean.utf8)) {
            let verdict: FoodCheckResult.Verdict
            switch parsed.verdict {
            case "yes": verdict = .yes
            case "no":  verdict = .no
            default:    verdict = .caution
            }
            return FoodCheckResult(foodName: displayName, verdict: verdict,
                                   reason: parsed.reason, nutrients: nutrients,
                                   servingDescription: serving)
        }

        return FoodCheckResult(foodName: displayName, verdict: .caution,
                               reason: "Got a response but couldn't parse it. Please try again.",
                               nutrients: nutrients, servingDescription: serving)
    }
}

// MARK: - USDA response models

private struct USDASearchResponse: Codable { let foods: [USDAFood] }
private struct USDAFood: Codable { let description: String; let foodNutrients: [USDANutrient] }
private struct USDANutrient: Codable { let nutrientName: String; let value: Double?; let unitName: String? }

// MARK: - Gemini response models

private struct GeminiResponse: Codable { let candidates: [GeminiCandidate] }
private struct GeminiCandidate: Codable { let content: GeminiContent }
private struct GeminiContent: Codable { let parts: [GeminiPart] }
private struct GeminiPart: Codable { let text: String }
private struct GeminiVerdict: Codable { let verdict: String; let reason: String }
