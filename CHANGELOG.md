# Changelog — agritrace-mobile

Formato [Keep a Changelog](https://keepachangelog.com/). Cada versión =
tag git `vX.Y.Z` → APK firmado adjunto al GitHub Release vía CI
(`.github/workflows/build-apk.yml`). "Dónde" indica archivos tocados.

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
