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

### Layer structure

```
lib/
  main.dart                  # ProviderScope + AgriTraceApp entry point
  navigation/
    app_router.dart          # GoRouter with auth redirect logic
    route_names.dart         # Route constants (Routes.welcome, .login, etc.)
  models/                    # Pure data classes (User, AuthResponse)
  providers/                 # Riverpod providers + state notifiers
  services/                  # Network and storage (no Flutter deps)
  screens/<domain>/          # One subfolder per feature domain
  widgets/common/            # Reusable UI components (AppButton, AppCard, AppInput)
  utils/                     # constants.dart, theme.dart, validators.dart
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

- **`ApiService`** — Dio client, base URL via `--dart-define=API_BASE_URL` (default: `http://10.0.2.2:3000/v1`). `_AuthInterceptor` attaches Bearer token on every request and auto-refreshes on 401.
- **`StorageService`** — `FlutterSecureStorage` wrapper for `access_token` / `refresh_token` keys only.
- **`AuthService`** — thin wrapper over `ApiService` calls for `/auth/*` endpoints; always saves tokens via `StorageService`.

Services receive dependencies via constructor — no global singletons. Providers wire them at `lib/providers/auth_provider.dart`.

### API response envelope

All backend responses: `{ success: bool, data: T }` or `{ success: false, error: string }`. `AuthResponse.fromJson` unwraps the `data` key automatically.

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

### Plot statuses (Sprint 2)
`planning` | `growing` | `ready` | `harvested`

### Certificate types (Sprint 3+)
`organic` | `fair_trade` | `ica` | `rainforest` | `other`

## Sync protocol (Sprint 3 — WatermelonDB)

```
POST /v1/sync
Body:  { changes: [{ entity, id, action: 'create'|'update', data }] }
Response: { success, synced, conflicts, timestamp }

GET /v1/sync/changes?since=<ISO timestamp>
Response: { changes, timestamp }
```

WatermelonDB sync fields on every model: `_status` (`'created'`|`'updated'`|`'synced'`), `updated_at`, `synced_at`. Conflict resolution: Last-Write-Wins on `updated_at`. MVP guarantees 14-day offline operation.

## Sprint context

- **Sprint 1 (done):** Auth screens (welcome, login, register), GoRouter, Riverpod auth state, ApiService + token interceptor, StorageService, OfflineIndicator widget, design tokens
- **Sprint 2 (done):** Farm + plot screens (`/farms/new`, `/plots`)
- **Sprint 3 (done):** Activity timeline screen, sync service, PDF traceability
- **Sprint 4 (done):** Alerts (`/alerts`, weather + reminders), sync status
  badge, alerts entry on dashboard; consumes `/v1/alerts` +
  `/v1/alerts/weather/check`

New feature screens go in `lib/screens/<domain>/`, providers in `lib/providers/<domain>_provider.dart`, services in `lib/services/<domain>_service.dart`.

## Business context

Pilot region: **Valle del Cauca, Colombia** (MVP exclusive). Target users: small/medium farmers (5–50 ha). Primary crops: cacao, caña panelera, hortalizas/frutas. Pricing model under validation: Mes 1 free with commitment contract → Mes 2 onwards $29.990 COP/mes per producer. App must work offline for ≥14 days; buyers verify traceability via QR codes (later release). Ley 1581 (Colombian data-protection law) requires minimizing personal data and logging access. Commercial validation track: see `agritrace-docs/01-preparacion-mvp/10-comercial-gtm/`.
