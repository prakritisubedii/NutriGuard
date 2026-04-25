//
//  ContentView.swift
//  NutriGuard_App
//
//  Root tab container. Three tabs: Ask, Today, Profile.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var state = AppState()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Ask", systemImage: "text.bubble.fill") }

            TrackerView()
                .tabItem { Label("Today", systemImage: "chart.pie.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(.green)
        .environmentObject(state)
    }
}

#Preview {
    ContentView()
}
