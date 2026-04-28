//
//  ContentView.swift
//  NutriGuard_App
//
//  Root tab container.
//  Tab order: Health (default) · Ask AI · Profile
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Health", systemImage: "waveform.path.ecg") }

            HomeView()
                .tabItem { Label("Ask AI", systemImage: "sparkles") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(.green)
    }
}

@MainActor
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(AuthState())
    }
}
