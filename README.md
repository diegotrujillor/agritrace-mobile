# agritrace-mobile

App móvil del MVP de **AgriTrace** — plataforma de trazabilidad agrícola para pequeños y medianos productores en Colombia.

> Estrategia MVP: **Farmer-First · Mobile-Only · Offline-First**. El agricultor registra actividades sin conexión durante 14+ días. Marketplace con compradores internacionales es later release.
>
> **Validación comercial MVP**: Valle del Cauca, modelo híbrido Mes 1 gratis + $29.990 COP/mes Mes 2. Demo navegable: [`agritrace-demo`](https://github.com/diegotrujillor/agritrace-demo). Estrategia: [`agritrace-docs/01-preparacion-mvp/10-comercial-gtm/`](https://github.com/diegotrujillor/agritrace-docs/tree/main/01-preparacion-mvp/10-comercial-gtm).

## Stack Técnico

| Capa | Tecnología |
|------|------------|
| Framework | Flutter 3.x |
| Lenguaje | Dart |
| Almacenamiento local | WatermelonDB (offline-first) |
| Estado | Riverpod |
| Navegación | GoRouter |
| HTTP | Dio |
| Almacenamiento seguro | flutter_secure_storage |
| Testing | flutter_test + mocktail |
| Plataformas | iOS + Android |

## Pantallas MVP (10 pantallas — Flujo Productor)

| # | Pantalla | Sprint |
|---|----------|--------|
| 1 | Bienvenida | 1 |
| 2 | Registro | 1 |
| 3 | Login | 1 |
| 4 | Dashboard vacío | 1 |
| 5 | Dashboard con fincas | 2 |
| 6 | Registrar finca | 2 |
| 7 | Vista finca | 2 |
| 8 | Registrar lote | 2 |
| 9 | **Vista lote + timeline actividades** ⭐ | 3 |
| 10 | **Registrar actividad** ⭐ | 3 |

> Pantallas later release (Generar QR, Trazabilidad pública) diferidas hasta validar demanda con compradores.

## Flujo de Navegación

```
splash → welcome → login ──────────────────────────────→ dashboardFincas
                 → register → dashboardVacio → registerFinca → vistaFinca
                                                             → registrarLote → vistaFinca
                                                             → vistaLote → registrarActividad → vistaLote
```

## Estructura del Proyecto

```
agritrace-mobile/
├── lib/
│   ├── screens/
│   │   ├── auth/          # welcome, login, register
│   │   ├── farms/         # dashboard, farm_form, farm_detail
│   │   ├── plots/         # plot_form, plot_detail
│   │   └── activities/    # activity_form, activity_timeline
│   ├── widgets/
│   │   ├── common/        # AppButton, AppInput, AppCard, OfflineIndicator
│   │   └── domain/        # FarmCard, ActivityListItem
│   ├── navigation/        # GoRouter setup, route names
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   ├── sync_service.dart   # Sync Drift ↔ backend
│   │   └── storage_service.dart
│   ├── database/
│   │   ├── database.dart       # Drift DB init
│   │   ├── models/             # Farm, Plot, Activity (modelos locales)
│   │   └── migrations/
│   ├── providers/              # Riverpod providers por dominio
│   │   ├── auth_provider.dart
│   │   ├── farms_provider.dart
│   │   └── sync_provider.dart
│   ├── utils/                  # validators, formatters, constants
│   └── main.dart
├── test/
│   ├── unit/
│   └── widget/
├── pubspec.yaml
└── README.md
```

## Sistema de Diseño

```dart
// Colores
const primaryGreen  = Color(0xFF2D7A3E);
const darkGreen     = Color(0xFF1B5028);
const lightGreen    = Color(0xFFE8F5E9);
const earthBrown    = Color(0xFF6D4C3D);
const harvestYellow = Color(0xFFF9A825);
const certBlue      = Color(0xFF1976D2);

// Tipografía: Inter (Google Fonts) — mínimo 16px body, touch targets ≥44px
// Espaciado base 8px: xs=4 · sm=8 · md=16 · lg=24 · xl=32
// Dimensiones mobile-only: 375 × 812 px
```

## Setup Local

### Prerequisitos
- Flutter SDK 3.x (`flutter --version`)
- Android Studio o Xcode
- Emulador o dispositivo físico
- **[agritrace-backend](https://github.com/diegotrujillor/agritrace-backend) corriendo en `localhost:3000`** — el login y la sincronización requieren la API. Levanta el backend primero.

### 1. Clonar y configurar

```bash
git clone https://github.com/diegotrujillor/agritrace-mobile.git
cd agritrace-mobile
flutter pub get
```

### 2. Ejecutar

La configuración se pasa por `--dart-define` (no hay archivo `.env`):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/v1   # emulador Android → localhost
flutter run --dart-define=API_BASE_URL=http://localhost:3000/v1   # simulador iOS
```

## Variables de configuración

Se inyectan en build/run vía `--dart-define` (default en código: `http://10.0.2.2:3000/v1`):

| Variable | Ejemplo | Uso |
|----------|---------|-----|
| `API_BASE_URL` | `https://api.agritrace.co/v1` | Backend del piloto (dispositivo real) |
| `API_BASE_URL` | `http://10.0.2.2:3000/v1` | Emulador Android → backend local |

## Build distribuible (APK Android, piloto)

Requiere Android SDK (`ANDROID_HOME`). Firma release vía
`android/key.properties` + keystore (ambos git-ignored — ver
"Firma / keystore" abajo).

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.agritrace.co/v1
# salida: build/app/outputs/flutter-apk/app-release.apk  (instalación directa / sideload)
```

### Firma / keystore (secreto — NO se versiona)

`android/agritrace-release.keystore` + `android/key.properties` están en
`.gitignore`. Para reconstruir en otra máquina/CI: generar con
`keytool -genkeypair -keystore agritrace-release.keystore -alias agritrace
-keyalg RSA -keysize 2048 -validity 10000` y crear `android/key.properties`
con `storePassword/keyPassword/keyAlias=agritrace/storeFile=agritrace-release.keystore`.
**Resguardar keystore + passwords en gestor de contraseñas** — perderlo
impide publicar actualizaciones de la app.

## Offline-First

El app usa **Drift** como base de datos local (SQLite):
- Todos los datos se guardan localmente primero
- `sync_service` sincroniza con el backend al recuperar conexión (`POST /v1/sync`)
- `OfflineIndicator` muestra estado de conexión en tiempo real
- Garantía: **14+ días sin conexión** sin pérdida de datos

## Testing

```bash
flutter test                  # Todos los tests
flutter test --coverage       # Coverage report (objetivo: 80%+)
flutter test test/unit/
flutter test test/widget/
```

## Referencia de Implementación

| Artefacto | Ubicación |
|-----------|-----------|
| Prototipo React navegable | [`agritrace-prototype › agritrace_prototype.jsx`](https://github.com/diegotrujillor/agritrace-prototype/blob/main/agritrace_prototype.jsx) |
| Código Flutter de referencia | [`agritrace-prototype › agritrace_flutter_main.dart`](https://github.com/diegotrujillor/agritrace-prototype/blob/main/agritrace_flutter_main.dart) |
| Especificaciones de pantallas | [`agritrace-docs › 04-diseno-ui-ux`](https://github.com/diegotrujillor/agritrace-docs/tree/main/01-preparacion-mvp/04-diseno-ui-ux) |
| Scope MVP | [`agritrace-docs › 09-scope-mvp.md`](https://github.com/diegotrujillor/agritrace-docs/blob/main/01-preparacion-mvp/09-scope-mvp.md) |

## Repositorios Relacionados

| Repo | Descripción |
|------|-------------|
| [`agritrace-docs`](https://github.com/diegotrujillor/agritrace-docs) | Documentación técnica, DB schema, API spec, UI/UX |
| [`agritrace-backend`](https://github.com/diegotrujillor/agritrace-backend) | Node.js + TypeScript API REST |
| [`agritrace-prototype`](https://github.com/diegotrujillor/agritrace-prototype) | Prototipo React navegable + código Flutter de referencia |

---

*AgriTrace — Trazabilidad que conecta · MVP · Mayo 2026*

---

## Licencia

**Copyright © 2025–2026 Diego Trujillo R.**

Este proyecto está publicado bajo **MIT + Commons Clause**:

- ✅ Puedes estudiar, modificar y redistribuir el código para uso personal o no comercial
- ✅ Puedes contribuir mejoras (pull requests bienvenidos)
- ❌ **No puedes vender** este software ni ofrecer servicios comerciales basados en él sin autorización expresa del autor

Ver [`LICENSE`](LICENSE) para el texto completo.  
Uso comercial → [diegotrujillor@gmail.com](mailto:diegotrujillor@gmail.com)
