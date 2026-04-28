//
//  ParseService.swift
//  NutriGuard_App
//
//  Parse-Swift model for the logged-in user.
//  Session persistence is handled automatically by the SDK (Keychain).
//

import Foundation
import ParseSwift

// MARK: - Parse User model

struct NutriUser: ParseUser {
    // Required ParseUser fields
    var objectId:      String?
    var createdAt:     Date?
    var updatedAt:     Date?
    var ACL:           ParseACL?
    var originalData:  Data?
    var username:      String?
    var email:         String?
    var emailVerified: Bool?
    var password:      String?
    var authData:      [String: [String: String]?]?

    // Custom profile fields stored on the User object
    var displayName:        String?
    var conditions:         [String]?
    var dailySugarLimitG:   Double?
    var dailySodiumLimitMg: Double?
    var dailyCalorieLimit:  Double?

    // MARK: Convenience

    func toProfile() -> UserProfile {
        var p = UserProfile()
        p.name               = displayName ?? ""
        p.conditions         = Set((conditions ?? []).compactMap(HealthCondition.init(rawValue:)))
        p.dailySugarLimitG   = dailySugarLimitG   ?? 50
        p.dailySodiumLimitMg = dailySodiumLimitMg ?? 2300
        p.dailyCalorieLimit  = dailyCalorieLimit  ?? 2000
        return p
    }
}
