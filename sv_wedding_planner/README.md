# SV Wedding Planner — The AI Wedding Operating System

A premium **Flutter** app for **Android & iOS** (and web) that plans an Indian
wedding end-to-end. It is not a static checklist — a **Wedding Knowledge
Engine** filters a large master task base down to a personalized roadmap of
~150–200 actionable items, then a **dependency-aware timeline engine**
schedules them against your wedding date.

Pre-loaded with the demo configuration from the brief:
**Vaishnav Wanjari & Shefali Verma · Wedding 25 Nov 2026 · Reception 29 Nov ·
Honeymoon early Dec · Maharashtrian Hindu wedding.**

## 🌐 Live web app

The app is deployed to GitHub Pages on every push:

**https://vaishnavwanjari.github.io/Cautious/**

> First-time activation (repo owner, one click): **Settings → Pages → Source:
> "Deploy from a branch" → Branch: `gh-pages` / `(root)`**. The
> `Deploy SV Wedding Planner (Web)` workflow creates the `gh-pages` branch and
> the site goes live within a minute of the next push.

Native **Android APK** is built and uploaded as a CI artifact on every push
(Actions → latest run → Artifacts → `sv-wedding-planner-apk`).

---

## What's implemented

| Area | Status |
|------|--------|
| Wedding Knowledge Engine (rich task metadata + JSON seed) | ✅ |
| AI personalization funnel (persona → religion → community → style → bookings → AI rank) | ✅ |
| Dependency-aware timeline engine (cascading schedule) | ✅ |
| Conversational onboarding with **live** task-count preview | ✅ |
| Premium dashboard: countdowns, progress ring, funnel strip, today's priorities | ✅ |
| Budget manager with pie chart + planned-vs-actual per category | ✅ |
| Vendor management (contracts, payments, ratings, booked status) | ✅ |
| Shopping planner grouped by person | ✅ |
| Guests & family with RSVP + seat tracking | ✅ |
| Honeymoon planner with destination suggestions & checklist | ✅ |
| **Proactive AI Insights engine** (overdue, critical-path risk, blocked dependencies, budget overspend, unbooked vendors, pending payments) | ✅ |
| **Reminders agenda** derived from the timeline (overdue-first, grouped by month) | ✅ |
| AI Wedding Copilot (offline, rule-based; LLM-swappable) | ✅ |
| Offline-first persistence (shared_preferences) | ✅ |
| Material 3 theme, light + dark | ✅ |
| Unit tests for both engines + CI (analyze, test, build APK & web) | ✅ |

> Scope note: the seed knowledge base ships a curated, richly-tagged subset of
> tasks covering every ceremony and category. The engine and data layer are
> source-agnostic — swapping `KnowledgeBase` for a Firestore-backed source
> scales it to the full 10,000–15,000 atomic tasks without touching the UI.

---

## Architecture

Clean, layered, MVVM-ish with Riverpod:

```
lib/
  models/       WeddingProfile, WeddingTask (rich metadata), Vendor/Budget/Shopping/Guest, enums
  data/         KnowledgeBase (asset loader), LocalStore (persistence), SeedData (demo config)
  engine/       PersonalizationEngine, TimelineEngine, InsightsEngine, ReminderEngine, CopilotEngine
  state/        Riverpod providers (profile, roadmap, budget, vendors, …)
  core/         theme, formatting
  widgets/      shared UI
  features/     onboarding, dashboard, tasks, budget, more, modules, copilot
assets/data/    wedding_tasks.json  (the knowledge-engine seed)
test/           engine_test.dart
```

**Data flow:** `masterTasksProvider` (knowledge base) → `PersonalizationEngine`
(filters to your profile) → `TimelineEngine` (schedules with dependencies) →
`roadmapProvider` → screens. Changing the profile in onboarding regenerates the
whole roadmap automatically.

---

## Run it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.19+). Platform folders are generated on demand, not committed.

```bash
cd sv_wedding_planner
flutter create --platforms=android,ios,web .   # generates android/ios/web scaffolding
flutter pub get
flutter run                                     # pick an Android/iOS device or Chrome
```

Build release binaries:

```bash
flutter build apk        # Android
flutter build ios        # iOS (on macOS, then archive in Xcode)
flutter build web        # Web
```

CI (`.github/workflows/sv-wedding-planner.yml`) analyzes, tests, and builds the
APK + web bundle on every push, and uploads the APK as an artifact.

---

## Roadmap (designed for, not yet built)

Firebase Auth/Firestore/Storage sync · real LLM Copilot · vendor marketplace ·
digital invitation builder · AR venue preview · multi-user collaboration roles ·
**OS push notifications** (the reminder agenda already exists in-app; wiring it to
`flutter_local_notifications`/FCM needs native config — Android core-library
desugaring + an FCM project) · PDF/Excel report export.
