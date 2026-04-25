//
//  Models.swift
//  NutriGuard_App
//
//  Shared data models used across the app.
//  Owned by: Data & Logic teammate.
//  The UI reads/writes these via the protocols in Services.swift.
//

import Foundation
import SwiftUI

// MARK: - Health Conditions

/// Conditions the user can have. Add more here as the team agrees on scope.
enum HealthCondition: String, CaseIterable, Identifiable, Codable, Hashable {
    case diabetes       = "Diabetes"
    case hypertension   = "Hypertension"
    case highCholesterol = "High Cholesterol"
    case kidneyDisease  = "Kidney Disease"
    case celiac         = "Celiac (Gluten-Free)"
    case lactoseIntolerance = "Lactose Intolerance"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .diabetes:           return "drop.fill"
        case .hypertension:       return "heart.fill"
        case .highCholesterol:    return "waveform.path.ecg"
        case .kidneyDisease:      return "cross.case.fill"
        case .celiac:             return "leaf.fill"
        case .lactoseIntolerance: return "cup.and.saucer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .diabetes:           return .red
        case .hypertension:       return .pink
        case .highCholesterol:    return .orange
        case .kidneyDisease:      return .purple
        case .celiac:             return .green
        case .lactoseIntolerance: return .brown
        }
    }
}

// MARK: - User Profile

/// Persisted user profile. Backend/DB lead is responsible for persistence;
/// for now it lives in @AppStorage / in-memory (see Services.swift).
struct UserProfile: Codable, Equatable {
    var name: String = ""
    var conditions: Set<HealthCondition> = []

    /// Daily limits the tracker compares against.
    /// Defaults are reasonable adult values; data teammate can tune per condition.
    var dailySugarLimitG: Double   = 50
    var dailySodiumLimitMg: Double = 2300
    var dailyCalorieLimit: Double  = 2000
}

// MARK: - Food / Nutrients

/// Nutrient breakdown for a single food item (per serving).
/// Mirrors the subset of USDA fields we care about.
struct Nutrients: Codable, Equatable, Hashable {
    var calories: Double = 0
    var sugarG: Double   = 0
    var sodiumMg: Double = 0
    var carbsG: Double   = 0
    var fatG: Double     = 0
    var proteinG: Double = 0
}

/// A logged food entry in the daily tracker.
struct FoodEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var servingDescription: String  // e.g. "1 cup (240ml)"
    var nutrients: Nutrients
    var loggedAt: Date = Date()
}

// MARK: - AI Verdict

/// The verdict shown on the Home screen after asking "Can I eat ___?"
struct FoodCheckResult: Identifiable, Equatable {
    enum Verdict: String, Equatable {
        case yes      // safe
        case caution  // OK in moderation
        case no       // avoid

        var label: String {
            switch self {
            case .yes:     return "Yes"
            case .caution: return "Caution"
            case .no:      return "No"
            }
        }

        var color: Color {
            switch self {
            case .yes:     return .green
            case .caution: return .orange
            case .no:      return .red
            }
        }

        var icon: String {
            switch self {
            case .yes:     return "checkmark.circle.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .no:      return "xmark.octagon.fill"
            }
        }
    }

    let id: UUID = UUID()
    let foodName: String
    let verdict: Verdict
    /// Personalized, human-readable explanation from the AI.
    let reason: String
    /// Nutrients used to make the call (so we can also log the food if user accepts).
    let nutrients: Nutrients
    /// Suggested serving description matching `nutrients`.
    let servingDescription: String
}
