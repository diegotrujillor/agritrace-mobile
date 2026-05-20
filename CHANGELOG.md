# Changelog — agritrace-mobile

Formato [Keep a Changelog](https://keepachangelog.com/). Cada versión =
tag git `vX.Y.Z` → APK firmado adjunto al GitHub Release vía CI
(`.github/workflows/build-apk.yml`). "Dónde" indica archivos tocados.

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
