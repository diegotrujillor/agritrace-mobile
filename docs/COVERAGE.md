# Cobertura de pruebas — agritrace-mobile

**Cobertura global de líneas:** **84.6 %** (633 / 748)
**Meta MVP:** ≥80 % (`agritrace-docs/01-preparacion-mvp/09-scope-mvp.md §6` — Criterio Técnico).

Última medición: 184 tests verdes, `flutter analyze` limpio.

## Reproducir

```bash
flutter test --coverage
awk -F: 'BEGIN{lf=0;lh=0} /^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "%.1f%% (%d/%d)\n", (lh/lf)*100, lh, lf}' coverage/lcov.info
```

HTML report opcional:
```bash
brew install lcov                                # una sola vez
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Por archivo (Sprint 5 baseline — 2026-05-20)

| Archivo | Antes | Ahora |
|---|---|---|
| `lib/utils/error_parser.dart` | 0.0 % | **100.0 %** |
| `lib/navigation/route_names.dart` | 0.0 % | **100.0 %** |
| `lib/widgets/common/app_error_banner.dart` | 0.0 % | **88.9 %** |
| `lib/services/auth_service.dart` | 0.0 % | **100.0 %** |
| `lib/models/user.dart` | 3.3 % | **100.0 %** |
| `lib/services/storage_service.dart` | 9.1 % | **100.0 %** |
| `lib/models/plot.dart` | 32.4 % | **100.0 %** |
| `lib/models/farm.dart` | 34.5 % | **100.0 %** |
| `lib/models/activity.dart` | 39.5 % | **100.0 %** |
| `lib/models/alert.dart` | 75.5 % | 75.5 % |
| `lib/services/{farm,plot,activity,alert,sync}_service.dart` | (refactor PR) | 88.9 – 100 % |
| `lib/providers/{auth,farms,plots,activities,alerts,sync}_provider.dart` | (refactor PR) | 86.4 – 96.0 % |

## Gap explícito

- **`lib/services/api_service.dart` — 0 % (0 / 57 líneas).**
  El constructor valida `String.fromEnvironment('API_BASE_URL')` y arroja
  `StateError` cuando está vacío; bajo `flutter test` sin
  `--dart-define=API_BASE_URL=...` la construcción rompe. Además el
  interceptor `_AuthInterceptor` es una clase privada sin seam público.
  Probarlo requeriría exponer un seam (refactor de producción) o
  invocar los tests con `--dart-define`. El target global ≥80 % se
  cumple sin necesidad — gap documentado para un sprint posterior si
  se desea cobertura total del archivo.

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
