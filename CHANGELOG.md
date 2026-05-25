# Changelog — agritrace-mobile

Formato [Keep a Changelog](https://keepachangelog.com/). Cada versión =
tag git `vX.Y.Z` → APK firmado adjunto al GitHub Release vía CI
(`.github/workflows/build-apk.yml`). "Dónde" indica archivos tocados.

## [Unreleased]

### Docs
- **README.md** alineado a v1.9.4: agrega bloque "Highlights v1.9.0 → v1.9.4",
  expande la tabla de Pantallas a 13 (incluye Alertas, Perfil ARCO y Reportar
  problema), refresca la estructura de `lib/` (incluye `database/`,
  `repositories/`, screens de `alerts/` y `profile/`, widgets `AppLogoMark`
  / `SyncStatusBadge` / `AppErrorBanner`) y añade secciones de **Captura de
  evidencia** (foto · GPS · PDF · feedback) y **Brand mark — `AppLogoMark`**
  con política de tamaños por pantalla. Aclara que la wipe de Drift en logout +
  cross-account login (v1.9.3) y la garantía 14-day offline siguen vigentes.
- **CLAUDE.md** refrescado para v1.9.4: estructura `lib/` actualizada
  (incluye `database/`, `repositories/`, `widgets/common/app_logo_mark.dart`,
  `screens/profile/`, `screens/alerts/`); service layer documenta
  `SyncOrchestrator`, `UploadsService`, `FeedbackService`,
  `PdfTraceabilityService` y el invariante de seguridad `DataWiper` en
  `AuthService` (P0 v1.9.3); sección "Sprint context" extendida a Sprints 5
  y 6; nueva sección "UX conventions (locked in v1.9.4)" que codifica el
  patrón **Activity card: tap = no-op, long-press → bottom sheet
  Editar/Eliminar**, la política de tamaños de `AppLogoMark`, la higiene
  de `clearError()` en mount de pantallas de auth, y la regla
  "nunca borrar tokens sin invocar el `DataWiper`". Target de cobertura
  subido a ≥80 % con referencia a `docs/COVERAGE.md`.
- **docs/COVERAGE.md** reemplaza el baseline Sprint 5 (184 tests · 84.6 %
  sobre 748 líneas) por el snapshot post-v1.9.4: **300 tests verdes**,
  cobertura representativa **83.6 %** (1732 / 2072) sobre código a mano,
  cobertura cruda 44.9 % (1762 / 3926) dominada por `app_database.g.dart`
  (1398 líneas de codegen Drift, 0.9 %). Gap explícito reescrito para
  enumerar los cinco grupos excluidos (`*.g.dart`, `repositories/`,
  `database/app_database.dart`, `database/tables.dart`,
  `sync_orchestrator.dart`) con su backlog Sprint 7. El comando de
  reproducción ahora incluye `--dart-define=API_BASE_URL=http://localhost:3000/v1`
  (sin él, `ApiService` lanza `StateError` y la suite no compila bajo
  `flutter test`).

## [1.9.8] - 2026-05-25

### Fixed
- **P0 — Same-user re-login leaves dashboard empty.** v1.9.3 introduced
  `wipeAllUserData()` on logout to close the cross-account PII/GPS leak on
  shared devices. The wipe stays (privacy/Ley 1581), but a same-user
  re-login no longer renders "No tienes fincas aún" indefinitely:
  `AuthService.login()` and `.register()` now await a new injected
  `RemotePuller` callback that hydrates the local Drift DB from
  `GET /v1/sync/changes` (no `since` cursor → the backend returns every
  row owned by the producer) BEFORE the `AuthNotifier` flips to
  `AuthAuthenticated`. The previous fire-and-forget seed in
  `AuthNotifier.login()/register()` raced with the first dashboard render
  and is removed. Network failures during the pull are logged and
  swallowed — login still completes so an offline producer can keep
  creating local rows; `SyncNotifier` auto-retries when connectivity
  returns. (Pilot QA verbatim: "I created farms, plots or activities and
  is shown while session is open, once logout/login all screen are
  empty.")
- **P1 — Inactivity logout after 20 min of zero pointer activity.** New
  `lib/services/inactivity_monitor.dart` runs a pure-Dart `Timer` armed
  from `AuthNotifier` on every successful login/register/cold-start. A
  root-level `Listener` in `main.dart` (`HitTestBehavior.translucent`)
  pokes the timer on every `onPointerDown` / `onPointerMove` event. App
  lifecycle is respected via `WidgetsBindingObserver`:
  `AppLifecycleState.paused/hidden` records the wall-clock moment and
  cancels the foreground timer; `resumed` re-evaluates and either fires
  the callback immediately (≥ 20 min elapsed) or re-arms with the
  remaining budget. On timeout: `AuthNotifier._handleInactivityTimeout`
  increments `inactivityLogoutSignalProvider`, calls `logout()`, and
  `_AgriTraceAppState` queues a "Sesión cerrada por inactividad" SnackBar
  via a global `ScaffoldMessenger` key after the router routes to
  `/welcome`. (Pilot QA verbatim: "the session is not ended by inactivity
  after 20 mins")
- **P3 — Logo center-align with FAB on Dashboard and Vista finca.** The
  v1.9.4 implementation pinned both the logo and the FAB at `bottom: 16`
  and the resulting 4 px center offset was visibly off on real devices
  (pilot QA captures #25, #26, #27). Dashboard logo `bottom: 16 → 12`
  (formula: `fabCenter − logoHeight/2 = (16 + 56/2) − 32 = 12`). Vista
  finca logo `bottom: 0 → 4` — the v1.9.4 comment assumed the extended
  FAB was 48 px tall, but the rendered height under Material 3 is 56 px,
  so the centered position is `(16 + 56/2) − 80/2 = 4`. The new
  `test/widget/logo_fab_alignment_test.dart` measures `tester.getRect`
  for both widgets and asserts the center-Y delta is ≤ 2 px.

### Added
- `lib/services/inactivity_monitor.dart` — pure-Dart `Timer`-based
  monitor (start / poke / stop / markBackgroundedAt /
  resumeFromBackground). No Flutter or Riverpod imports — testable with
  `fake_async`.
- `lib/utils/constants.dart` — `kInactivityTimeoutMinutes = 20` const.
- `lib/services/sync_orchestrator.dart` — `pullAllFromServer()` method
  that calls `SyncService.syncNow()` with no `since` cursor and applies
  every returned change via the existing `_applyPulledChange` LWW path.
  Does NOT push local pending rows (pull-only contract — see method
  docstring for rationale).
- `lib/services/auth_service.dart` — `RemotePuller` typedef + optional
  `pullRemoteData` constructor param. Awaited inside `login()` and
  `register()` after token / `last_user_id` persistence. Errors caught
  + logged via `dart:developer`.
- `lib/providers/auth_provider.dart` — `inactivityMonitorProvider` and
  `inactivityLogoutSignalProvider` (StateProvider counter that the root
  widget watches to queue the inactivity SnackBar). `authServiceProvider`
  now injects both the existing `DataWiper` and the new `RemotePuller`.

### Changed
- `lib/main.dart` — `AgriTraceApp` is now a `ConsumerStatefulWidget` with
  `WidgetsBindingObserver`. The root tree wraps `MaterialApp.router` in a
  `Listener` (gesture poke) and registers a global
  `scaffoldMessengerKey` so the inactivity SnackBar has a stable mount
  point across router transitions.
- `lib/providers/auth_provider.dart` — removed the fire-and-forget
  `_seedInBackground('login seed')` / `_seedInBackground('register seed')`
  calls (the synchronous `RemotePuller` in `AuthService` covers the same
  ground deterministically). Cold-start refresh still calls
  `_seedInBackground('initial seed')` because the cold-start flow does
  NOT wipe the DB and the local rows are already valid.

### Tests
- `test/unit/auth_service_test.dart` — +5 tests under the new
  "remote hydration on login/register (P0)" group: (1) login awaits the
  puller after tokens + last_user_id are saved (order asserted), (2)
  register awaits the puller, (3) login completes when the puller
  throws, (4) login still works without a puller (legacy callers), (5)
  cross-user wipe runs BEFORE the puller.
- `test/unit/sync_orchestrator_test.dart` — new file with 4 tests
  covering `pullAllFromServer()`: (a) calls `syncNow` with no `since`,
  (b) upserts every entity (2 farms + 1 plot + 1 activity + 1 alert),
  (c) propagates transport errors so `AuthService` can log them, (d)
  does NOT push pending local changes (pull-only contract).
- `test/unit/inactivity_monitor_test.dart` — new file with 10 tests
  using `fake_async`: timeout fires, poke resets indefinitely, stop
  cancels, re-start works, no-op without start, background+resume after
  full timeout fires immediately, background+resume before timeout
  re-arms remaining budget, resume without a paired pause re-arms a
  fresh timer, stop after background cleans up.
- `test/widget/logo_fab_alignment_test.dart` — new file with 2 widget
  tests: Dashboard 64 px logo vs 56 px FAB, Vista finca 80 px logo vs
  extended FAB. 2 px center-Y tolerance.
- `pubspec.yaml` — `fake_async: ^1.3.1` promoted from transitive to
  explicit dev_dependency.

Suite total: 319 → 340 (+21 new tests). `flutter test` green;
`flutter analyze` clean.

## [1.9.7] - 2026-05-25

### Fixed
- PDF de trazabilidad (CU-25): activity photos uploaded to OCI (`https://...` URLs from `POST /v1/uploads/photos`) now download and render correctly in the PDF. Previously they were silently absent because `_loadPhotos` only handled local `File(path)`. Closes #33.
- PDF rendering no longer crashes when a single photo fetch fails — the row renders a placeholder (`Foto no disponible (sin conexión)`) and the rest of the PDF generates normally. Photo fetches use a dedicated, interceptor-free `Dio` (10 s connect/receive/send timeouts) so the user's JWT is never leaked to Oracle Object Storage.

### Changed
- `PdfTraceabilityService` constructor is no longer `const`; accepts an optional `Dio? httpClient` for test injection. Default factory builds a fresh, interceptor-free `Dio` with 10 s timeouts.
- `lib/screens/plots/plot_detail_screen.dart` — drop `const` at the `PdfTraceabilityService()` call site to match the new constructor.

### Tests
- `test/unit/pdf_traceability_service_test.dart` extended with 8 new tests covering the v1.9.7 URL-scheme branch: https + http happy paths, connection-error / timeout / empty-body failure paths, "1 of 3 photos fails → PDF still generates", local-file branch isolation (verifies Dio is NOT hit), and a real-file round-trip via `Directory.systemTemp`. Uses `mocktail` `MockDio` per the existing `_helpers.dart` pattern.

## [1.9.6] - 2026-05-24

### Added
- Soft duplicate warning on `Registrar actividad`: when type is `Siembra` and a prior Siembra exists for the same lote on the same calendar day, an AlertDialog asks the user to confirm before saving. Other activity types (Fertilización, Riego, Cosecha, Control de plagas, Otro) unaffected — they remain freely repeatable.
- `kDuplicateWarnActivityTypes` constant in `lib/utils/constants.dart` to extend the warning to other types later (post-pilot data permitting).
- New notifier method `ActivitiesNotifier.findByPlotTypeAndDate({type, date})` — local Drift cache only, in-memory year/month/day filter on local time.
- 6 new widget tests in `test/widget/activity_duplicate_warn_test.dart` covering the dialog appearance, the Cancelar / Sí-continuar branches, the no-warn cases (different day, different plot, other activity type), and the edit-screen bypass. Suite total: 305 → 311.

## [1.9.5] - 2026-05-24

### Fixed
- Form screens (Registrar actividad / Agregar lote / Registrar finca + edit variants): removed duplicate bottom-left logo. Only the top-centered 80px header logo remains, per user feedback on v1.9.4.

## [1.9.4] - 2026-05-24 — fix(ui+auth): logo alignment hotfixes + clear leaked auth error across screens

### Fixed
- **Dashboard:** bottom-left brand mark size bumped 56 → 64 px so it stops
  reading as visually smaller than the 56 px FAB on the right. Both rows
  still share `bottom: AppSpacing.md (16)`. Pantalla 15 in the v1.9.3
  user-feedback captures.
- **Farm detail (Lote list):** vertically center-align the 80 px brand mark
  with the "Agregar lote" extended FAB. The extended FAB is 48 px tall at
  `bottom: 16`, so the logo's `bottom` was changed from 16 → 0 to satisfy
  `logoBottom = fabBottom + (fabHeight - logoHeight) / 2 = 0`. The logo
  size itself is unchanged. Pantalla 16.
- **Form screens — centered brand mark header:** plot edit, plot create,
  finca create + edit, activity create + edit all gained a centered
  80 px `AppLogoMark` directly under the AppBar so the producer never
  loses the identity strip while filling a form. `plot_edit_screen.dart`
  had no logo at all; the rest gain the header in addition to the existing
  bottom-left mark. Pantalla 18 (Editar lote had no logo) covers the
  hard miss; the rest is consistency follow-through per the spec
  "rest of screens: do the same with the logo size, the alignment and
  the position".
- **Auth — error state no longer leaks across screens:**
  `_LoginScreenState.initState` and `_RegisterScreenState.initState` now
  schedule `ref.read(authProvider.notifier).clearError()` via a
  post-frame callback. Previously, a failed login (HTTP 401 ⇒
  "Credenciales incorrectas") parked the AsyncNotifier in `AsyncError`
  and the banner survived the GoRouter navigation to the register screen,
  surfacing the misleading text on a page that had nothing to do with the
  failure. The notifier's `clearError()` is idempotent on `AsyncData`, so
  the same-user re-mount path is a no-op. Pantalla 19.

  Dónde:
  `lib/screens/auth/login_screen.dart`,
  `lib/screens/auth/register_screen.dart`,
  `lib/screens/farms/dashboard_screen.dart`,
  `lib/screens/farms/farm_detail_screen.dart`,
  `lib/screens/farms/farm_form_screen.dart`,
  `lib/screens/plots/plot_edit_screen.dart`,
  `lib/screens/plots/plot_form_screen.dart`,
  `lib/screens/activities/activity_edit_screen.dart`,
  `lib/screens/activities/activity_form_screen.dart`.

### Investigated (no change)
- **Activity tap on plot detail (Pantalla 17):** the user asked whether
  the lack of view/edit/delete on a single-tap of a recent activity is
  intentional. Confirmed intentional for the MVP — activities are
  immutable trace events at the list level; edit/delete is reachable via
  **long-press → contextual bottom sheet** ("Editar / Eliminar"), the same
  pattern surfaced by the dedicated `ActivityTimelineScreen`. No dedicated
  `activity_detail_screen.dart` exists; the GoRouter route for
  `Routes.activityEdit('/activities/:id/edit')` is the only edit entry
  point. Discoverability is a known follow-up — improving the single-tap
  affordance (small chevron, toast hint, or promoting the long-press to
  an explicit overflow menu) is deferred to post-Día 0.

### Tests
- New: `test/widget/auth_error_clear_on_mount_test.dart` — pre-seeds an
  `AsyncError` on `authProvider` via `AuthNotifier.login()` with a stubbed
  401, then asserts both `RegisterScreen` and `LoginScreen` render no
  `AppErrorBanner` after `pumpAndSettle`. Locks in the cross-screen
  leak fix.

## [1.9.3] - 2026-05-24 — fix(security): clear Drift on logout (P0 data leak) + farm detail refresh + activity edit/delete + logo sizes

### Security
- **P0 — fix (data leak): wipe local Drift DB on logout AND on cross-account
  login.** Drift's SQLite database (`agritrace`) is shared across every
  account that authenticates on the same device. Before this fix, `logout()`
  only cleared the Bearer tokens in `flutter_secure_storage`; the local
  `farms`, `plots`, `activities` and `alerts` rows survived, and the next
  user that logged in (or registered) on the same device saw the previous
  account's farms — full PII + GPS leak across users.

  Implementation (no SQLCipher yet; flagged for Sprint 6+):
  - `AppDatabase.wipeAllUserData()` — single SQLite transaction issuing
    `DELETE FROM activities`, `DELETE FROM alerts`, `DELETE FROM plots`,
    `DELETE FROM farms` (children before parents). All-or-nothing semantics
    so a crash mid-wipe cannot leave a partial state.
  - `AuthService` now accepts an optional `DataWiper` callback in its
    constructor and is wired in `authServiceProvider` to delegate to
    `AppDatabase.wipeAllUserData`. Keeping the binding at the provider
    layer lets `AuthService` stay Flutter-free and unit-testable without
    importing Drift.
  - `AuthService.logout()` wraps its work in `try / finally`; the `finally`
    block always (a) `_storage.deleteAll()` (tokens + `last_user_id`) and
    (b) invokes the wiper. The server `/auth/logout` round-trip remains
    best-effort.
  - **Defense in depth:** `AuthService.login()` and `.register()` now
    compare the freshly authenticated `user.id` against the cached
    `last_user_id` and run the wiper iff they differ — closes the gap
    where a user closes the app without logging out and another account
    then signs in on the same device. First-device logins never wipe
    (nothing to leak). Same-user re-login (e.g. token refresh recovery)
    never wipes.
  - `StorageService` gains `last_user_id` storage (`getLastUserId`,
    `saveLastUserId`) and a `deleteAll()` that clears all three keys at
    once.
  - `AuthService.refresh()` also persists `last_user_id` so post-cold-start
    sessions keep the marker fresh (covers Android backup-restore edge
    case where tokens survive a reinstall).

  Dónde:
  `lib/database/app_database.dart`,
  `lib/services/storage_service.dart`,
  `lib/services/auth_service.dart`,
  `lib/providers/auth_provider.dart`,
  `test/unit/auth_service_test.dart` (+5 new tests covering: logout-always-
  wipes-even-on-server-error, cross-user-login-wipes, same-user-login-keeps,
  first-login-keeps, register-also-wipes-when-different).

  **Known limitation (backlog Sprint 6+):** SQLCipher per-user database
  encryption is the long-term fix — it makes the wipe redundant because
  the previous user's rows are unreadable without their key. This MVP
  wipe closes the leak without rotating keys.

### Fixed
- **P1 — fix (farm detail refresh): editar tipo de cultivo de una finca no
  refrescaba la pantalla de detalle.** `FarmFormScreen._submit()` invalidaba
  `farmsProvider` (lista del dashboard) tras un `updateFarm`, pero NO
  invalidaba `farmProvider(id)` (singular del detail). `farmProvider` es un
  `FutureProvider.family` cuyo snapshot está cacheado independientemente
  del notifier de la lista, así que la cabecera del detalle seguía mostrando
  el `cropType` viejo aunque el dashboard ya reflejara el nuevo. Fix idéntico
  al patrón ya usado en `plot_edit_screen.dart`: invalidar ambos providers
  tras el `await notifier.updateFarm(...)`. Dónde:
  `lib/screens/farms/farm_form_screen.dart`.
- **P1 — confirm (activity edit/delete): el reporte "lista las actividades
  pero no permite editar o eliminar" se traza a un build stale en QA.** La
  funcionalidad ya estaba implementada en v1.9.2 (CU-16 + CU-17):
  long-press en cualquier card de actividad (tanto en `plot_detail_screen`
  como en `activity_timeline_screen`) abre un bottom sheet con
  "Editar / Eliminar"; `ActivityEditScreen` ya existe y postea PUT con
  invalidate de `activityProvider`. Los widget tests
  `test/widget/activity_timeline_delete_test.dart` y
  `test/widget/activity_edit_screen_test.dart` cubren ambos flujos. Esta
  versión incluye un APK recién compilado para descartar build stale en el
  device de QA; no se requieren cambios de código.

### Changed
- **Logo sizes — QA cycle-03 (5 pantallas bump 2×, vista finca aumenta a
  80 px, dashboard se mantiene 56 px = altura del FAB).**
  | Pantalla | Antes | Después | Notas |
  |----------|-------|---------|-------|
  | Login | 48 px | 96 px | Posición intacta (centered, debajo del CTA "¿No tienes cuenta?"). |
  | Register | 40 px (top-left) | 80 px (derecha) | Re-estructurado en `Row(spaceBetween)` con el título "Crear cuenta", para alinear el logo verticalmente al label. Texto + estilo del título sin cambios para no romper text-finders de tests. |
  | Vista finca (`FarmDetailScreen`) | 56 px | 80 px | Spec autorizaba 80-90 px como fallback cuando 112 px choca con el FAB "Agregar lote". Alineación + posición (bottom-left + AppSpacing.md) sin cambios. |
  | Registrar finca | 40 px | 80 px | Reserva inferior del scroll: `AppSpacing.xl + 56` → `AppSpacing.xl + 80` para que el botón "Registrar finca" no se solape con el logo. |
  | Registrar lote | 40 px | 80 px | Reserva inferior actualizada al mismo valor. |
  | Registrar actividad | 40 px | 80 px | Reserva inferior actualizada al mismo valor. |
  | Dashboard | 56 px | 56 px (sin cambio) | Ya coincidía con la altura por defecto del FAB Material; el spec pidió "= altura EXACTA del FAB +" y se mantiene. |

  Dónde:
  `lib/screens/auth/login_screen.dart`,
  `lib/screens/auth/register_screen.dart`,
  `lib/screens/farms/farm_detail_screen.dart`,
  `lib/screens/farms/farm_form_screen.dart`,
  `lib/screens/plots/plot_form_screen.dart`,
  `lib/screens/activities/activity_form_screen.dart`.

## [1.9.2] - 2026-05-23 — fix(qa-cycle-02): crop_type display lote + finca capitalize + logos 7 screens

### Fixed
- **fix (QA cycle-02): display de `lote.crop_type` en minúscula tras guardar.**
  El form usaba `cropTypeLabel(crop)` para los items del dropdown, pero las
  pantallas de detalle mostraban el valor crudo de la DB (`cana_panelera`,
  `cacao`) en vez del label humano (`Caña panelera`, `Cacao`). Se envuelven
  todos los renders visibles de `plot.cropType` con `cropTypeLabel(...)`.
  Los submits/POSTs siguen mandando el valor canónico snake_case al backend
  — solo cambia el render. Dónde:
  `lib/screens/farms/farm_detail_screen.dart` (PlotTile),
  `lib/screens/plots/plot_detail_screen.dart` (PlotSummary InfoRow),
  `lib/services/pdf_traceability_service.dart` (fila "Cultivo (lote)" del
  PDF de trazabilidad).
- **fix (QA cycle-02): capitalización de `finca.crop_type` (texto libre).**
  `TextCapitalization.sentences` solo se aplica al tipear; falla con
  autofill, paste, o edit-mode (cuando se recarga un valor previo en
  minúscula el cursor no dispara la capitalización al inicio). Fix robusto:
  normalizar el valor antes de guardar (source of truth). Nuevo helper puro
  `capitalizeFirstLetter(String? input)` en `lib/utils/text_format.dart` que
  hace `trim` → null si queda vacío → `toUpperCase()` sobre el primer char.
  Se aplica en `FarmFormScreen._submit()` antes de pasar `cropType` a
  `farmService.create()` / `update()`. Dónde:
  `lib/utils/text_format.dart` (nuevo),
  `lib/screens/farms/farm_form_screen.dart`,
  `test/unit/text_format_test.dart` (nuevo, 9 cases).

### Added
- **Logo placement en 7 pantallas (QA cycle-01).** Nuevo widget reusable
  `AppLogoMark({size, color, variant})` en `lib/widgets/common/app_logo_mark.dart`
  que renderiza el SVG del brand mark (`assets/brand/agritrace-logo-mark.svg`
  por default, `agritrace-logo-white.svg` para variant `white`). Aplicado:
  - `RegisterScreen`: top-left, antes del título "Crear cuenta", 40 px.
  - `LoginScreen`: bottom centered debajo del link "¿No tienes cuenta?",
    48 px.
  - `DashboardScreen`: `Stack` con `Positioned(bottom, left)`, 56 px —
    mismo tamaño y nivel vertical que el FAB "+" del lado opuesto.
  - `FarmDetailScreen`: `Stack` con `Positioned(bottom, left)`, 56 px —
    mismo nivel del FAB "Agregar lote".
  - `FarmFormScreen`: bottom-left dentro de `Stack`, 40 px.
  - `PlotFormScreen`: bottom-left dentro de `Stack`, 40 px.
  - `ActivityFormScreen`: bottom-left dentro de `Stack`, 40 px.
  En las form screens se añade padding bottom extra al `SingleChildScrollView`
  para que el último botón no choque con el overlay del logo. Dónde:
  `lib/widgets/common/app_logo_mark.dart` (nuevo),
  `lib/screens/auth/register_screen.dart`,
  `lib/screens/auth/login_screen.dart`,
  `lib/screens/farms/dashboard_screen.dart`,
  `lib/screens/farms/farm_detail_screen.dart`,
  `lib/screens/farms/farm_form_screen.dart`,
  `lib/screens/plots/plot_form_screen.dart`,
  `lib/screens/activities/activity_form_screen.dart`,
  `test/widget/app_logo_mark_test.dart` (nuevo, 3 cases).

## [1.9.1] - 2026-05-23 — fix(qa-manual): back arrows + autofill trim + profile order + hint color

### Fixed
- **fix (PDF cycle-01 #11):** back arrow missing en `FarmDetailScreen`. El
  dashboard navega con `context.go(Routes.farmDetail(...))` (stack-replacing),
  por lo que Material no auto-inyecta el leading IconButton. Se agrega un
  `leading: IconButton(arrow_back) → context.go(Routes.dashboard)`,
  reutilizando el patrón de `plot_form_screen.dart`.
  Dónde: `lib/screens/farms/farm_detail_screen.dart`.
- **fix (PDF cycle-01 #21):** back arrow missing en `PlotDetailScreen`. Mismo
  origen que #11 (farm detail navega con `context.go`). Se agrega un leading
  IconButton que vuelve a `Routes.farmDetail(plot.farmId)` cuando el plot
  está hidratado; fallback a `Routes.dashboard` cuando se entra por deep-link
  y el `plot.farmId` aún no está disponible — el callback nunca crashea.
  Dónde: `lib/screens/plots/plot_detail_screen.dart`.
- **fix (PDF cycle-01 #1):** trailing whitespace de autofill en el campo
  "Nombre completo" del `RegisterScreen` quedaba pegado tras el autocompletar
  de Android, y el `.trim()` que corre en submit jamás se mostraba al
  usuario. Nuevo `TextInputFormatter` `_TrimTrailingWhitespaceOnBurst` que
  recorta whitespace final SOLO cuando la longitud crece por más de un
  carácter en un solo cambio (paste / autofill burst). Escribir "Diego
  Trujillo" letra por letra sigue funcionando sin tropiezos. Se extiende
  `AppInput` con un parámetro opcional `inputFormatters` (default `null`,
  backwards-compatible) para forwardearlo al `TextFormField` interno.
  Dónde: `lib/widgets/common/app_input.dart`,
  `lib/screens/auth/register_screen.dart`.
- **fix (PDF cycle-01 #8):** orden de tiles en `ProfileScreen`. "Cerrar
  sesión" pasa al final (acción menos destructiva, más frecuente). Nuevo
  orden: Exportar mis datos → Reportar problema → Eliminar mi cuenta →
  Cerrar sesión.
  Dónde: `lib/screens/profile/profile_screen.dart`.
- **fix (PDF cycle-01 #2 / #6 / #16):** placeholders demasiado fuertes
  (Material3 caía a ~60% alpha sobre `onSurface`, casi negros, indistinguibles
  del texto real). Se define `hintStyle` global en el `InputDecorationTheme`
  con un neutro suave `Color(0xFF9CA3AF)` 16 px; se aplica a todos los
  inputs de la app sin tocar `AppInput`.
  Dónde: `lib/utils/theme.dart`.

### Changed
- **chore:** bump version `1.9.0+4` → `1.9.1+5` en `pubspec.yaml`. El build
  number `+5` es monotónico (Android `versionCode` lo exige).

## [1.9.0] - 2026-05-23 — feat(uploads+gps+forms): photo capture, GPS, crop_type rules + 5 P1 fixes

### Added
- **feat (FASE 2 — `Registrar finca`):** `crop_type` ahora es un
  `TextField` libre opcional (max 255 chars, validador
  `validateOptionalFarmCropType` en `utils/validators.dart`). Placeholder
  *"Ej. Agricultura de exportación"*. `TextCapitalization.sentences`
  aplicado. El backend Zod (parallel agent v0.6.0) acepta cualquier
  string al nivel finca.
  Dónde: `lib/screens/farms/farm_form_screen.dart`, `lib/utils/validators.dart`.
- **feat (FASE 2 — GPS capture):** botón "Capturar ubicación GPS" en
  `FarmFormScreen` que pide permiso con `Geolocator.checkPermission()` +
  `requestPermission()` y captura una posición con
  `getCurrentPosition(accuracy: medium, timeLimit: 15s)`. Snackbar de
  error si el permiso es denegado o el servicio está apagado; skip
  permite continuar sin GPS (lat/lng = null). Visualiza
  `"lat, lng capturado"` cuando hay fix.
  Dónde: `lib/screens/farms/farm_form_screen.dart`.
- **feat (FASE 2 — auto-navegación post-finca):** tras crear una finca
  con éxito, navega automáticamente a `PlotFormScreen(farmId, suggestion)`
  via `context.go` (reemplaza la ruta del farm form). El plot form
  pre-selecciona el dropdown si el free-text del cultivo de la finca
  matchea uno de los wire values del enum (helper `matchPlotCropType`).
  El AppBar back-button del plot form vuelve a `/dashboard`, no al farm
  form (que ya no está en el stack).
  Dónde: `lib/screens/farms/farm_form_screen.dart`,
  `lib/screens/plots/plot_form_screen.dart`,
  `lib/navigation/app_router.dart`.
- **feat (FASE 2 — `Registrar lote` crop_type):** dropdown enum
  obligatorio con wire values `cacao`, `cana_panelera`, `hortalizas`,
  `frutas`, `otro` (renombrado el legacy `caña` → `cana_panelera` por
  contrato backend v0.6.0). Labels human-readable vía `cropTypeLabel`:
  "Cacao", "Caña panelera", etc. Validador `validatePlotCropType`
  rechaza vacíos y valores fuera del allow-list.
  Dónde: `lib/utils/constants.dart`, `lib/utils/validators.dart`,
  `lib/screens/plots/widgets/plot_form.dart`.
- **feat (FASE 2 — `Registrar actividad` foto):** reemplaza el `TextField`
  "URL de foto" con un widget de captura `image_picker` (cámara +
  galería) + preview thumbnail + botón "Quitar foto". Al hacer submit,
  primero sube la foto via `POST /v1/uploads/photos` (`UploadsService`),
  luego persiste la URL en `activity.photoUrl`. Errores de upload
  (429 rate-limit, 413 too-large, 5xx, network) muestran snackbar +
  banner inline SIN perder el resto del form — el usuario puede reintentar.
  `maxWidth: 1920`, `imageQuality: 85` capa el tamaño bajo los 5 MB del
  backend.
  Dónde: `lib/screens/activities/widgets/activity_form.dart`,
  `lib/services/uploads_service.dart` (nuevo),
  `lib/providers/uploads_provider.dart` (nuevo),
  `lib/models/upload.dart` (nuevo).
- **feat (FASE 2 — capitalización global):** `AppInput` ahora acepta
  `onChanged` (también necesario para bug #4 — ver Fixed). Forms críticos
  reciben `TextCapitalization.sentences` (nombre finca, nombre lote,
  cultivo libre finca, dirección, nota actividad, variedad lote). El
  email queda con `none` (lowercase).
  Dónde: `lib/widgets/common/app_input.dart` y todos los forms.
- **deps:** `image_picker: ^1.1.0`, `geolocator: ^13.0.0`,
  `permission_handler: ^11.3.0`, `http_parser: ^4.0.2` añadidos a
  `pubspec.yaml`. Lockfile actualizado.
- **android:** `AndroidManifest.xml` declara los permisos `CAMERA`,
  `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `READ_MEDIA_IMAGES`
  (API 33+), y `READ_EXTERNAL_STORAGE` con `maxSdkVersion="32"` para
  compatibilidad de galería en pre-API-33.

### Fixed
- **fix (bug #4 — email pegado tras rechazo):** después de un login
  fallido con "Credenciales incorrectas", editar el campo email o
  contraseña no limpiaba el banner — el `parseApiError(authState.error)`
  seguía leyendo el `AsyncError`. Nuevo `AuthNotifier.clearError()`
  invocado desde `onChanged` de ambos campos en `LoginScreen` y
  `RegisterScreen`. Idempotente: no-op si el state es `data`.
  Dónde: `lib/providers/auth_provider.dart`,
  `lib/screens/auth/login_screen.dart`,
  `lib/screens/auth/register_screen.dart`,
  `lib/widgets/common/app_input.dart`.
- **fix (bug #7 — login muestra "Sesión expirada"):** un POST
  `/auth/login` con credenciales erradas hacía 401 → el
  `_AuthInterceptor` intentaba refresh → fallaba con
  `_RefreshFailure('no refresh token in storage')` → emitía el sentinel
  `AuthSessionCollapsed` que `parseApiError` mapeaba a *"Sesión expirada"*.
  El interceptor ahora hace early-return en rutas anónimas (login /
  register), dejando que el 401 raw pase al `parseApiError` que lo
  traduce a *"Credenciales incorrectas"*.
  Dónde: `lib/services/api_service.dart` (nuevos
  `kAuthLoginPath` + `kAuthRegisterPath` + check `_isAnonymousAuthPath`).
- **fix (bug #10 — vista finca: error inmediato al abrir):** tras crear
  una finca offline, abrir la vista detalle devolvía error porque
  `farmProvider(farmId)` consultaba `GET /v1/farms/:id` directamente y
  el backend no conocía la finca pendiente de sync (hasta 14 días).
  Ahora es local-first: lee del repo Drift primero, fallback al server
  sólo si el local no la tiene.
  Dónde: `lib/providers/farms_provider.dart`,
  `lib/repositories/farm_repository.dart` (nuevo `getById`).
- **fix (bug #20 — vista lote: "No tienes permiso" + saca a login):**
  mismo síntoma que #10 — `plotProvider(plotId)` era server-first y
  devolvía 401/403 para lotes no sincronizados, y el interceptor
  interpretaba el 401 como sesión colapsada y forzaba logout. Mismo fix:
  local-first via `PlotRepository.getById` + nuevo `AppDatabase.getPlotById`.
  La parte del *"saca a login"* también queda mitigada por el fix de
  bug #7 (el interceptor ya no escala 401 a session-collapse cuando el
  refresh es trivialmente posible).
  Dónde: `lib/providers/plots_provider.dart`,
  `lib/repositories/plot_repository.dart`,
  `lib/database/app_database.dart`.
- **fix (bug #28 — editar lote: cambios no refrescan):** `PlotEditScreen`
  ya invalidaba `plotProvider(plotId)`; añadido `invalidate` también de
  `plotsProvider(farmId)` (family) para forzar el re-fetch de la lista
  cuando el stream reactivo de Drift no emite a tiempo.
  Dónde: `lib/screens/plots/plot_edit_screen.dart`.

### Tests
- **test (nuevo):** `test/unit/uploads_service_test.dart` — 11 tests
  cubren multipart body con field `photo`, parsing del envelope 201,
  guard local 5 MB → `UploadTooLargeException` sin tocar la red,
  mapping de 413/429/502/`success:false`, y `UploadResponse.fromJson`
  con tolerancia para `num` size.
- **test (nuevo):** `test/unit/farms_form_test.dart` — 6 tests del
  `validateOptionalFarmCropType` (null/empty/255/256/trim).
- **test (nuevo):** `test/unit/plots_form_test.dart` — 14 tests del
  `validatePlotCropType` con allow-list, `cropTypeLabel` Spanish
  rendering, y `matchPlotCropType` (incluido el fallback de legacy
  `caña` → `cana_panelera`).
- **test (existing, ajustados):** `test/unit/farms_provider_test.dart`
  + `test/unit/plots_provider_test.dart` actualizados al nuevo contrato
  local-first de `farmProvider`/`plotProvider` (stub `getById`), y dos
  tests nuevos por archivo para cubrir el path local. El test de
  `create()` ahora espera `throwsA(...)` además del state `hasError`,
  porque `FarmsNotifier.create()` retorna `Future<Farm>` (necesario para
  la auto-navegación post-finca).
- **test (existing, ajustados):** `test/widget/plot_edit_screen_test.dart`
  + `test/widget/plot_detail_delete_test.dart` + `test/widget/activity_edit_screen_test.dart`
  actualizados para reflejar la UI v1.9.0 (stub `mockPlotRepo.getById`,
  reemplazo del assert del campo URL por aserciones de los nuevos
  controles "Foto (opcional)" / "Tomar foto" / "Galería", + `ensureVisible`
  para que el botón "Guardar cambios" no quede off-screen con la sección
  de foto añadida).
- **Suite:** 251 → **281 tests** (`flutter analyze` limpio, todos verde).

### Notas de despliegue
- **Acoplamiento conocido:** el endpoint `POST /v1/uploads/photos` queda
  fallando hasta que `agritrace-backend` v0.6.0 (con S3 bucket
  configurado en el OCI VM) se despliegue. El mobile build sube en
  paralelo; en runtime sólo fallará la subida de foto (el resto del form
  sigue funcionando — la foto es opcional). Documentado en commit + tag
  v1.9.0.

## [1.8.0] - 2026-05-22 — feat(profile/report): in-app issue reporting → GitHub Issues (CU-28)

### Added
- **feat (CU-28):** nueva pantalla **"Reportar problema"** accesible desde
  `ProfileScreen` (entre "Exportar mis datos" y "Cerrar sesión"). Los
  pilotos pueden enviar bugs/sugerencias sin llamar a Diego — el reporte
  se postea a `POST /v1/feedback` (contrato congelado coordinado con
  backend v0.5.0) y el backend crea un GitHub Issue, devolviendo
  `{ issueUrl, issueNumber }` que se muestra en un `AlertDialog` con
  botón "Ver en GitHub" (`url_launcher.launchUrl`).
  Dónde: `lib/screens/profile/report_issue_screen.dart`,
  `lib/screens/profile/profile_screen.dart`.
- **feat:** `FeedbackService.submit()` con DTOs tipados
  (`FeedbackCategory` enum bug/feature/other, `FeedbackDevice`,
  `FeedbackSubmitted`). Mapea HTTP 429 a una excepción tipada
  `FeedbackRateLimitException` con mensaje en español *"Has alcanzado el
  límite de 5 reportes por día — intenta mañana."*; otros errores
  propagan como `DioException` y caen al `parseApiError` genérico.
  Dónde: `lib/services/feedback_service.dart`, `lib/models/feedback.dart`,
  `lib/providers/feedback_provider.dart`.
- **feat:** captura automática de `appVersion` (`PackageInfo.fromPlatform`
  → `'${version}+${buildNumber}'`) y `device`
  (`DeviceInfoPlugin().androidInfo` → `model`, `'android'`,
  `'Android ${version.release}'`). Sección read-only "Información que se
  enviará" en la pantalla muestra al usuario exactamente qué se manda
  (RNF-05 / Ley 1581 — transparencia). Guarda con `Platform.isAndroid` y
  fallback a placeholders seguros si el plugin falla.
- **deps:** `device_info_plus: ^12.0.0` y `package_info_plus: ^9.0.0`
  añadidos a `pubspec.yaml`. **Versiones pinned a las series 12.x/9.x
  por incompatibilidad de `win32`:** la 13.x/10.x dependen de `win32:
  ^6.0.1` que choca con `flutter_secure_storage_windows: ^3.1.2` (`win32:
  ^5`). Las APIs Android que usamos (`androidInfo.model`,
  `version.release`, `PackageInfo.fromPlatform`) son idénticas entre las
  series.
- **test:** `test/unit/feedback_service_test.dart` (nuevo) — 7 tests:
  body contractuado, mapping del enum, happy path, 429 →
  `FeedbackRateLimitException`, 502 → `DioException` propagado,
  `success:false` → `FormatException` con error del servidor, envelope
  malformado → `FormatException`. Suite: 244 → 251 tests (`flutter
  analyze` limpio).

### Notas de despliegue
- **Acoplamiento conocido:** la pantalla devolverá 404 hasta que
  `agritrace-backend` v0.5.0 (con `GITHUB_FEEDBACK_TOKEN` configurado en
  el OCI VM) se despliegue. Documentado en commit + tag v1.8.0.

### Tests
- **test (sync):** `stubPush` helper en `test/unit/sync_service_test.dart`
  ahora envuelve el body en `envelope(...)` para reflejar la shape
  `{ success, data }` que el backend emite desde `c313d3a` (fix sync push
  envelope + fromJson snake_case, CU-22/CU-23). El helper había quedado
  fuera de sincronía con producción — 4 tests fallaban con
  `FormatException: Invalid sync push response` (todos por la misma
  causa). Callers actualizados para pasar sólo el resultado interno; el
  test negativo "invalid push envelope" hace bypass directo de
  `stubPush` para inyectar `{ success: false }`. No hay cambio en
  producción. Suite: 240/244 → 244/244. `flutter analyze` limpio.
- Dónde: `test/unit/sync_service_test.dart`.

## [1.7.1] - 2026-05-22 — fix(profile/export): unwrap envelope + honour X-Export-Truncated

### Fixed
- **fix (CU-05):** `UsersService.exportMe()` ahora desenvuelve el envelope
  `{ success, data }` antes de compartir; el archivo `.json` ya no incluye
  el wrapper del transporte API — el productor recibe directamente el
  bundle Habeas Data (`{ exportedAt, user, producer, farms, plots,
  activities, alerts, truncated }`). Sincroniza con backend v0.4.4 que
  extendió el bundle. Si `success === false`, ahora lanza
  `FormatException` con el `error` del servidor (antes pasaba el envelope
  con `success:false` al share-sheet sin avisar).
  Dónde: `lib/services/users_service.dart`,
  `lib/screens/profile/profile_screen.dart`.

### Added
- **feat (CU-05):** lectura del header `X-Export-Truncated` (Dio lo
  normaliza a `x-export-truncated`). Cualquier valor no vacío se mapea a
  `truncated == true` en el nuevo DTO `UserExportResult` (`bundle` +
  `truncated`). `ProfileScreen` muestra un `SnackBar` de 8 s advirtiendo
  *"Exportación parcial: tu cuenta excede 10000 filas en alguna
  colección. Contacta soporte para un export completo."* cuando el
  bundle viene capado por el límite de 10000 filas por colección
  (backend v0.4.4).
- **feat:** filename del share-sheet con sello de fecha —
  `agritrace-datos-YYYY-MM-DD.json` (deriva la fecha de
  `bundle.exportedAt`; fallback a hoy UTC si falta).
- **test:** `test/unit/users_service_test.dart` (nuevo) — 6 tests que
  cubren envelope unwrap, header truthy/ausente, `success:false` y la
  ruta de `deleteMe`.

## [1.7.0] - 2026-05-21 — feat(profile)+fix(ux): pantalla de perfil ARCO + botón splash

### Added
- **feat (CU-27):** `ProfileScreen` (`lib/screens/profile/profile_screen.dart`) — nueva Pantalla 11. Muestra nombre/email/teléfono del usuario autenticado y expone tres acciones: exportar datos JSON (Ley 1581), cerrar sesión y eliminar cuenta con confirmación.
- **feat (CU-05):** `UsersService.exportMe()` llama `GET /v1/users/me/export`, serializa el bundle JSON con indentación y lo entrega al share-sheet Android como `agritrace-datos.json` vía `share_plus`.
- **feat (CU-04):** `UsersService.deleteMe()` llama `DELETE /v1/users/me`. Tras respuesta 200, llama `logout()` (limpia tokens + redirige a Bienvenida).
- **feat:** `UsersService` + `usersServiceProvider` en `lib/services/users_service.dart` y `lib/providers/users_provider.dart`.
- **deps:** `share_plus: ^10.0.0` añadido a `pubspec.yaml`.

### Changed
- **ux:** ícono de logout directo en AppBar del Dashboard reemplazado por 👤 **"Mi perfil"** (`Icons.person_outline`) → navega a `Routes.profile`. Logout queda en Pantalla 11.
- **nav:** `Routes.profile = '/profile'` en `route_names.dart`; ruta en `app_router.dart`.
  Dónde: `lib/services/users_service.dart`, `lib/providers/users_provider.dart`, `lib/screens/profile/profile_screen.dart`, `lib/screens/farms/dashboard_screen.dart`, `lib/navigation/route_names.dart`, `lib/navigation/app_router.dart`, `pubspec.yaml`.
- **fix(ux):** botón "Iniciar sesión" en pantalla de bienvenida ahora usa variante `light` (fondo blanco, texto verde) para ser visible sobre el fondo verde primario. Nuevo `AppButtonVariant.light` en `app_button.dart`.
  Dónde: `lib/widgets/common/app_button.dart`, `lib/screens/auth/welcome_screen.dart`.

## [1.6.0] - 2026-05-21 — feat(pdf): teléfono, email, GPS y fotos en trazabilidad (CU-25)

### Added
- **feat (CU-25):** `PdfTraceabilityService.build/buildAndShare` aceptan
  `producerPhone` y `producerEmail` opcionales. El resumen del PDF incluye
  filas "Teléfono" y "Email" cuando no están vacías.
- **feat (CU-25):** Fila "GPS (finca)" en el resumen cuando `Farm` tiene
  `latitude` y `longitude` no nulos, formateada como `"10.3932° N, 75.4832° W"`.
- **feat (CU-25):** Columna "Foto" en la tabla de actividades. Carga bytes
  del archivo local (`dart:io File.readAsBytes()`) usando `Activity.photoUrl`.
  Prefijos `file://` se descartan. Archivo no encontrado → thumbnail omitido
  sin crash (`on IOException`).
- **feat (CU-25):** `_activityTable` (solo texto) reemplazado por
  `_activityList` + `_activityHeaderRow` + `_activityDataRow` para soportar
  celdas con imágenes.
- **test:** `test/unit/pdf_traceability_service_test.dart` — 15 tests nuevos.
  Dónde: `lib/services/pdf_traceability_service.dart`,
  `lib/screens/plots/plot_detail_screen.dart`,
  `test/unit/pdf_traceability_service_test.dart`.

## [1.4.1] - 2026-05-20 — fix(auth): refresh interceptor coalescing + sesión-collapse sentinel (P1)
- **fix (P1):** `_AuthInterceptor` reescrito como `QueuedInterceptor` con cache single-flight `Future<String>? _refreshFuture` (patrón `fresh_dio`). Refresh ahora se coalesce: N requests paralelos que reciben 401 comparten UN solo `/auth/refresh`. Cierra el bug que producía banners "Credenciales incorrectas" en pantallas con múltiples providers concurrentes ([[CU-11]]/14/15/18/20/21).
- **fix:** `/auth/refresh` ahora corre sobre un Dio dedicado SIN interceptores → no recursión y no envío de Bearer vencido.
- **fix:** colapso del flujo de refresh (refresh 401/403 → token rotado server-side) emite ahora un `AuthSessionCollapsed` sentinel; `parseApiError` lo mapea a "Sesión expirada. Vuelve a iniciar sesión." en vez de mezclarlo con login-401.
- **fix:** `parseApiError` distingue 3 casos de 401: login → "Credenciales incorrectas", sesión colapsada → "Sesión expirada...", dominio → "No tienes permiso...".
- **fix:** `AuthNotifier.build()` ahora hace probe activo contra `/auth/refresh` en cold-start en vez de confiar en el `exp` client-side del JWT → ya no se aterriza en dashboard con sesión zombi.
- **fix:** retry budget per-request (max 1) impide loops infinitos de refresh; storage write atómico antes de liberar el future single-flight.
- 224 tests verdes (incluye `test/unit/auth_interceptor_test.dart` con 6 casos: 401-then-refresh, 5 concurrent 401s coalescen, refresh-401 → collapse + onLogout + storage cleared, refresh-5xx → transient, non-401 passthrough, `/auth/refresh` sin Bearer). `flutter analyze` limpio.

## [1.5.1] - 2026-05-21 — fix(sync): push envelope + fromJson snake_case — CU-22/CU-23 E2E pasa

- **fix (CU-23):** `SyncService._pushEnvelope` ahora desenvuelve `body['data']` igual que `_pullEnvelope`. El backend responde `{ success, data: { synced, conflicts, timestamp } }` pero el cliente leía `push['synced']` en el nivel raíz → siempre 0. `synced` y `conflicts` ahora se leen correctamente.
- **fix (CU-23):** `Farm.fromJson`, `Plot.fromJson`, `Activity.fromJson`, `Alert.fromJson` aceptan claves snake_case del pull de PostgreSQL (`crop_type`, `area_hectares`, `created_at`, `farm_id`, `plot_id`, `occurred_at`, `photo_url`, `scheduled_for`). La crash `type 'Null' is not a subtype of type 'String'` en `_applyPulledChange` está resuelta.
- **verified (CU-22):** E2E emulador AVD confirmado — finca creada offline con `syncStatus=pendingCreate`, UI renderiza sin red, offline indicator visible.
- **verified (CU-23):** E2E emulador AVD confirmado — `FarmRepo.getPending: 1 rows`, `server synced=1 conflicts=0 pulled=2`, `upsertFromServer` sin crashes. Batch-splitting >500 cambios no implementado (futura iteración).

## [1.5.0] - 2026-05-21 — feat(offline): capa de persistencia SQLite offline-first con Drift
- **feat:** Drift 2.x + drift_flutter integrados. Base de datos local `agritrace.db` con 4 tablas (`farms`, `plots`, `activities`, `alerts`) con columnas de sincronización (`syncStatus`, `updatedAt`) en cada fila.
- **feat:** 4 repositorios nuevos (`FarmRepository`, `PlotRepository`, `ActivityRepository`, `AlertRepository`) como capa de acceso a datos local. Escritura offline-first con estados `pendingCreate` / `pendingUpdate` / `pendingDelete`.
- **feat:** `SyncOrchestrator` drena cambios pendientes → POST `/v1/sync`, aplica cambios jalados del servidor con estrategia LWW (`updatedAt` del servidor gana). `SyncNotifier` auto-dispara sync 2 s después de reconexión vía `connectivityProvider`.
- **feat:** Providers de dominio (`farmsProvider`, `plotsProvider`, `activitiesProvider`, `alertsProvider`) actualizados a streams reactivos desde SQLite — responden instantáneamente sin conexión.
- **feat:** Seed inicial: al primer login/registro, `AuthNotifier` lanza `SyncOrchestrator.run()` en background para poblar la DB local.
- **chore:** `database_provider.dart` centraliza `appDatabaseProvider` + 4 repository providers + `syncOrchestratorProvider`.
- 223 tests verdes (unit + widget tests actualizados para mockear capa de repositorio). `flutter analyze` limpio.

## [Unreleased] - 2026-05-20 — feat(weather): trigger manual de chequeo de clima (CU-19)
- **feat:** acción "Actualizar clima" en AppBar de `alerts_screen`. Llama `POST /v1/alerts/weather/check` (provider `WEATHER_PROVIDER=stub` en prod) y refresca la lista de alertas con el resultado.
- **UX:** spinner inline durante la llamada + snackbar con resumen ("N alertas nuevas") o mensaje de error.
- 207 tests verdes (3 widget tests nuevos: happy + error + per-plot call). `flutter analyze` limpio.
- **pendiente:** cron backend / wiring de `WEATHER_PROVIDER=openweathermap` real → decisión post-pilot.

## [Unreleased] - 2026-05-20 — feat(activities): editar + eliminar actividad (CU-16 + CU-17)
- **feat:** pantalla `activity_edit_screen` con prefill, ruta `/activities/:id/edit`, entrada vía long-press en el timeline (bottom sheet "Editar / Eliminar"). Cierra CU-16.
- **feat:** acción "Eliminar" con `AlertDialog` de confirmación + refresh inmediato del timeline. Cierra CU-17.
- **refactor:** `ActivityForm` extraído como widget compartido entre create y edit (DRY), reubicado a `lib/screens/activities/widgets/activity_form.dart` (mismo patrón que `PlotForm`).
- **chore:** `AppCard` + `ActivityListItem` ganan `onLongPress` opcional (aditivo, no rompe call sites existentes); long-press espejado también en `plot_detail_screen` para que ambas superficies del timeline compartan el mismo flujo.
- 210 tests verdes (incluye 5 widget tests nuevos: 2 edit + 3 timeline long-press/delete). `flutter analyze` limpio.
- **nota trazabilidad:** edición destructiva sobre el registro original (no genera "nota correctiva"). Decisión a revisitar post-pilot si los productores piden auditoría inmutable.

## [Unreleased] - 2026-05-20 — feat(plots): editar + eliminar lote (CU-12 + CU-13)
- **feat:** pantalla `plot_edit_screen` con prefill, ruta `/plots/:id/edit`, entrada vía menú overflow en `plot_detail_screen`. Cierra CU-12.
- **feat:** acción "Eliminar lote" en `plot_detail_screen` con `AlertDialog` de confirmación + cascade visible (actividades del lote desaparecen). Cierra CU-13.
- **refactor:** `PlotForm` extraído como widget compartido entre create y edit (DRY).
- 204 tests verdes (incluye 4 widget tests nuevos: 2 edit + 2 delete). `flutter analyze` limpio.

## [Unreleased] - 2026-05-20 — fix(iso utc): P1 datetimes sin Z fallaban Zod 400
- **fix (P1):** `activity_service.dart` (`occurredAt` create/update),
  `alert_service.dart` (`scheduledFor` createReminder) y
  `sync_service.dart` (`since` query de `/sync/changes`) enviaban
  `DateTime.now().toIso8601String()` que devuelve local-time **sin sufijo `Z`**.
  Backend Zod `.datetime()` rechaza con 400 — "occurredAt must be an
  ISO 8601 datetime". Resultado: CU-14 (Registrar actividad), CU-18
  (Crear recordatorio) y CU-23 (sync pull) producían el banner
  genérico "Ocurrió un error".
- **fix:** todos los `.toIso8601String()` antes del envío al backend
  ahora son `.toUtc().toIso8601String()` (sufijo `Z` garantizado).
- 200 tests verdes, `flutter analyze` clean.

## [Unreleased] - 2026-05-20 — fix(api urls): P1 listar lotes/actividades 404
- **fix (P1):** `PlotService.listByFarm` y `ActivityService.listByPlot`
  usaban paths sin el prefijo de su router. Backend monta `plots` en
  `/v1/plots` y `activities` en `/v1/activities`, así que las rutas
  nesteadas son `/plots/farms/{farmId}/plots` y
  `/activities/plots/{plotId}/activities`. Mobile pegaba a
  `/farms/{farmId}/plots` y `/plots/{plotId}/activities` → **404 silencioso** →
  `parseApiError` fallback → "Ocurrió un error" inline en farm-detail y
  plot-detail screens (sección Lotes / Timeline de actividades).
- **fix:** `plot_service.dart:17` + `activity_service.dart:20` con
  comentarios de regresión + tests actualizados con los paths reales.
- 200 tests verdes, `flutter analyze` clean.

## [Unreleased] - 2026-05-20 — fix(crud): P1 navegación post-create silent error
- **fix (P1, bloqueador Sprint 5):** los FAB "+" (registrar finca / lote /
  actividad / alerta) usaban `context.go(...)` (REPLACE en go_router 14)
  para abrir el form, dejando la pila vacía. El form, tras un POST 201,
  llamaba `context.pop()` para volver a la lista → go_router lanzaba
  `GoError('There is nothing to pop')` que el catch del form rendía como
  el banner genérico `"Ocurrió un error, intenta de nuevo"` — mientras
  la fila SÍ se había creado en el backend (3 taps = 3 filas duplicadas).
- **fix:** 6 sitios de navegación cambiados de `context.go` a `context.push`:
  - `dashboard_screen.dart` FAB "Registrar finca"
  - `farm_detail_screen.dart` FAB "Agregar lote" + AppBar "Editar finca"
  - `plot_detail_screen.dart` FAB "Registrar actividad"
  - `activity_timeline_screen.dart` FAB "Registrar actividad"
  - `alerts_screen.dart` FAB "Recordatorio"
- **test:** `test/widget/form_nav_regression_test.dart` ancla el patrón
  push-then-pop para los 4 chains (farms / plots / activities / alerts).
  200 tests verdes, `flutter analyze` clean.

## [Unreleased] - 2026-05-20 — feat(cu-01-readiness): error_parser 409/429 + widget tests para Registro

### Fixed
- **fix (ux):** `parseApiError` mapea explícitamente `409 → "Ese email ya
  está registrado"` (único endpoint con 409 hoy: `POST /v1/auth/register`)
  y `429 → "Muchos intentos, intenta de nuevo en unos minutos"` (rate
  limiter de auth + general). Antes ambos caían al fallback genérico
  ("Ocurrió un error, intenta de nuevo"), ocultando la causa real al
  productor en CU-01 Flujo A y Flujo D. Dónde:
  `lib/utils/error_parser.dart`.

### Tests
- **test (cu-01):** `test/widget/cu_01_register_test.dart` (nuevo) —
  10 widget tests que cubren el Escenario principal + los 5 flujos
  alternos (A email-duplicado / B password-débil / C sin-consentimiento
  / D rate-limit / E sin-conexión) de
  [`CU-01-registro-productor.md`](../agritrace-docs/01-preparacion-mvp/03-mapeo-funcional/casos-de-uso/CU-01-registro-productor.md).
  Mockea `authServiceProvider` vía Riverpod override; el happy-path
  captura los named args y verifica que el payload incluye
  `privacyConsent: true` + `privacyConsentVersion: "1.0"` y **nunca**
  `role` (el rol lo asigna el servidor — defensa contra authz bypass).
- **test (unit):** `test/unit/error_parser_test.dart` — +2 branches
  (409 + 429). `error_parser.dart` mantiene 100 % de cobertura (8/8).
- **coverage:** global pasa de **84.6 %** a **85.6 %** (699/817).
  Cumple Criterio Técnico `09-scope-mvp.md §6` (≥80 %).

## [Unreleased] - 2026-05-20 — test: cobertura global a 84.6 % (meta ≥80 %)
- **test:** +70 tests nuevos (184 total). Cobertura global pasa de
  65.0 % a **84.6 %** (633/748 líneas) — cumple el Criterio Técnico
  de `09-scope-mvp.md §6`.
- **test:** 9 archivos test creados: `error_parser_test.dart`,
  `route_names_test.dart`, widget `app_error_banner_test.dart`,
  `user_model_test.dart`, `plot_model_test.dart`, `farm_model_test.dart`,
  `activity_model_test.dart`, `auth_service_test.dart`,
  `storage_service_test.dart`.
- **docs:** `docs/COVERAGE.md` — tabla por archivo, comando de repro,
  HTML report opcional, gap explícito de `api_service.dart` (no
  testeado por validación `String.fromEnvironment` + interceptor
  privado), snippet de CI floor para Sprint 6.
- 10 de 11 archivos target llegan a 88–100 %; `api_service.dart`
  intencionalmente diferido (gap documentado).

## [Unreleased] - 2026-05-19 — chore: intake del piloto (Sprint 5)
- **chore (intake):** plantillas de GitHub Issues para el field test:
  `field-test-bug.yml` (versión, dispositivo, conectividad, pasos,
  esperado vs real, captura) y `field-test-feedback.yml`
  (frecuencia de uso, fácil/difícil, qué falta, ¿recomendarías?).
- **chore:** `.github/ISSUE_TEMPLATE/config.yml` desactiva issues en
  blanco y deja un único contacto fuera de GitHub
  (`mailto:diegotrujillor@gmail.com`) para dudas no-bug.
- Etiquetas auto-aplicadas: `sprint-5`, `field-test`, + `bug`/
  `feedback` según corresponda — filtran el board del piloto.

## [Unreleased] - 2026-05-19 — chore: Play Console setup (assets + runbook)
- **chore (assets):** generados a partir del logo oficial y guardados
  en `assets/brand/play/`:
  - `icon-512.png` (ícono Play Store 512×512).
  - `feature-graphic.svg` + `feature-graphic.png` (1024×500).
- **ci:** `release-play.yml` añade `if: always()` al step *Archive AAB
  artifact* — el AAB firmado queda disponible como artifact incluso
  cuando la subida a Play falla (sin `PLAY_SERVICE_ACCOUNT_JSON`).
  Sirve para el primer upload manual obligatorio.
- **docs:** nuevo `docs/PLAY_CONSOLE_SETUP.md` — runbook completo
  paso-a-paso (cuenta, app, listing, content rating, primer AAB,
  service account, secret, closed testing 14d/12 testers).

## [Unreleased] - 2026-05-19 — fix: UX inputs auth
### Fixed
- **bug (ux):** ícono del ojo en campo Contraseña invertido — con texto
  oculto mostraba el ojo abierto (parecía visible). Ahora oculto =
  ojo tachado, visible = ojo abierto (login + registro).
- **bug (ux):** campo "Nombre completo" no capitalizaba la primera
  letra de cada palabra. `AppInput` gana parámetro opcional
  `textCapitalization` (default `none`); registro usa
  `TextCapitalization.words` solo en ese campo.
- Dónde: `lib/widgets/common/app_input.dart`,
  `lib/screens/auth/register_screen.dart`.

## [Unreleased] - 2026-05-19 — fix: sin red en APK release (login/registro)
### Fixed
- **bug (red):** login y registro mostraban "Sin conexión, verifica tu
  internet" en el APK release aunque el backend estaba arriba. Causa:
  el permiso `android.permission.INTERNET` solo estaba en los manifests
  `debug/` y `profile/` (scaffold Flutter), no en `main/`; el APK
  firmado se construye solo con `main/` → sin acceso a red → toda
  llamada HTTP fallaba sin respuesta (`error.response == null` →
  mensaje genérico de offline). Añadidos `INTERNET` y
  `ACCESS_NETWORK_STATE` a `main/AndroidManifest.xml`.
- Dónde: `android/app/src/main/AndroidManifest.xml`.

## [Unreleased] - 2026-05-19 — fix: crash al abrir + nombre de la app
### Fixed
- **bug (crash):** la app cerraba al abrir en Android. Causa:
  `applicationId`/`namespace` = `co.agritrace.app` pero `MainActivity.kt`
  seguía en el paquete `com.example.agritrace_mobile`; el manifest
  (`android:name=".MainActivity"`) resolvía a una clase inexistente →
  `ClassNotFoundException`. Movido a `co/agritrace/app/MainActivity.kt`
  (`package co.agritrace.app`); eliminado el paquete viejo.
- **bug (marca):** la app se instalaba como "agritrace_mobile".
  `android:label` → "AgriTrace".
- Dónde: `android/app/src/main/AndroidManifest.xml`,
  `android/app/src/main/kotlin/co/agritrace/app/MainActivity.kt`
  (eliminado `kotlin/com/example/agritrace_mobile/`).

## [Unreleased] - 2026-05-19 — branding ícono + nombre de APK
- **chore (marca):** ícono de launcher regenerado desde el logo oficial
  `agritrace-logo-mark.svg` (rasterizado a `assets/brand/icon-1024.png`
  1024², `flutter_launcher_icons`; iconos adaptativos + `colors.xml`).
  `ios: false` en config (proyecto Android-only).
- **ci:** `build-apk.yml` renombra el APK resultante a `AgriTrace.apk`
  (artifact + asset del GitHub Release).
- Dónde: `assets/brand/icon-1024.png`, `pubspec.yaml`,
  `android/app/src/main/res/{mipmap-*,drawable-*,mipmap-anydpi-v26,values/colors.xml}`,
  `.github/workflows/build-apk.yml`.

## [Unreleased] - 2026-05-19 — refactor de seams compartidos + fixes
### Added
- **refactor:** `lib/services/api_envelope.dart` (`unwrapEnvelope`,
  `unwrapOne`, `unwrapList`), `lib/utils/date_format.dart`
  (`formatLocalDate`), `lib/models/model_utils.dart` (`toDoubleOrNull`).
- **refactor:** widgets compartidos en `lib/widgets/common/`:
  `app_date_field.dart` (`AppDateField`), `app_labeled_dropdown.dart`
  (`AppLabeledDropdown<T>`), `info_row.dart` (`InfoRow`),
  `inline_error.dart` (`InlineError`), `error_state.dart` (`ErrorState`),
  `empty_state.dart` (`EmptyState`).
- **feat (gap):** `PlotService.delete` (`DELETE /plots/:id`) y
  `PlotsNotifier.deletePlot` — espejo de `FarmService`/`FarmsNotifier`.
- **test:** cobertura unitaria para los 5 providers (farms/plots/
  activities/alerts/sync) y 5 services de dominio + `test/unit/_helpers.dart`.
  73 tests nuevos (114 total); targets ≥80 % línea (services 88.9–100 %,
  providers 90.9–96 %).
### Changed
- **refactor:** activity/farm/plot/alert services usan los helpers de
  `api_envelope`; eliminados los 4 trios privados
  `_envelope/_unwrapOne/_unwrapList`.
- **refactor:** `farm.dart`/`plot.dart` usan `toDoubleOrNull`; eliminados
  los `_toDouble` privados duplicados.
- **refactor:** 5 copias de formato de fecha reemplazadas por
  `formatLocalDate` (activity/alert list item, pdf_traceability_service,
  activity/alert form screens).
- **refactor:** `_DateField`/`_LabeledDropdown`/`_CropTypeDropdown`/
  `_InfoRow`/`_InlineError`/`_ErrorState`/`_NoActivities`/`_NoPlots`/
  `_EmptyState` reemplazados por los widgets compartidos.
- **chore:** `appBarTheme` global en `buildAppTheme()`; eliminado el
  estilado redundante de `AppBar` en 9 pantallas (color/elevación/estilo
  de título ahora vienen del tema).
- **refactor:** `Alert.copyWith` ahora cubre todos los campos
  (id, type, severity, title, status, createdAt, plotId, body,
  scheduledFor), igual que `Farm`/`Plot`.
- **refactor:** `parseAuthError` → `parseApiError` (declaración + todos
  los call sites).
### Fixed
- **perf (bug):** `activity_timeline_screen` ordenaba las actividades
  dentro de `itemBuilder` (O(n²) al hacer scroll). Ahora se ordena una
  vez por emisión de datos; mismo patrón aplicado a
  `plot_detail_screen`.
- Dónde: `lib/services/{activity,farm,plot,alert}_service.dart`,
  `lib/services/api_envelope.dart`, `lib/services/pdf_traceability_service.dart`,
  `lib/models/{farm,plot,alert,model_utils}.dart`,
  `lib/utils/{date_format,theme,error_parser}.dart`,
  `lib/providers/plots_provider.dart`,
  `lib/widgets/common/{app_date_field,app_labeled_dropdown,info_row,inline_error,error_state,empty_state}.dart`,
  `lib/widgets/domain/{activity,alert}_list_item.dart`,
  `lib/screens/**` (forms, detalles, dashboard, alertas, timeline).

## [Unreleased] - 2026-05-19 — directrices de desarrollo en CLAUDE.md
- **docs:** se incorpora a `CLAUDE.md` el contenido relevante de
  `agritrace-docs/.../04-desarrollo/01-directrices-desarrollo.md`
  (principios, checklist de widgets/providers, seguridad, anti-patterns,
  testing, pre-commit).
- **chore:** instrucción obligatoria — usar el plugin `everything-claude-code`
  y sus skills para toda codificación, y anexar los cambios a este
  `CHANGELOG.md` al final de cada implementación.
- Dónde: `CLAUDE.md` (secciones "Development guidelines (MANDATORY)" y
  "Codification workflow (MANDATORY)").
- **chore (release):** firma release + AAB para Google Play.
  `versionCode`/`versionName` overridables por CI
  (`-PversionCode`/`VERSION_CODE`); `-PreleaseSigningRequired=true` falla
  el build si falta `key.properties` (evita AAB firmado en debug).
- **ci:** workflow `release-play.yml` — build AAB firmado + subida a
  Google Play (track `internal` por defecto) vía
  `r0adkll/upload-google-play`; `versionCode = github.run_number`.
- Dónde: `android/app/build.gradle.kts`, `android/key.properties.example`,
  `.github/workflows/release-play.yml`. Requiere secrets
  `PLAY_SERVICE_ACCOUNT_JSON` + keystore (`KEYSTORE_BASE64`, etc.).

## [1.2.0] - 2026-05-19 — Sprint 4: alertas + estado de sync
- **feat:** alertas (clima + recordatorios), indicador de estado de
  sincronización y entrada de alertas desde el dashboard.
- Dónde: `lib/models/alert.dart`, `lib/services/alert_service.dart`,
  `lib/providers/alerts_provider.dart`,
  `lib/screens/alerts/{alerts_screen,alert_form_screen}.dart`,
  `lib/widgets/domain/alert_list_item.dart`,
  `lib/widgets/common/sync_status_badge.dart`,
  `lib/navigation/{route_names,app_router}.dart`,
  `lib/screens/farms/dashboard_screen.dart` (acción "Alertas").
- Lista de alertas con descartar/eliminar + pull-to-refresh; formulario
  de recordatorio (título/fecha/nota); `SyncStatusBadge` toca para
  sincronizar y muestra sincronizados/conflictos; consume
  `/v1/alerts` y `/v1/alerts/weather/check`. 41 tests verdes;
  `flutter analyze` sin nuevos hallazgos.

## [1.1.0] - 2026-05-19 — Sprint 3: actividades + sync + PDF
- **feat:** registro/timeline de actividades, sincronización y reporte
  PDF de trazabilidad (W1c).
- Dónde: `lib/models/activity.dart`,
  `lib/services/{activity_service,sync_service,pdf_traceability_service}.dart`,
  `lib/providers/{activities_provider,sync_provider}.dart`,
  `lib/screens/activities/{activity_form,activity_timeline}_screen.dart`,
  `lib/widgets/domain/activity_list_item.dart`,
  `lib/screens/plots/plot_detail_screen.dart` (timeline + botón
  "Exportar PDF"), `lib/navigation/*`, `pubspec.yaml` (pdf, printing).

## [1.0.0] - 2026-05-19 — Release piloto: consentimiento + Sprint 2
Primer release distribuible (APK firmado). Acumula:
- **feat (Sprint 1):** pantallas auth — welcome/login/register/dashboard.
  Dónde: `lib/screens/auth/*`, `lib/providers/auth_provider.dart`,
  `lib/services/{api,auth,storage}_service.dart`, `lib/navigation/*`.
- **feat (marca):** logo/ícono oficiales + firma release + CI APK.
  Dónde: `assets/brand/*`, `android/` (signing), `.github/workflows/build-apk.yml`.
- **feat (Ley 1581):** checkbox de consentimiento + enlace a política
  en el registro. Dónde: `lib/screens/auth/register_screen.dart`,
  `lib/services/auth_service.dart`, `lib/providers/auth_provider.dart`,
  `pubspec.yaml` (url_launcher).
- **feat (Sprint 2):** fincas y lotes — modelos, servicios, providers,
  pantallas form/detail, lista en dashboard. Dónde: `lib/models/{farm,plot}.dart`,
  `lib/services/{farm,plot}_service.dart`,
  `lib/providers/{farms,plots}_provider.dart`,
  `lib/screens/{farms,plots}/*`, `lib/widgets/domain/farm_card.dart`,
  `lib/navigation/*`, `lib/utils/{constants,validators}.dart`.
- **fix:** hallazgos CRITICAL/HIGH de auditoría pre-piloto; colisión
  `invalid_override` en notifiers (`update`→`updateFarm/updatePlot`);
  permisos CI `contents:write` para publicar el Release.

## Sprint 1 (pre-tag) - 2026-05
- Scaffold inicial Flutter + arquitectura (Riverpod, go_router, Dio),
  `CLAUDE.md`. Incluido dentro de `1.0.0`.
