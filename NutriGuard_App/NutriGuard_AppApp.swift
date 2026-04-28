//
//  NutriGuard_AppApp.swift
//  NutriGuard_App
//

import SwiftUI
import ParseSwift

@main
struct NutriGuard_AppApp: App {
    @StateObject private var auth = AuthState()

    init() {
        ParseSwift.initialize(
            applicationId: "BfFlTTSQUSyXgvLH2G6sO7HeR1LnqF6EUHYMCUbx",
            clientKey:     "uMPdXJ4hODatIQ89qS0Kj10qGJSTnRAcB9M2iiCN",
            serverURL:     URL(string: "https://parseapi.back4app.com")!
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isRestoringSession {
                    SplashView()
                } else if auth.isLoggedIn, let appState = auth.appState {
                    ContentView()
                        .environmentObject(appState)
                        .environmentObject(auth)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: auth.isLoggedIn)
            .animation(.easeInOut(duration: 0.3), value: auth.isRestoringSession)
        }
    }
}
