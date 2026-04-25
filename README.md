# NutriGuard

A Swift/SwiftUI iOS app that tells people with conditions like diabetes or hypertension whether a specific food is okay for them, and tracks daily intake of sugar, sodium, etc.

Powered by **USDA FoodData Central** (nutrient lookup) + **Gemini AI** (personalized verdicts).

---

## Project files (only 4 Swift files)

| File | What's in it | Owner |
|---|---|---|
| `NutriGuardApp.swift` | App entry point, theme/colors, button styles | Frontend |
| `Models.swift` | Data structures (User, FoodItem, Nutrients, ChatMessage…) | Data/Logic |
| `Services.swift` | API protocols + mock implementations + sample foods | AI/API + Backend |
| `ViewModels.swift` | Screen state and business logic | Frontend + Logic |
| `Views.swift` | All UI screens and components (sectioned with `MARK:`) | Frontend |

That's it. Open `Views.swift` and use Cmd+F on `MARK: -` to jump between sections.

---

## How to open the project in Xcode

1. Open Xcode → **File → New → Project…**
2. Choose **iOS → App**, click **Next**.
3. Settings:
   - Product Name: `NutriGuard`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
4. Save the project **inside this folder** (`NutriGuard/`). It will create a `NutriGuard.xcodeproj`.
5. In Xcode's left sidebar, **delete** the auto-generated `ContentView.swift` and `NutriGuardApp.swift` files (move to trash).
6. Drag the 4 Swift files from this folder into Xcode's left sidebar:
   - `NutriGuardApp.swift`
   - `Models.swift`
   - `Services.swift`
   - `ViewModels.swift`
   - `Views.swift`
   - When prompted: ✅ Copy items if needed, ✅ Add to target NutriGuard.
7. Press ▶︎ (Cmd+R) to run on the iPhone simulator.

The app will boot into the onboarding flow → main tabs (Home / Ask / Log / Profile).

---

## Team handoff — where to plug things in

Everything goes through the protocols in `Services.swift`. Replace the mock with the real implementation and inject it where the ViewModel is created in `NutriGuardApp.swift`.

### AI / API teammate
- Replace `MockUSDAService` → real USDA FoodData Central calls.
  - Endpoint: `https://api.nal.usda.gov/fdc/v1/foods/search`
- Replace `MockAIService` → real Gemini API call.
  - Build the prompt from `AIQueryContext` (question + conditions + today's totals + limits).
  - Parse Gemini's response into a `FoodVerdict` (level + reason + detected food).
- Put your API keys in a new `Secrets.swift` file (already gitignored — won't be pushed).

### Data / Logic teammate
- Tweak `NutrientLimits.defaultAdult` based on conditions (e.g. diabetic should have lower sugar limit).
- Improve verdict logic if the AI isn't enough on its own.

### Backend / DB lead
- Replace `InMemoryDataStore` with persistent storage (SwiftData, CoreData, or Firebase).
- Manage the GitHub board / issues for everyone.

### Frontend (me)
- All UI lives in `Views.swift`, themed via `NGTheme` in `NutriGuardApp.swift`.

---

## Why is `.gitignore` here?

It tells git which files **not** to push to GitHub. We need it so:
- Xcode build junk (`DerivedData/`, `xcuserdata/`) doesn't pollute the repo.
- macOS's `.DS_Store` files don't get committed.
- **API keys** (`Secrets.swift`, `.env`) stay private — never pushed where someone could steal them.

Don't delete it.
