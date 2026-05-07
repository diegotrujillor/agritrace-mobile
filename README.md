# agritrace-mobile

App móvil del MVP de **AgriTrace** — plataforma de trazabilidad agrícola para pequeños y medianos productores en Colombia.

> Estrategia MVP: **Farmer-First · Mobile-Only · Offline-First**. El agricultor registra actividades sin conexión durante 14+ días. Marketplace con compradores internacionales es Phase 2.

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

> Pantallas Phase 2 (Generar QR, Trazabilidad pública) diferidas hasta validar demanda con compradores.

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
│   │   ├── sync_service.dart   # Sync WatermelonDB ↔ backend
│   │   └── storage_service.dart
│   ├── database/
│   │   ├── database.dart       # WatermelonDB init
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

// Tipografía: Inter (principal) · Poppins SemiBold 600 (logo)
// Espaciado base 8px: xs=4 · sm=8 · md=16 · lg=24 · xl=32
// Dimensiones mobile-only: 375 × 812 px
```

## Setup Local

### Prerequisitos
- Flutter SDK 3.x (`flutter --version`)
- Android Studio o Xcode
- Emulador o dispositivo físico

### 1. Clonar y configurar

```bash
git clone https://github.com/diegotrujillor/agritrace-mobile.git
cd agritrace-mobile
flutter pub get
cp .env.example .env
```

### 2. Ejecutar

```bash
flutter run                  # Dispositivo/emulador conectado
flutter run -d emulator-5554
```

## Variables de Entorno

```env
API_BASE_URL=http://10.0.2.2:3000/v1   # Android emulator → localhost
# API_BASE_URL=http://localhost:3000/v1  # iOS simulator
```

## Offline-First

El app usa **WatermelonDB** como base de datos local:
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

*AgriTrace — Trazabilidad que conecta · MVP Phase 1 · Mayo 2026*
