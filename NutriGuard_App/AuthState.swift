//
//  AuthState.swift
//  NutriGuard_App
//
//  Manages the user session via Parse-Swift.
//  The SDK persists the session token in the Keychain automatically —
//  no manual UserDefaults token management needed.
//

import Foundation
import SwiftUI
import Combine
import ParseSwift

@MainActor
final class AuthState: ObservableObject {

    // MARK: Published

    @Published var isLoggedIn:         Bool     = false
    @Published var isRestoringSession: Bool     = true
    @Published var isLoading:          Bool     = false
    @Published var errorMessage:       String?  = nil
    @Published var appState:           AppState? = nil

    // MARK: Init

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Session restore

    private func restoreSession() async {
        defer { isRestoringSession = false }
        guard let current = NutriUser.current else { return }
        do {
            // Refresh from server to get the latest profile fields
            let fresh = try await current.fetch()
            configure(user: fresh)
        } catch {
            // Session expired or network issue — stay on login screen
        }
    }

    // MARK: - Public auth actions

    func login(email: String, password: String) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await NutriUser.login(username: email.lowercased(),
                                                 password: password)
            configure(user: user)
        } catch {
            errorMessage = friendlyMessage(error)
        }
    }

    func signUp(email: String, password: String, name: String) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var newUser                = NutriUser()
            newUser.username           = email.lowercased()
            newUser.email              = email.lowercased()
            newUser.password           = password
            newUser.displayName        = name
            newUser.conditions         = []
            newUser.dailySugarLimitG   = 50.0
            newUser.dailySodiumLimitMg = 2300.0
            newUser.dailyCalorieLimit  = 2000.0

            let saved = try await newUser.signup()
            configure(user: saved)
        } catch {
            errorMessage = friendlyMessage(error)
        }
    }

    func logout() {
        // Fire-and-forget server call; local state clears immediately
        Task { _ = try? await NutriUser.logout() }
        appState   = nil
        isLoggedIn = false
    }

    func requestPasswordReset(email: String) async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await NutriUser.passwordReset(email: email.lowercased())
            // Success — LoginView detects nil errorMessage and shows the success state
        } catch {
            errorMessage = friendlyMessage(error)
        }
    }

    // MARK: - Private helpers

    private func configure(user: NutriUser) {
        let store = ParseProfileStore(initial: user.toProfile())
        appState   = AppState(profileStore: store)
        isLoggedIn = true
    }

    private func friendlyMessage(_ error: Error) -> String {
        // Parse error codes: 101 = invalid credentials, 202 = username taken
        let msg = error.localizedDescription
        if msg.contains("101") { return "Incorrect email or password." }
        if msg.contains("202") { return "An account with that email already exists." }
        if msg.contains("200") { return "Please enter a valid email address." }
        return msg
    }
}
