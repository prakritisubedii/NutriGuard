//
//  DashboardView.swift
//  NutriGuard_App
//
//  Default landing screen. Shows blood sugar trend, quick-log actions,
//  and today's nutrition summary.
//

import SwiftUI
import Charts

// MARK: - Main View

struct DashboardView: View {
    @EnvironmentObject private var state: AppState

    @State private var showBloodSugarSheet = false
    @State private var showFoodSheet       = false
    @State private var showCalendarSheet   = false
    @State private var showAnalyzeSheet    = false
    @State private var chartRange: ChartRange = .week

    enum ChartRange: String, CaseIterable {
        case day = "24 h", week = "7 d", month = "30 d"
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    greetingSection
                    bloodSugarCard
                    quickActions
                    nutritionCard
                    foodLogSection
                    analyzeButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("LogoWithText")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 110)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCalendarSheet = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .sheet(isPresented: $showBloodSugarSheet) {
            BloodSugarEntrySheet { state.logBloodSugar($0) }
        }
        .sheet(isPresented: $showFoodSheet) {
            QuickFoodEntrySheet { state.log($0) }
        }
        .sheet(isPresented: $showCalendarSheet) {
            CalendarPickerSheet(selectedDate: $state.selectedDate)
        }
        .sheet(isPresented: $showAnalyzeSheet) {
            AnalyzeReportSheet()
        }
    }

    // MARK: - Sections

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeGreeting)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Text(state.profile.name.isEmpty ? "Welcome" : state.profile.name)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var bloodSugarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                Text("Blood Sugar")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                if let latest = displayedEntries.last {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(latest.category.color)
                            .frame(width: 8, height: 8)
                        Text("\(Int(latest.level)) mg/dL")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(latest.category.color)
                        Text(latest.category.label)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Chart or empty state
            if displayedEntries.isEmpty {
                bloodSugarEmptyState
            } else {
                bloodSugarChart
            }

            // Range picker
            Picker("Range", selection: $chartRange) {
                ForEach(ChartRange.allCases, id: \.self) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bloodSugarEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop")
                .font(.system(size: 36))
                .foregroundStyle(Color(.tertiaryLabel))
            Text("No readings yet")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Tap Log Blood Sugar below to add your first reading.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var bloodSugarChart: some View {
        Group {
            if chartRange == .day {
                bloodSugarChart24h
            } else {
                bloodSugarChartRange
            }
        }
    }

    /// 24h: individual data points with time labels like "7:00 AM"
    private var bloodSugarChart24h: some View {
        Chart {
            RectangleMark(yStart: .value("Low", 70), yEnd: .value("High", 100))
                .foregroundStyle(Color.green.opacity(0.07))
            RuleMark(y: .value("Low threshold", 70))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.green.opacity(0.5))
            RuleMark(y: .value("High threshold", 126))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.orange.opacity(0.5))

            ForEach(displayedEntries) { entry in
                LineMark(x: .value("Time", entry.recordedAt), y: .value("mg/dL", entry.level))
                    .foregroundStyle(Color(.label).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Time", entry.recordedAt), y: .value("mg/dL", entry.level))
                    .foregroundStyle(entry.category.color)
                    .symbolSize(48)
            }
        }
        .chartYScale(domain: 50...260)
        .chartYAxis {
            AxisMarks(values: [70, 100, 126, 180, 250]) { _ in
                AxisGridLine().foregroundStyle(Color(.systemFill))
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Color(.systemFill))
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(height: 180)
    }

    /// 7d / 30d: daily high-low range bars
    private var bloodSugarChartRange: some View {
        let ranges = dailyRanges
        let xFormat: Date.FormatStyle = chartRange == .week
            ? .dateTime.weekday(.abbreviated)
            : .dateTime.month(.abbreviated).day()

        return Chart {
            RectangleMark(yStart: .value("Low", 70), yEnd: .value("High", 100))
                .foregroundStyle(Color.green.opacity(0.07))
            RuleMark(y: .value("Low threshold", 70))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.green.opacity(0.5))
            RuleMark(y: .value("High threshold", 126))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.orange.opacity(0.5))

            ForEach(ranges) { r in
                // Vertical range line
                RuleMark(x: .value("Day", r.date),
                         yStart: .value("Low", r.low),
                         yEnd: .value("High", r.high))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color(.label).opacity(0.3))

                // High point
                PointMark(x: .value("Day", r.date), y: .value("mg/dL", r.high))
                    .foregroundStyle(r.highCat.color)
                    .symbolSize(48)
                // Low point
                PointMark(x: .value("Day", r.date), y: .value("mg/dL", r.low))
                    .foregroundStyle(r.lowCat.color)
                    .symbolSize(48)
            }
        }
        .chartYScale(domain: 50...260)
        .chartYAxis {
            AxisMarks(values: [70, 100, 126, 180, 250]) { _ in
                AxisGridLine().foregroundStyle(Color(.systemFill))
                AxisValueLabel()
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: chartRange == .week ? 7 : 6)) { _ in
                AxisGridLine().foregroundStyle(Color(.systemFill))
                AxisValueLabel(format: xFormat)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(height: 180)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                title: "Log Blood Sugar",
                subtitle: "Record a reading",
                icon: "drop.fill",
                iconColor: Color(red: 0.94, green: 0.27, blue: 0.27)
            ) { showBloodSugarSheet = true }

            QuickActionCard(
                title: "Log Food",
                subtitle: "Quick entry",
                icon: "fork.knife",
                iconColor: Color.green
            ) { showFoodSheet = true }
        }
    }

    private var nutritionCard: some View {
        let selectedEntries = state.entriesForSelectedDate()
        let selectedTotals  = state.totalsForSelectedDate()
        let isToday = Calendar.current.isDateInToday(state.selectedDate)
        let isYesterday = Calendar.current.isDateInYesterday(state.selectedDate)
        let dateLabel: String = isToday ? "Today's Intake"
            : isYesterday ? "Yesterday's Intake"
            : state.selectedDate.formatted(.dateTime.month(.wide).day())

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(dateLabel)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Spacer()
                Text("\(selectedEntries.count) item\(selectedEntries.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if selectedEntries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color(.tertiaryLabel))
                    Text("No food logged for this date.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                // Rings
                HStack(spacing: 0) {
                    DashRing(label: "Sugar",
                             value: selectedTotals.sugarG,
                             limit: state.profile.dailySugarLimitG,
                             unit: "g", color: .pink)
                    DashRing(label: "Sodium",
                             value: selectedTotals.sodiumMg,
                             limit: state.profile.dailySodiumLimitMg,
                             unit: "mg", color: .orange)
                    DashRing(label: "Calories",
                             value: selectedTotals.calories,
                             limit: state.profile.dailyCalorieLimit,
                             unit: "kcal", color: .green)
                }

                // Macros
                HStack(spacing: 12) {
                    DashMacro(label: "Carbs",   grams: selectedTotals.carbsG,   color: .blue)
                    DashMacro(label: "Fat",     grams: selectedTotals.fatG,     color: .yellow)
                    DashMacro(label: "Protein", grams: selectedTotals.proteinG, color: .purple)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Food Log List

    private var foodLogSection: some View {
        let entries = state.entriesForSelectedDate()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Food Log")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if entries.isEmpty {
                Text("No entries for this date.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                            Text("\(entry.servingDescription) · \(Int(entry.nutrients.calories)) kcal")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.loggedAt, style: .time)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Label("\(Int(entry.nutrients.sugarG))g", systemImage: "drop.fill")
                                    .foregroundStyle(.pink)
                                Label("\(Int(entry.nutrients.sodiumMg))mg", systemImage: "circle.grid.cross.fill")
                                    .foregroundStyle(.orange)
                            }
                            .font(.system(.caption2, design: .rounded))
                            .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(.vertical, 6)
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Analyze Button

    private var analyzeButton: some View {
        Button { showAnalyzeSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(.title3, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Analyze My Day")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text("AI-powered insights & meal suggestions")
                        .font(.system(.caption2, design: .rounded))
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
            }
            .padding(16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color.green, Color(red: 0.1, green: 0.6, blue: 0.4)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var timeGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning," }
        if h < 17 { return "Good afternoon," }
        return "Good evening,"
    }

    private var displayedEntries: [BloodSugarEntry] {
        let now = Date()
        let cutoff: Date
        switch chartRange {
        case .day:   cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        case .week:  cutoff = Calendar.current.date(byAdding: .day,  value: -7,  to: now)!
        case .month: cutoff = Calendar.current.date(byAdding: .day,  value: -30, to: now)!
        }
        return state.bloodSugarEntries
            .filter { $0.recordedAt >= cutoff }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// For 7d/30d: compute daily high and low pairs
    private struct DailyRange: Identifiable {
        let id = UUID()
        let date: Date      // noon of that day (common x-axis position)
        let high: Double
        let low: Double
        let highCat: BloodSugarEntry.Category
        let lowCat: BloodSugarEntry.Category
    }

    private var dailyRanges: [DailyRange] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: displayedEntries) { entry in
            cal.startOfDay(for: entry.recordedAt)
        }
        return grouped.map { (day, entries) in
            let sorted = entries.sorted { $0.level < $1.level }
            let lo = sorted.first!
            let hi = sorted.last!
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            return DailyRange(date: noon, high: hi.level, low: lo.level,
                              highCat: hi.category, lowCat: lo.category)
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Supporting Views

private struct QuickActionCard: View {
    let title:     String
    let subtitle:  String
    let icon:      String
    let iconColor: Color
    let action:    () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct DashRing: View {
    let label: String
    let value: Double
    let limit: Double
    let unit:  String
    let color: Color

    private var progress: Double { limit > 0 ? min(value / limit, 1.0) : 0 }
    private var over: Bool { limit > 0 && value > limit }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(over ? Color.red : color,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 66, height: 66)

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            Text("/ \(Int(limit))\(unit)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(over ? Color.red : Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}

struct DashMacro: View {
    let label: String
    let grams: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))g")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Blood Sugar Entry Sheet

struct BloodSugarEntrySheet: View {
    let onSave: (BloodSugarEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var levelText = ""
    @State private var context: BloodSugarEntry.MealContext = .fasting

    private var level: Double? {
        guard let d = Double(levelText), d > 0 else { return nil }
        return d
    }

    private func category(for lvl: Double) -> BloodSugarEntry.Category {
        if lvl < 70  { return .low }
        if lvl < 100 { return .normal }
        if lvl < 126 { return .elevated }
        return .high
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero number display
                VStack(spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(levelText.isEmpty ? "—" : levelText)
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(level.map { category(for: $0).color } ?? Color(.tertiaryLabel))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.2), value: levelText)
                        Text("mg/dL")
                            .font(.system(.title3, design: .rounded, weight: .regular))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)
                    }
                    if let l = level {
                        let cat = category(for: l)
                        Text(cat.label)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(cat.color)
                    } else {
                        Text("Enter value below")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(.secondarySystemGroupedBackground))

                // Hint bar
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("Normal fasting: 70–99 mg/dL  ·  After meal < 140 mg/dL")
                }
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                Form {
                    Section("Reading (mg/dL)") {
                        TextField("e.g. 95", text: $levelText)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .rounded))
                    }
                    Section("When measured") {
                        Picker("Context", selection: $context) {
                            ForEach(BloodSugarEntry.MealContext.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Log Blood Sugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let l = level else { return }
                        onSave(BloodSugarEntry(level: l, context: context))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(level == nil)
                }
            }
        }
    }
}

// MARK: - Quick Food Entry Sheet

struct QuickFoodEntrySheet: View {
    let onSave: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var foodName    = ""
    @State private var caloriesText = ""

    private var isValid: Bool {
        !foodName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Oatmeal with banana", text: $foodName)
                        .font(.system(.body, design: .rounded))
                        .autocorrectionDisabled()
                } header: {
                    Text("What did you eat or drink?")
                }

                Section {
                    HStack {
                        TextField("Optional", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .rounded))
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text("Leave blank if unknown. For detailed analysis, use the Ask tab.")
                        .font(.system(.caption, design: .rounded))
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cal = Double(caloriesText) ?? 0
                        let entry = FoodEntry(
                            name: foodName.trimmingCharacters(in: .whitespaces),
                            servingDescription: "1 serving",
                            nutrients: Nutrients(calories: cal)
                        )
                        onSave(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Calendar Picker Sheet

struct CalendarPickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Select Date",
                           selection: $selectedDate,
                           in: ...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.green)
                    .padding()
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Analyze Report Sheet

struct AnalyzeReportSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if state.isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                        Text("Analyzing your health data…")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else if let report = state.lastAnalysis {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary
                        Text(report.summary)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)

                        // Good habits
                        if !report.goodHabits.isEmpty {
                            AnalyzeSection(title: "What You're Doing Well",
                                           icon: "checkmark.circle.fill",
                                           iconColor: .green,
                                           items: report.goodHabits)
                        }

                        // Bad habits
                        if !report.badHabits.isEmpty {
                            AnalyzeSection(title: "Areas to Improve",
                                           icon: "exclamationmark.triangle.fill",
                                           iconColor: .orange,
                                           items: report.badHabits)
                        }

                        // Suggestions
                        if !report.suggestions.isEmpty {
                            AnalyzeSection(title: "Suggestions",
                                           icon: "lightbulb.fill",
                                           iconColor: .yellow,
                                           items: report.suggestions)
                        }

                        // Meal plan
                        if !report.mealPlan.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Recommended Meals", systemImage: "fork.knife.circle.fill")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.green)
                                Text(report.mealPlan)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("Tap the button below to generate your personalized health analysis.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 32)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Health Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        Task { await state.runAnalysis() }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(state.lastAnalysis == nil ? "Generate Analysis" : "Re-analyze")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(state.isAnalyzing)
                }
            }
        }
    }
}

private struct AnalyzeSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(iconColor)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(item)
                        .font(.system(.subheadline, design: .rounded))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview

@MainActor
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView().environmentObject(AppState())
    }
}
