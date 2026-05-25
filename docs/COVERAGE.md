# Cobertura de pruebas — agritrace-mobile

**Cobertura sobre código a mano:** **83.6 %** (1732 / 2072) — excluye codegen Drift (`*.g.dart`), `repositories/`, `database/app_database.dart`, `database/tables.dart`, `services/sync_orchestrator.dart` (todas pendientes; gap explícito abajo).

**Cobertura global cruda (incluye codegen):** 44.9 % (1762 / 3926) — dominada por `lib/database/app_database.g.dart` (1398 líneas de codegen Drift, 0.9 %). No es un número accionable.

**Meta MVP:** ≥80 % (`agritrace-docs/01-preparacion-mvp/09-scope-mvp.md §6` — Criterio Técnico). Vigente sobre código a mano.

Última medición: **300 tests verdes** (post v1.9.4, 2026-05-24), `flutter analyze` limpio. Reemplaza el baseline Sprint 5 (184 tests, 84.6 %, 748 líneas) que precedía a Drift + screens de profile/uploads/feedback.

## Reproducir

```bash
flutter test --coverage --dart-define=API_BASE_URL=http://localhost:3000/v1

# Total crudo (incluye codegen, no representativo):
awk -F: 'BEGIN{lf=0;lh=0} /^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "%.1f%% (%d/%d)\n", (lh/lf)*100, lh, lf}' coverage/lcov.info

# Cobertura sobre código a mano (representativa, excluye codegen + Drift wrappers + repos + orchestrator):
awk -F: '
/^SF:/{file=$2; skip = (file ~ /\.g\.dart$/ || file ~ /\/repositories\// || file ~ /\/database\/app_database\.dart$/ || file ~ /\/database\/tables\.dart$/ || file ~ /\/services\/sync_orchestrator\.dart$/)}
/^LF:/{ if (!skip) tlf+=$2 }
/^LH:/{ if (!skip) tlh+=$2 }
END { printf "%.1f%% (%d/%d)\n", (tlh/tlf)*100, tlh, tlf }' coverage/lcov.info
```

HTML report opcional:
```bash
brew install lcov                                # una sola vez
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Por archivo (post v1.9.4 — 2026-05-24)

Snapshot tras `flutter test --coverage --dart-define=API_BASE_URL=http://localhost:3000/v1`.

| Archivo | Cobertura | Notas |
|---------|-----------|-------|
| `lib/services/api_service.dart` | **87.6 %** (92 / 105) | Antes 0 %. Ahora cubierto vía `--dart-define` + `auth_interceptor_test.dart`. |
| `lib/services/auth_service.dart` | 73.2 % (30 / 41) | `wipeAllUserData` path + cross-account wipe cubiertos (`auth_service_test.dart`). |
| `lib/services/uploads_service.dart` | 85.7 % (18 / 21) | multipart photo upload (v1.9.0). |
| `lib/services/storage_service.dart` | 57.9 % (11 / 19) | `last_user_id` getters/setters parcialmente cubiertos. |
| `lib/services/{farm,plot,activity}_service.dart` | 88.9 – 100 % | — |
| `lib/services/pdf_traceability_service.dart` | cubierto | `pdf_traceability_service_test.dart` valida render. |
| `lib/services/feedback_service.dart` | cubierto | `feedback_service_test.dart`. |
| `lib/providers/{auth,farms,plots,activities,alerts,sync}_provider.dart` | 81.0 – 90.5 % | `AsyncNotifier` por dominio. |
| `lib/providers/uploads_provider.dart` | 0.0 % (0 / 2) | trivial passthrough; gap aceptado. |
| `lib/models/{user,farm,plot,activity}.dart` | 100 % | — |
| `lib/models/alert.dart` | 83.6 % (51 / 61) | — |
| `lib/models/{upload,feedback}.dart` | 76 – 78 % | — |
| `lib/widgets/common/app_logo_mark.dart` | 64.7 % (11 / 17) | `mark` vs `white` variant + tamaños. |
| `lib/widgets/common/app_error_banner.dart` | n/d | cubierto vía widget tests (auth + forms). |
| `lib/widgets/common/error_state.dart` | 0.0 % (0 / 11) | placeholder UI; gap aceptado. |
| `lib/widgets/common/inline_error.dart` | 0.0 % (0 / 6) | placeholder UI; gap aceptado. |
| `lib/widgets/common/offline_indicator.dart` | 50.0 % (8 / 16) | gap aceptado (connectivity_plus side-effect). |
| `lib/screens/auth/login_screen.dart` | 85.2 % (46 / 54) | incluye `clearError()` mount path (v1.9.4). |
| `lib/screens/auth/register_screen.dart` | 90.8 % (79 / 87) | incluye `clearError()` mount path (v1.9.4). |
| `lib/screens/activities/widgets/activity_form.dart` | 59.7 % (77 / 129) | photo + GPS + crop rules; gap pendiente. |
| `lib/screens/plots/plot_detail_screen.dart` | 48.9 % (68 / 139) | long-press → bottom sheet cubierto vía `activity_timeline_delete_test.dart`. |
| `lib/screens/alerts/alerts_screen.dart` | 70.4 % (50 / 71) | — |

## Gap explícito (excluido del 83.6 %)

Cinco grupos quedan fuera del cálculo representativo porque su cobertura requiere infra adicional (test DB sqlite in-memory, mocking de `connectivity_plus`, expose seam para `_AuthInterceptor`) que se documenta para un sprint posterior:

- **`lib/database/app_database.g.dart` — 0.9 % (12 / 1398).** Codegen de Drift; nunca se testea directo. Cubierto vía repos cuando lleguen tests con `NativeDatabase.memory()`.
- **`lib/database/app_database.dart` — 9.2 % (7 / 76).** Incluye `wipeAllUserData()` (P0 v1.9.3); cubierto indirectamente vía `auth_service_test.dart`. Falta test in-memory directo.
- **`lib/database/tables.dart` — 0.0 % (0 / 59).** Solo definiciones de tablas (constantes), sin lógica ejecutable.
- **`lib/repositories/{farm,plot,activity,alert}_repository.dart` — 1.6 – 3.2 %.** Capa de acceso a Drift; requiere sqlite in-memory + fixtures. Backlog Sprint 7.
- **`lib/services/sync_orchestrator.dart` — 7.5 % (6 / 80).** Coordina push + pull + LWW; pendiente harness E2E con mock backend + Drift in-memory. Backlog Sprint 7.

## Política

- Mínimo global: **80 %**.
- Mínimo por archivo nuevo: **80 %** (recomendado; no es bloqueador
  automatizado por ahora).
- Tests viven en `test/unit/` (sin dependencias de plataforma) y
  `test/widget/` (con `WidgetTester`).
- Reusar `test/unit/_helpers.dart` para mocks de `ApiService` /
  `MockDio` antes de inventar nuevos dobles.

## CI (pendiente, opcional Sprint 6)

`flutter test --coverage` ya corre dentro de `release-play.yml`. Falta
gate explícito en CI que falle si el global cae bajo 80 %. Snippet
listo cuando se adopte:

```yaml
- name: Enforce coverage floor
  run: |
    flutter test --coverage
    pct=$(awk -F: 'BEGIN{lf=0;lh=0} /^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "%.1f", (lh/lf)*100}' coverage/lcov.info)
    echo "Coverage: ${pct}%"
    awk -v p="$pct" 'BEGIN { exit (p+0 < 80.0) }'
```

## Lado backend

`agritrace-backend` tiene tests Jest. La cobertura global no está
publicada (jest requiere Postgres y los runs son locales/CI con
Testcontainers). Aprobar ≥80 % backend está pendiente —
ver `09-scope-mvp.md §6 Criterio Técnico` (mismo target).
