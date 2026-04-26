# NutriGuard

## Table of Contents

1. [Overview](#overview)
2. [Product Spec](#product-spec)
3. [Wireframes](#wireframes)
4. [chema](#schema)

---

## Overview

### Description

NutriGuard is a Swift / SwiftUI iOS app that helps users with health conditions like diabetes or hypertension decide whether a food is safe for them to eat. Users can ask about a specific food, receive a personalized verdict, and track daily intake of sugar, sodium, and calories.

The app uses USDA FoodData Central for nutrient lookup and Gemini AI for personalized food recommendations.

---

### App Evaluation

**Category:** Health / Nutrition / Lifestyle

**Mobile:**  
NutriGuard is designed as a mobile iOS app. Since users often need quick food guidance while shopping, cooking, or eating out, mobile access is important.

**Story:**  
The app helps users make safer food choices based on their personal health needs. Instead of only showing nutrition facts, NutriGuard explains whether a food fits the user's condition and daily limits.

**Market:**  
The target audience includes people managing conditions such as diabetes, hypertension, or general diet-related health goals. It can also help caregivers or family members who prepare food for others.

**Habit:**  
NutriGuard is intended for daily use. Users can check foods before eating and track their intake throughout the day.

**Scope:**  
The app has a narrow but useful scope. The main features are food checking, personalized health verdicts, profile setup, and daily nutrition tracking.

---

## Product Spec

### 1. User Stories

#### Required Must-have Stories

- User can enter a food question such as "Can I eat mac and cheese?"
- User can receive a verdict explaining whether the food is okay for them.
- User can view sugar, sodium, and calorie information for a food.
- User can track today's sugar, sodium, and calorie intake.
- User can view daily progress toward nutrition limits.
- User can set or update their profile information.
- User can select health conditions such as diabetes or hypertension.
- User can set daily limits for sugar, sodium, and calories.

#### Optional Nice-to-have Stories

- User can save food entries across app sessions.
- User can view weekly or monthly nutrition trends.
- User can scan a barcode to look up food.
- User can save favorite foods.
- User can receive warning notifications when close to a daily limit.
- User can get healthier food alternatives from AI.
- User can share a food report with a doctor or caregiver.

---

### 2. Screen Archetypes

#### Home / Ask Screen

- User can ask whether a food is safe to eat.
- User can view an AI-generated verdict.
- User can view the reason behind the verdict.
- User can see nutrient details for the food.

#### Today / Tracker Screen

- User can view today's logged food entries.
- User can see total sugar, sodium, and calories consumed.
- User can view progress toward daily limits.

#### Profile Screen

- User can enter their name.
- User can select health conditions.
- User can update daily nutrition limits.
- User can save profile settings.

---

### 3. Navigation

#### Tab Navigation

- **Ask:** Main food question and verdict screen.
- **Today:** Daily intake tracker screen.
- **Profile:** User health profile and limit settings screen.

#### Flow Navigation

**Ask Screen**
- User enters a food question.
- Leads to verdict result card on the same screen.
- User can add checked food to today's tracker.

**Today Screen**
- User views daily nutrition totals.
- User can review logged foods.

**Profile Screen**
- User edits conditions and daily limits.
- Leads back to Ask or Today with updated profile data.

---

## Wireframes

<img width="600" height="600" alt="Screenshot1" src="https://github.com/user-attachments/assets/c1f8248d-22ab-4762-aa37-d31e4ddadddf" />



<img width="652" height="1216" alt="Screenshot2" src="https://github.com/user-attachments/assets/0b4c1237-456c-4673-892f-7f70fb7756b4" />



<img width="568" height="1186" alt="Screenshot3" src="https://github.com/user-attachments/assets/cbb97d78-f4c6-4bf1-b8ac-2500df2d4337" />


### Required Screens to Sketch

1. Ask Screen
2. Today / Tracker Screen
3. Profile Screen

---

## [BONUS] Digital Wireframes & Mockups

[Add digital wireframes or mockups here if completed.]

---

## [BONUS] Interactive Prototype

[Add interactive prototype link here if completed.]

---

## Schema

### Models

#### UserProfile

| Property | Type | Description |
|---|---|---|
| name | String | User's name |
| conditions | Array | Health conditions selected by the user |
| dailySugarLimitG | Double | User's daily sugar limit in grams |
| dailySodiumLimitMg | Double | User's daily sodium limit in milligrams |
| dailyCalorieLimit | Double | User's daily calorie limit |

#### HealthCondition

| Property | Type | Description |
|---|---|---|
| name | String | Name of the health condition |
| description | String | Short explanation of the condition |

#### Nutrients

| Property | Type | Description |
|---|---|---|
| sugarG | Double | Sugar amount in grams |
| sodiumMg | Double | Sodium amount in milligrams |
| calories | Double | Calories in the food |

#### FoodEntry

| Property | Type | Description |
|---|---|---|
| foodName | String | Name of the logged food |
| servingDescription | String | Serving size or portion description |
| nutrients | Nutrients | Nutrient values for the food |
| date | Date | Date the food was logged |

#### FoodCheckResult

| Property | Type | Description |
|---|---|---|
| verdict | String | Result such as safe, caution, or avoid |
| reason | String | Explanation for the verdict |
| nutrients | Nutrients | Nutrient information for the food |
| servingDescription | String | Serving size used for the result |

---

## Networking

### Ask Screen

- `[GET] USDA FoodData Central /foods/search`
  - Used to search for food nutrition data.
  - Example endpoint:
    `https://api.nal.usda.gov/fdc/v1/foods/search`

- `[POST] Gemini AI request`
  - Sends the user's food question, health conditions, daily limits, and current intake.
  - Receives a personalized verdict and explanation.

### Today / Tracker Screen

- No external network request required if using local storage.
- Optional future backend:
  - `[GET] /foodEntries`
  - `[POST] /foodEntries`
  - `[DELETE] /foodEntries/:id`

### Profile Screen

- No external network request required if using local storage.
- Optional future backend:
  - `[GET] /profile`
  - `[POST] /profile`
  - `[PUT] /profile`

---

## API Request Snippets

### USDA Food Search

```swift
GET https://api.nal.usda.gov/fdc/v1/foods/search?query=FOOD_NAME&api_key=API_KEY
