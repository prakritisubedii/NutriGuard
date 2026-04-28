//
//  TrackerView.swift
//  NutriGuard_App
//
//  Today's intake. Shows progress vs. the user's daily limits and a list of
//  what they've logged.
//

import SwiftUI

struct TrackerView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Logged today") {
                    if state.entries.isEmpty {
                        ContentUnavailableView(
                            "Nothing logged yet",
                            systemImage: "fork.knife",
                            description: Text("Ask about a food on the Ask tab and tap “Log this food.”")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(state.entries) { entry in
                            EntryRow(entry: entry)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { state.remove(state.entries[i]) }
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
    }

    // MARK: Summary

    private var summaryCard: some View {
        let totals = state.totals
        let p = state.profile
        return VStack(spacing: 14) {
            HStack {
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(state.entries.count) item\(state.entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                LimitRing(label: "Sugar",
                          value: totals.sugarG,
                          limit: p.dailySugarLimitG,
                          unit: "g",
                          color: .pink)
                LimitRing(label: "Sodium",
                          value: totals.sodiumMg,
                          limit: p.dailySodiumLimitMg,
                          unit: "mg",
                          color: .orange)
                LimitRing(label: "Calories",
                          value: totals.calories,
                          limit: p.dailyCalorieLimit,
                          unit: "kcal",
                          color: .green)
            }

            HStack(spacing: 16) {
                MacroBadge(label: "Carbs", grams: totals.carbsG, color: .blue)
                MacroBadge(label: "Fat", grams: totals.fatG, color: .yellow)
                MacroBadge(label: "Protein", grams: totals.proteinG, color: .purple)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Subviews

private struct LimitRing: View {
    let label: String
    let value: Double
    let limit: Double
    let unit: String
    let color: Color

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(value / limit, 1.0)
    }

    private var over: Bool { limit > 0 && value > limit }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(over ? Color.red : color,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.headline)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("of \(Int(limit))\(unit)")
                .font(.caption2)
                .foregroundStyle(over ? .red : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MacroBadge: View {
    let label: String
    let grams: Double
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))g")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EntryRow: View {
    let entry: FoodEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body)
                Text("\(entry.servingDescription) · \(Int(entry.nutrients.calories)) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.loggedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label("\(Int(entry.nutrients.sugarG))g", systemImage: "drop.fill")
                        .foregroundStyle(.pink)
                    Label("\(Int(entry.nutrients.sodiumMg))mg", systemImage: "circle.grid.cross.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption2)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
struct TrackerView_Previews: PreviewProvider {
    static var previews: some View {
        TrackerView().environmentObject(AppState())
    }
}
