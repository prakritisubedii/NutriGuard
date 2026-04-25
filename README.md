# NutriGuard

A Swift / SwiftUI iOS app that tells people with conditions like diabetes or
hypertension whether a specific food is okay for them, and tracks daily intake
of sugar, sodium, and calories.

Powered by **USDA FoodData Central** (nutrient lookup) + **Gemini AI**
(personalized verdicts).

---

## Project structure

The Xcode project is already set up. All Swift code lives in
`NutriGuard_App/` as a flat folder — no subdirectories, on purpose, so nobody
has to hunt for files.

| File | What's in it | Owner |
|---|---|---|
| `NutriGuard_AppApp.swift` | App entry point (`@main`) | Frontend |
| `ContentView.swift` | Root `TabView` (Ask / Today / Profile) | Frontend |
| `HomeView.swift` | "Can I eat ___?" question + verdict card | Frontend |
| `TrackerView.swift` | Today's intake — progress rings + log | Frontend |
| `ProfileView.swift` | Conditions, name, daily limits | Frontend |
| `Models.swift` | Shared data structures (`UserProfile`, `Nutrients`, `FoodEntry`, `FoodCheckResult`, `HealthCondition`) | Data / Logic |
| `Services.swift` | Service protocols + `AppState` + mock implementations | AI/API + Backend |

**Tip:** Open `Services.swift` first — it has a banner at the top showing
exactly which mock each teammate replaces.

---

## How to open and run

1. Double-click `NutriGuard_App.xcodeproj` (in the project root).
2. In the top toolbar, pick any iPhone simulator.
3. Press ▶︎ (or Cmd+R).

The Xcode project uses *synchronized file groups*, which means **any new `.swift`
file you drop into `NutriGuard_App/` is automatically added to the build** — no
manual "Add to target" step.

---

## Team handoff — where to plug things in

The UI never talks to APIs or storage directly. It only talks to the three
protocols in `Services.swift`. Replace a mock with a real implementation and
the UI keeps working unchanged.

### AI / API teammate
- Replace `MockFoodCheckService` in `Services.swift`.
- Implement `FoodCheckService.check(question:profile:todaysIntake:)`:
  1. Use **USDA FoodData Central** to look up nutrients.
     Endpoint: `https://api.nal.usda.gov/fdc/v1/foods/search`
  2. Build a Gemini prompt from the user's question + their conditions +
     today's running totals + their daily limits.
  3. Parse Gemini's response into a `FoodCheckResult`
     (`verdict`, `reason`, `nutrients`, `servingDescription`).
- Put API keys in a new `Secrets.swift` file — `.gitignore` already excludes
  it so you can't accidentally push them.

### Data / Logic teammate
- Tune defaults in `UserProfile` (`dailySugarLimitG`, `dailySodiumLimitMg`,
  `dailyCalorieLimit`) based on which conditions the user has.
- Add new fields to `Nutrients` / `FoodEntry` / `HealthCondition` as needed.
- Extend the totals math in `AppState` if we want weekly trends, etc.

### Backend / DB lead
- Replace `UserDefaultsProfileStore` with persistent storage (SwiftData,
  CoreData, or a server) — implements `ProfileStore`.
- Replace `InMemoryFoodTracker` (currently wipes on every app launch) —
  implements `FoodTracker`.
- Wire your real implementations into `AppState`'s initializer in
  `Services.swift` (or pass them in from `ContentView`).
- Manage the GitHub Project board and issues.

### Frontend (Ahmed)
- All UI lives in the `*View.swift` files.
- The shared `AppState` (in `Services.swift`) is injected via
  `.environmentObject` from `ContentView`.

---

## What's mocked right now

So the app runs end-to-end while everyone builds in parallel, three things in
`Services.swift` are placeholders:

1. **`MockFoodCheckService`** — keyword-matches the question (`"milk"`,
   `"mac"`, `"salad"`, etc.) and returns a hardcoded verdict. Replace with
   real Gemini + USDA.
2. **`UserDefaultsProfileStore`** — uses iOS `UserDefaults`. Works, but a
   real DB is better long-term.
3. **`InMemoryFoodTracker`** — holds entries in an array; **resets on every
   launch**. Replace with persistent storage.

Each one has a comment above it saying who's responsible for replacing it.

---

## Why is `.gitignore` here?

It tells git which files **not** to push to GitHub:

- Xcode build junk (`DerivedData/`, `build/`, `*.dSYM`).
- Per-developer Xcode state (`xcuserdata/`, `*.xcuserstate`) — without this,
  every time someone opens the project Xcode rewrites these files and you
  get merge conflicts.
- macOS noise (`.DS_Store`).
- **API keys** (`Secrets.swift`, `.env`, `GoogleService-Info.plist`) — must
  never be pushed where a stranger could grab them.

**Don't delete `.gitignore`.**
