# Changelog — agritrace-mobile

Formato [Keep a Changelog](https://keepachangelog.com/). Cada versión =
tag git `vX.Y.Z` → APK firmado adjunto al GitHub Release vía CI
(`.github/workflows/build-apk.yml`). "Dónde" indica archivos tocados.

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
