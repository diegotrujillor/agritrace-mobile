# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development
flutter run                          # run on connected device / emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1   # iOS simulator

# Testing
flutter test                         # all tests
flutter test test/unit/              # unit tests only
flutter test test/widget/            # widget tests only
flutter test test/unit/auth_provider_test.dart   # single file

# Build
flutter build apk                    # Android release APK
flutter build ios                    # iOS release

# Lint / analysis
flutter analyze                      # static analysis (analysis_options.yaml)
dart fix --apply                     # auto-fix lint issues
```

## Architecture

### Layer structure (current as of v1.9.4)

```
lib/
  main.dart                  # ProviderScope + AgriTraceApp entry point
  navigation/
    app_router.dart          # GoRouter with auth redirect logic
    route_names.dart         # Route constants (Routes.welcome, .login, etc.)
  models/                    # Pure data classes (User, AuthResponse, Farm, Plot,
                             #   Activity, Alert, Upload, Feedback)
  providers/                 # Riverpod AsyncNotifier per domain
                             # (auth, farms, plots, activities, alerts, sync,
                             #  uploads, feedback)
  services/                  # Network + storage + sync (no Flutter widget deps).
                             # api_service · auth_service · storage_service ·
                             # farm/plot/activity/alert/uploads/feedback_service ·
                             # sync_orchestrator · pdf_traceability_service
  database/                  # Drift SQLite — tables.dart · app_database.dart
                             # (includes wipeAllUserData) · app_database.g.dart
  repositories/              # Drift-backed repos (Farm/Plot/Activity/Alert)
  screens/<domain>/          # One subfolder per feature domain
                             # (auth, farms, plots, activities, alerts, profile)
  widgets/
    common/                  # AppButton, AppCard, AppInput, AppLogoMark,
                             # OfflineIndicator, AppErrorBanner, SyncStatusBadge
    domain/                  # FarmCard, ActivityListItem, AlertListItem
  utils/                     # constants.dart, theme.dart, validators.dart,
                             # text_format.dart, error_parser.dart
```

### State management

Riverpod with `AsyncNotifier`. Auth state is a sealed class (`AuthUnauthenticated` | `AuthAuthenticated`). All providers are defined in `lib/providers/auth_provider.dart` for Sprint 1; Sprint 2+ adds domain providers per feature.

```dart
// Pattern for new notifiers
class XyzNotifier extends AsyncNotifier<XyzState> {
  @override Future<XyzState> build() async { ... }
}
final xyzProvider = AsyncNotifierProvider<XyzNotifier, XyzState>(XyzNotifier.new);
```

### Navigation

GoRouter (`routerProvider` in `app_router.dart`). Auth redirect runs on every navigation event: authenticated users are sent to `/dashboard`; unauthenticated users are sent to `/welcome`. New routes are added to the `routes` list and a constant to `route_names.dart`.

### Service layer

- **`ApiService`** — Dio client, base URL via `--dart-define=API_BASE_URL` (default: `http://10.0.2.2:3000/v1`). `_AuthInterceptor` attaches Bearer token on every request, auto-refreshes on 401, and uses a single-flight lock to avoid refresh-storms when multiple requests fail concurrently.
- **`StorageService`** — `FlutterSecureStorage` wrapper for `access_token`, `refresh_token`, and `last_user_id` keys. Exposes `deleteAll()` for full logout teardown.
- **`AuthService`** — wrapper over `ApiService` calls for `/auth/*` endpoints; always saves tokens via `StorageService`. Accepts a `DataWiper` callback in its constructor (wired in `authServiceProvider` to `AppDatabase.wipeAllUserData`). **Security invariant (v1.9.3 P0)**: `logout()` always wipes local Drift in `try/finally` even if the server round-trip fails; `login()` / `register()` wipe iff `user.id != last_user_id`. Closes cross-account PII/GPS leak on shared devices.
- **`SyncOrchestrator`** — push (`POST /v1/sync`) → mark synced → pull (`GET /v1/sync/changes`) with LWW conflict resolution on `updatedAt`.
- **`UploadsService`** — multipart `POST /v1/uploads/photos` for activity photos captured via `image_picker`.
- **`FeedbackService`** — `POST /v1/feedback` (→ GitHub Issues) for in-app problem reporting (CU-28).
- **`PdfTraceabilityService`** — on-device PDF generation (`pdf` + `printing`); shared via `share_plus`. **No `pandoc`**, no native renderer dependency.

Services receive dependencies via constructor — no global singletons. Providers wire them in `lib/providers/<domain>_provider.dart`.

### API response envelope

All backend responses: `{ success: bool, data: T }` or `{ success: false, error: string }`. `AuthResponse.fromJson` unwraps the `data` key automatically.

### API protocol policy

- **REST + JSON over HTTP/1.1 via Dio is the only sanctioned transport.** Do not introduce `graphql_flutter`, gRPC, or any non-REST client. Required for ETag/304 caching, presigned-upload flow (CU2 plan), and rural-network reliability (HTTP/2 obligatorio = roto en CO rural).
- **Photos**: uploads will migrate from multipart to **presigned PUT against OCI Object Storage** in CU2 (M2.1). Still REST — no SDK shortcuts.
- **Realtime / push**: no SSE, no long-poll, no WebSocket. If immediacy is required post-MVP, use FCM push notifications (not a new transport).
- Any proposal to deviate must open an ADR proving commercial trigger + REST evaluation + back-compat plan. Default = REST via Dio.
- Canonical reference: [`agritrace-docs/01-preparacion-mvp/06-infraestructura/05-plan-escalado-concurrencia.md §10`](https://github.com/diegotrujillor/agritrace-docs/blob/main/01-preparacion-mvp/06-infraestructura/05-plan-escalado-concurrencia.md#10-protocolo-de-api-cross-tier).

## Design system

### Colors (`AppColors` in `lib/utils/constants.dart`)

| Token | Hex | Usage |
|-------|-----|-------|
| `primaryGreen` | `#2D7A3E` | Primary buttons, headers, action elements |
| `darkGreen` | `#1B5028` | Backgrounds, hover states |
| `lightGreen` | `#E8F5E9` | Card backgrounds, success states |
| `earthBrown` | `#6D4C3D` | Icons, complementary elements |
| `harvestYellow` | `#F9A825` | Alerts, badges, "pending" status |
| `certBlue` | `#1976D2` | Links, certifications, info elements |
| `offlineOrange` | `#F57C00` | Offline indicator bar |
| `error` | `#D32F2F` | Validation errors |

### Spacing (`AppSpacing`)
`xs: 4` / `sm: 8` / `md: 16` / `lg: 24` / `xl: 32`

### Typography
**Inter** (via `google_fonts`). Minimum body size 16px for rural readability. Touch targets ≥ 44×44px (WCAG 2.1 AA).

### Offline indicator
`OfflineIndicator` widget (`lib/widgets/common/offline_indicator.dart`) shows an amber bar when connectivity is lost. Uses `connectivity_plus`.

## Domain model

### User roles
`producer` | `cooperative` | `exporter` | `buyer` | `admin`

### Activity types (Sprint 3)
`sowing` | `fertilization` | `irrigation` | `pest_control` | `harvest` | `other`

### Activity units (v1.11.0 — `kActivityUnits` in `lib/utils/constants.dart`)
`kg` | `g` | `L` | `ml` | `unidades` — optional `quantity` (double) + `unit` on each activity (registro de labores). A quantity requires a unit (form-validated). Kept in sync with backend Zod `ACTIVITY_UNITS`.

### Plot statuses (Sprint 2)
`planning` | `growing` | `ready` | `harvested`

### Certificate types (Sprint 3+)
`organic` | `fair_trade` | `ica` | `rainforest` | `other`

## Sync protocol (Sprint 3 — Drift + custom sync)

```
POST /v1/sync
Body:  { changes: [{ entity, id, action: 'create'|'update', data }] }
Response: { success: true, data: { synced, conflicts, timestamp } }

GET /v1/sync/changes?since=<ISO timestamp>
Response: { success: true, data: { changes, timestamp } }
```

Drift sync fields on every model: `syncStatus TEXT` (`'synced'`|`'pendingCreate'`|`'pendingUpdate'`), `updatedAt`. `SyncOrchestrator` runs push → `_markSynced()` → pull → `_applyPulledChange()`. Conflict resolution: Last-Write-Wins on `updatedAt` (server wins on pull). MVP guarantees 14-day offline operation.

## Sprint context

- **Sprint 1 (done):** Auth screens (welcome, login, register), GoRouter, Riverpod auth state, ApiService + token interceptor, StorageService, OfflineIndicator widget, design tokens.
- **Sprint 2 (done):** Farm + plot screens (`/farms/new`, `/plots`).
- **Sprint 3 (done):** Activity timeline screen, Drift SQLite offline-first persistence (Sprint 3 pivot — Drift chosen over WatermelonDB), `SyncOrchestrator`, PDF traceability on-device (`pdf` + `printing`).
- **Sprint 4 (done):** Alerts (`/alerts`, weather + reminders), `SyncStatusBadge`, alerts entry on dashboard; consumes `/v1/alerts` + `/v1/alerts/weather/check`.
- **Sprint 5 (done — v1.6.0 → v1.8.0):** Profile screen (ARCO compliance — Ley 1581), export data, delete account, in-app issue reporting (CU-28) via `POST /v1/feedback` → GitHub Issues; PDF traceability now includes phone, email, GPS, photos (CU-25).
- **Sprint 6 (done — v1.9.0 → v1.9.4):** Photo capture (`image_picker`) + GPS (`geolocator`) on activities + multipart `POST /v1/uploads/photos`. `AppLogoMark` reusable widget across 13 screens with per-screen size policy. P0 security fix: `AppDatabase.wipeAllUserData()` on logout + cross-account login. UX hotfixes (logo alignment, auth banner leak across screens, back arrows, autofill trim).
- **Inactivity auto-logout (v1.9.8 → v1.10.3):** `InactivityMonitor` (20 min, `kInactivityTimeoutMinutes`) — gesture-poked, lifecycle-aware (background-trip elapsed check). Note: CU-26 doc still says "not implemented" — stale.
- **Private photo read path (v1.10.0):** activity photos read via authenticated `GET /v1/uploads/photos/{id}` (bucket private, Ley 1581).
- **Pilot window (v1.10.4 → v1.10.5):** `User.pilotEndsAt` + `isDemo`; `pilotStatusProvider`; `PilotCountdownBanner` (≤5 days, app-wide); `PilotBlockedScreen` (`/pilot-blocked`); GoRouter pilot+consent redirects; 403 codes (`PILOT_EXPIRED`/`PILOT_NOT_STARTED`/`ACCOUNT_DISABLED`/`NOT_INVITED`) in `error_parser`. **PilotConsentScreen** (`/pilot-consent`) — one-time post-login privacy consent (CU-30). See CU-29/CU-30.
- **Bug #38 fix (v1.10.6):** removing an activity photo now persists (explicit rebuild in repo `update`, sync sends null to clear).
- **Activity quantity+unit (v1.11.0 — CU-14):** `Activity.quantity` (double?) + `unit` (String?); form number field + unit dropdown (`kActivityUnits`); shown in timeline + PDF. **Drift schema v1→v2** with `onUpgrade` ADD COLUMN migration in `app_database.dart` — existing devices keep their offline data; ANY future column add needs a schemaVersion bump + onUpgrade step.

New feature screens go in `lib/screens/<domain>/`, providers in `lib/providers/<domain>_provider.dart`, services in `lib/services/<domain>_service.dart`, Drift repos in `lib/repositories/<domain>_repository.dart`.

## UX conventions (locked in v1.9.4)

- **Activity card on plot detail / timeline:** **tap = no-op** (activities are immutable trace events at the list level). **Long-press → bottom sheet** with `Editar / Eliminar` actions. There is no dedicated `activity_detail_screen.dart`; edit reaches `ActivityEditScreen` via `Routes.activityEdit('/activities/:id/edit')`. Do not add a single-tap navigation without explicit product decision.
- **`AppLogoMark` placement:** form screens use 80 px centered top under the AppBar; Dashboard uses 64 px bottom-left aligned to the 56 px FAB; Vista finca uses 80 px bottom-left center-aligned to the 48 px extended FAB; Login uses 96 px; Register 80 px. Always reuse `lib/widgets/common/app_logo_mark.dart` — never inline the SVG.
- **Auth banner hygiene:** every auth-touching screen must call `ref.read(authProvider.notifier).clearError()` in `initState` via a post-frame callback to avoid leaking a 401 banner across GoRouter transitions (v1.9.4 fix). Already wired in `login_screen.dart` and `register_screen.dart`.
- **Logout / cross-account login:** never call `_storage.deleteAll()` without also invoking the Drift wiper. The `AuthService` constructor takes a `DataWiper` for this — keep that contract intact.

## Business context

Pilot region: **Valle del Cauca, Colombia** (MVP exclusive). Target users: small/medium farmers (5–50 ha). Primary crops: cacao, caña panelera, hortalizas/frutas. Pricing model under validation (tiered): Mes 1 free with commitment contract → Mes 2-3 = $14.900 COP/mes (introductory) → Mes 4+ = $29.900 COP/mes (full tariff). Willingness-to-pay is always validated against the full $29.900 tariff. App must work offline for ≥14 days; buyers verify traceability via QR codes (later release). Ley 1581 (Colombian data-protection law) requires minimizing personal data and logging access. Commercial validation track: see `agritrace-docs/01-preparacion-mvp/10-comercial-gtm/`.

## Development guidelines (MANDATORY)

Source of truth: `agritrace-docs/02-documentacion-tecnica/04-desarrollo/01-directrices-desarrollo.md`. These rules apply to **every** implementation in this repo.

### Fundamental principles

1. **Mobile-First** — Flutter/Dart only. No web app, no React Native.
2. **Offline-First** — app must work without connectivity, sync when online (Drift SQLite, 14-day guarantee).
3. **Security by Default** — tokens in `FlutterSecureStorage`, never plain storage.
4. **Simplicity** — simple code over clever code.
5. **Documentation** — `///` doc comments where needed.
6. **Testing** — everything must be testable.

### Widgets

- `PascalCase` naming; prefer `StatelessWidget` when possible.
- Typed constructor params; no `dynamic`.
- No complex logic in `build()` — extract to providers.
- Document with `///` comments.

### Providers (Riverpod)

- One provider per domain.
- Business logic lives in the notifier, not the widget (keeps it testable/reusable).
- Handle all three states: loading, data, error.
- Document dependencies.

### Security

- JWT access + refresh; never store tokens in plain storage — `FlutterSecureStorage` only.
- Never expose secrets in the client.
- Validate input before sending to the API.

### Anti-patterns (prohibited)

Business logic inside widgets, untyped (`dynamic`) props, God widgets, magic numbers (use named constants), `print()` in production, swallowed errors.

### Testing

- `flutter test`, coverage target **≥ 80%** on hand-written code (see [`docs/COVERAGE.md`](docs/COVERAGE.md)). Current as of v1.9.4: **83.6 %** (1732 / 2072 lines, 300 tests passing), excluding Drift codegen (`*.g.dart`), `repositories/`, `database/app_database.dart`, `database/tables.dart` and `sync_orchestrator.dart` — pending coverage tracked in `COVERAGE.md`.
- Always run `flutter test` with `--dart-define=API_BASE_URL=http://localhost:3000/v1` so `ApiService` does not throw `StateError` from `String.fromEnvironment`.
- AAA structure, descriptive test names per behavior. Unit + widget tests.

### Pre-commit checklist

- [ ] `flutter analyze` passes
- [ ] `dart format` applied
- [ ] `flutter test` passes
- [ ] No `print()`, no credentials in code
- [ ] Descriptive commit message

## Codification workflow (MANDATORY)

1. **Use the `everything-claude-code` plugin and its skills for all codification.** Before/while implementing, drive work through its relevant skills — e.g. `everything-claude-code:plan`, `everything-claude-code:flutter-test`, `everything-claude-code:dart-flutter-patterns`, `everything-claude-code:flutter-review`, `everything-claude-code:flutter-build`, `everything-claude-code:code-review`, `everything-claude-code:security-review`, `everything-claude-code:accessibility`, `everything-claude-code:frontend-patterns`. Pick the skills that match the task; do not hand-roll work a skill already covers.
2. **At the end of every implementation, append the changes to `CHANGELOG.md`** (Keep a Changelog format: `Added` / `Changed` / `Fixed` / etc., under the current unreleased/version heading).
