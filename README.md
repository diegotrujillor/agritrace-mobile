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
| Almacenamiento local | Drift (SQLite offline-first) |
| Estado | Riverpod |
| Navegación | GoRouter |
| HTTP | Dio |
| Almacenamiento seguro | flutter_secure_storage |
| Testing | flutter_test + mocktail |
| Plataformas | iOS + Android |

### Cómo interactúan las 9 capas

Cada componente de la tabla de arriba conectado con los demás, con el rol concreto que cumple en runtime.

```mermaid
flowchart TB
    subgraph plat[📱 Plataformas runtime]
        AND[🤖 Android APK]
        IOS[🍎 iOS bundle]
    end

    subgraph app[🎨 App proceso Flutter Dart]
        SCR[📺 Screens StatelessWidget]
        WID[🧩 Widgets reusables comunes]
        SCR --- WID
    end

    ROUTER[🧭 GoRouter app_router.dart]
    RIV[🔁 Riverpod AsyncNotifier]
    DIO[🌐 Dio HTTP client]
    DRIFT[💾 Drift SQLite local]
    SS[🔐 flutter_secure_storage Keychain Keystore]

    subgraph testing[🧪 Testing dev-only]
        FT[flutter_test]
        MT[mocktail mocks]
    end

    AND -. empaqueta y ejecuta .-> app
    IOS -. empaqueta y ejecuta .-> app

    SCR -->|context go push pop| ROUTER
    ROUTER -->|monta widget tree por ruta| SCR
    SCR -->|ref watch listen| RIV
    RIV -->|invoca services| DIO
    RIV -->|invoca services| DRIFT
    RIV -->|invoca services| SS

    DIO -. lee tokens y agrega Bearer header .-> SS
    DRIFT -. SQLite file en app sandbox .-> plat
    SS -. cifrado nativo Keychain en iOS Keystore en Android .-> plat

    FT -. test widget render .-> SCR
    FT -. test unit estado .-> RIV
    MT -. mockea Dio .-> DIO
    MT -. mockea Drift .-> DRIFT
```

### Rol de cada capa

| Capa de la tabla | Rol concreto en runtime | Vive en `lib/` |
|------------------|--------------------------|----------------|
| Flutter 3.x + Dart | El proceso entero. Render declarativo del widget tree. | todo `lib/` |
| Drift SQLite | Source of truth local; UI siempre lee de aquí. Sync envía cambios al backend en background. | `lib/database/` |
| Riverpod | Pega screens con services. Mantiene 3 estados loading data error en cada `AsyncNotifier`. | `lib/providers/` |
| GoRouter | Mapea URLs a widget trees + ejecuta auth redirect en cada navegación. | `lib/navigation/` |
| Dio | Cliente HTTP único. `_AuthInterceptor` agrega Bearer y refresca tokens en 401. | `lib/services/api_service.dart` |
| flutter_secure_storage | Único lugar autorizado para guardar access y refresh token; usa Keychain en iOS, Keystore en Android. | `lib/services/storage_service.dart` |
| flutter_test + mocktail | Solo en `test/`. mocktail produce dobles para Dio y Drift; tests cubren providers + widgets críticos. | `test/unit/`, `test/widget/` |
| iOS + Android | Targets de build. Una codebase Dart, dos binarios firmados. | `android/`, `ios/` |

> Foto-instantánea: los tokens nunca dejan `flutter_secure_storage`. Si la APK es decompilada, el atacante NO obtiene credenciales de GitHub ni del backend. El backend valida cada request con JWT firmado HS256.

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

```mermaid
flowchart LR
    SPL[🚀 Splash] --> WEL[👋 Welcome]
    WEL --> LOG[🔐 Login]
    WEL --> REG[📝 Register]
    LOG --> DASH[📊 Dashboard]
    REG --> DASH
    DASH --> CF[🌱 Crear finca]
    DASH --> VF[🏞️ Vista finca]
    VF --> CL[📐 Crear lote]
    CL --> VF
    VF --> VL[📋 Vista lote y timeline]
    VL --> CA[🧑‍🌾 Registrar actividad]
    CA --> VL
    DASH --> PROF[👤 Mi perfil]
    PROF --> RI[🐞 Reportar problema]
    PROF --> ER[🗑️ Eliminar cuenta]
    PROF --> EX[💾 Exportar mis datos]
    PROF --> LOGOUT[🚪 Logout]
    LOGOUT --> WEL
    ER --> WEL
```

> GoRouter implementa este grafo en `lib/navigation/app_router.dart`. El redirect de auth fuerza `/welcome` para usuarios no autenticados y `/dashboard` para los autenticados; las pantallas con asterisco están condicionadas a tener sesión activa.

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

## Diagramas internos

Vista funcional + sincronización local-remoto. Para el stack completo (Cloudflare, Caddy, backend, Postgres, Object Storage) ver [`agritrace-docs/01-preparacion-mvp/06-infraestructura/README.md → Diagrama del Stack`](https://github.com/diegotrujillor/agritrace-docs/blob/main/01-preparacion-mvp/06-infraestructura/README.md#diagrama-del-stack--vista-funcional).

### Arquitectura por capas (UI a base de datos local)

Riverpod media entre las pantallas y los servicios. La UI **siempre** lee de Drift (source of truth local); el sync con backend ocurre en background.

```mermaid
flowchart TB
    USER[👨‍🌾 Productor]
    USER --> UI

    subgraph ui[📱 Capa UI lib screens y lib widgets]
        UI[Screens StatelessWidget]
        WID[Widgets comunes AppButton AppInput AppCard OfflineIndicator]
        UI --- WID
    end

    UI -->|watch o listen| PROV

    subgraph state[🔁 Estado lib providers Riverpod]
        PROV[AsyncNotifier por dominio]
        AUTH_P[auth_provider]
        FARMS_P[farms_provider]
        SYNC_P[sync_provider]
        FEEDBACK_P[feedback_provider]
        PROV --- AUTH_P
        PROV --- FARMS_P
        PROV --- SYNC_P
        PROV --- FEEDBACK_P
    end

    PROV --> SVC

    subgraph services[🔌 Services lib services]
        API_S[ApiService Dio + _AuthInterceptor]
        AUTH_S[AuthService]
        USERS_S[UsersService export y deleteMe]
        SYNC_S[SyncService Drift a backend]
        STORE_S[StorageService FlutterSecureStorage]
        FB_S[FeedbackService]
        SVC[Services] --- API_S
        SVC --- AUTH_S
        SVC --- USERS_S
        SVC --- SYNC_S
        SVC --- STORE_S
        SVC --- FB_S
    end

    SVC -->|UI lee siempre local| LOCAL[💾 Drift SQLite lib database]
    SVC -->|push o pull cuando hay red| NET[🌐 Dio a https api.agritrace.co v1]
    STORE_S -.->|tokens cifrados| KEY[🔐 Keychain o Keystore]

    LOCAL -.->|connectivity_plus dispara sync| SYNC_S
```

**Reglas no negociables** (ver [`CLAUDE.md`](CLAUDE.md)):

| Capa | Recibe | Devuelve | No puede |
|------|--------|----------|----------|
| Screen widget | rutas + provider watch | UI declarativa | tener lógica de negocio |
| Provider AsyncNotifier | inputs del usuario | estado loading data error | tocar Drift directo desde build |
| Service | tipos del dominio | tipos del dominio o throw | depender de Flutter widgets |
| Drift DB | SQL tipado | rows | exponerse fuera de services |
| Dio ApiService | DTOs | envelope success data | bypass del _AuthInterceptor |

### Flujo de sincronización (offline-first)

Qué pasa cuando el productor registra una actividad sin red y luego recupera conexión. Garantía MVP: 14 días offline sin pérdida.

```mermaid
sequenceDiagram
    autonumber
    participant P as 👨‍🌾 Productor
    participant UI as 📱 Pantalla
    participant Prov as 🔁 Provider Riverpod
    participant Drift as 💾 Drift local
    participant Sync as 🔄 SyncService
    participant Conn as 📡 connectivity_plus
    participant API as ⚙️ Backend

    Note over P,Drift: 80 por ciento del tiempo sin red en la finca
    P->>UI: Registrar actividad siembra
    UI->>Prov: invoca crear
    Prov->>Drift: INSERT con syncStatus pendingCreate y updatedAt now
    Drift-->>Prov: id local generado
    Prov-->>UI: optimistic update con badge pendiente

    Note over Sync,API: Cuando hay red detectada
    Conn->>Sync: ConnectivityResult wifi o mobile
    Sync->>Drift: SELECT WHERE syncStatus pendingCreate o pendingUpdate
    Drift-->>Sync: changes pendientes
    Sync->>API: POST v1 sync con array changes y JWT Bearer
    API->>API: aplica con LWW updatedAt cliente como reloj
    API-->>Sync: 200 con synced count y conflicts ids y timestamp
    Sync->>Drift: UPDATE filas a syncStatus synced

    Note over Sync,Drift: Pull de cambios del servidor
    Sync->>API: GET v1 sync changes since last_synced_at
    API-->>Sync: cambios remotos del servidor reloj
    Sync->>Drift: apply remotes y resuelve LWW por updatedAt
    Sync-->>UI: badge OK sin pendientes
```

> Detalle del protocolo: [`CLAUDE.md → Sync protocol`](CLAUDE.md). Casos de uso afectados: CU-22 (trabajar offline), CU-23 (reconectar y sincronizar), CU-24 (LWW conflict resolution) en [`agritrace-docs/01-preparacion-mvp/03-mapeo-funcional/casos-de-uso/`](https://github.com/diegotrujillor/agritrace-docs/tree/main/01-preparacion-mvp/03-mapeo-funcional/casos-de-uso).

### Flujo de autenticación (vista cliente)

Ciclo completo desde tap inicial hasta refresh automático en 401. Complementa el server-side flow del backend en [`agritrace-backend/README.md → Flujo de autenticación`](https://github.com/diegotrujillor/agritrace-backend/blob/main/README.md#flujo-de-autenticación-jwt-access--refresh).

```mermaid
sequenceDiagram
    autonumber
    participant P as 👨‍🌾 Productor
    participant UI as 📱 LoginScreen
    participant Prov as 🔁 authProvider
    participant AS as 🔌 AuthService
    participant DIO as 🌐 Dio + _AuthInterceptor
    participant SS as 🔐 flutter_secure_storage
    participant API as ⚙️ Backend

    Note over P,API: Login inicial CU-02
    P->>UI: Tap Iniciar sesion con email password
    UI->>Prov: invoca login
    Prov->>AS: login email password
    AS->>DIO: POST v1 auth login con body
    DIO->>API: HTTPS request sin Bearer aun
    API-->>DIO: 200 con accessToken refreshToken user
    DIO-->>AS: response data
    AS->>SS: write access_token y refresh_token cifrados
    AS-->>Prov: AuthAuthenticated user
    Prov-->>UI: estado autenticado, GoRouter redirect a dashboard

    Note over P,API: Uso normal de cualquier endpoint protegido
    P->>UI: navega o ejecuta accion
    UI->>Prov: invoca operacion ejemplo cargar fincas
    Prov->>DIO: GET v1 farms
    DIO->>SS: read access_token
    SS-->>DIO: token vigente
    DIO->>API: HTTPS GET con Authorization Bearer
    API-->>DIO: 200 con data

    Note over P,API: Token expirado, refresh transparente
    P->>UI: navega o ejecuta otra accion
    UI->>Prov: invoca operacion
    Prov->>DIO: GET v1 alerts
    DIO->>SS: read access_token
    SS-->>DIO: token expirado o sera rechazado
    DIO->>API: HTTPS GET con Bearer viejo
    API-->>DIO: 401 token expired
    DIO->>SS: read refresh_token
    SS-->>DIO: refresh vigente
    DIO->>API: POST v1 auth refresh con refresh
    API-->>DIO: 200 con tokens rotados nuevos
    DIO->>SS: write access_token y refresh_token nuevos
    DIO->>API: retry GET v1 alerts con Bearer nuevo
    API-->>DIO: 200 con data
    DIO-->>Prov: response data, UI nunca vio el 401

    Note over P,API: Logout CU-03
    P->>UI: Tap Cerrar sesion en ProfileScreen
    UI->>Prov: invoca logout
    Prov->>AS: logout
    AS->>SS: read refresh_token
    AS->>DIO: POST v1 auth logout con refresh
    DIO->>API: HTTPS POST con Bearer del access
    API-->>DIO: 200 con success true
    AS->>SS: delete access_token y refresh_token
    AS-->>Prov: AuthUnauthenticated
    Prov-->>UI: GoRouter redirect a welcome

    Note over P,API: Token comprometido escenario de seguridad
    DIO->>API: cualquier request con Bearer revocado
    API->>API: verifyAccessToken consulta revoked_tokens en PG
    API-->>DIO: 401 token revoked
    DIO->>API: POST v1 auth refresh con refresh
    API-->>DIO: 401 refresh tambien revocado
    DIO->>SS: delete tokens forzar logout
    DIO-->>UI: trigger redirect a welcome con mensaje sesion expirada
```

**Garantías de seguridad cliente-side:**

| Aspecto | Cómo lo cumple el app |
|---------|------------------------|
| Tokens nunca en plain storage | `flutter_secure_storage` usa **Keychain en iOS** (Secure Enclave cuando hay TouchID/FaceID) y **Keystore en Android** (StrongBox cuando hay hardware). Single source de truth. |
| Refresh transparente al usuario | `_AuthInterceptor` (`api_service.dart`) intercepta cualquier 401, refresca, reintenta. La UI nunca ve el 401 si el refresh es vigente. |
| Concurrencia segura | El interceptor tiene un single-flight lock: si 5 requests fallan a la vez con 401, sólo 1 dispara el refresh; las otras 4 esperan al nuevo token. Evita refresh-storm + tokens divergentes. |
| Logout limpio | `AuthService.logout` borra ambos tokens del Keychain/Keystore antes de redirigir. Imposible reusar la sesión post-logout. |
| Refresh comprometido | Si el backend invalida también el refresh (`401` en `/auth/refresh`), el interceptor borra ambos tokens y dispara redirect a `/welcome`. No retry loop infinito. |
| API base configurable | `--dart-define=API_BASE_URL=...` en build time. El APK release apunta a `https://api.agritrace.co/v1`; debug builds pueden apuntar a localhost. |

> CU-01 (registro), CU-02 (login), CU-03 (logout) están en [`agritrace-docs/01-preparacion-mvp/03-mapeo-funcional/casos-de-uso/`](https://github.com/diegotrujillor/agritrace-docs/tree/main/01-preparacion-mvp/03-mapeo-funcional/casos-de-uso). La implementación vive en `lib/services/auth_service.dart`, `lib/services/api_service.dart` (interceptor), `lib/providers/auth_provider.dart`.

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

### Pipeline de release (de git tag a tester)

Un `git tag vX.Y.Z` dispara dos workflows en paralelo: uno para el APK de side-load (canal del piloto) y otro para el AAB del Play Console (canal post-pilot).

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 💻 Diego local
    participant Repo as 📦 agritrace-mobile main
    participant W1 as 🤖 Build Release APK workflow
    participant W2 as 🤖 Release to Google Play workflow
    participant GH as 🐙 GitHub Release
    participant Play as 🛍️ Play Console
    participant Land as 🌐 agritrace.co instalar
    participant Tester as 👨‍🌾 Tester

    Dev->>Repo: git tag vX.Y.Z y git push --tags
    Repo->>W1: tag dispara build-apk yml
    Repo->>W2: tag dispara release-play yml en paralelo

    Note over W1: 1 flutter analyze, 2 flutter build apk release, 3 firma con KEYSTORE_BASE64 desde secrets, 4 verifica apksigner v2 v3, 5 limpia key.properties
    W1->>GH: action-gh-release sube AgriTrace.apk al release de la tag

    Note over W2: 1 flutter analyze, 2 flutter test, 3 flutter build appbundle release, 4 firma AAB, 5 archiva AAB como artifact
    W2->>Play: upload signed AAB al track configurado
    W2->>GH: archive AAB como build artifact respaldo

    Note over GH,Land: landing apex agritrace.co instalar redirige a releases latest download AgriTrace.apk
    Tester->>Land: tap boton verde Descargar AgriTrace
    Land->>GH: 302 a /releases/latest/download/AgriTrace.apk
    GH-->>Tester: APK firmado, instalar encima
```

**Características:**

| Aspecto | Cómo lo implementamos |
|---------|------------------------|
| Trigger | Solo `git tag vX.Y.Z + git push --tags`. Push a `main` sin tag **no** dispara release. |
| Secreto del keystore | `KEYSTORE_BASE64` en GitHub Actions Secrets. Se decodifica al filesystem del runner, se usa, se borra antes del cleanup step. |
| Verificación de firma | `apksigner verify --verbose --print-certs` confirma v2 + v3 schemes. Falla el job si no firma correctamente. |
| Canal de distribución actual | GitHub Release APK descargada desde `agritrace.co/#instalar` (mientras Play Internal testing no esté listo). |
| Canal post-pilot | Play Console internal testing → closed alpha → producción. Build pipeline ya emite el AAB hoy aunque el track Play sea no-op hasta que se complete `PLAY_CONSOLE_SETUP.md`. |
| Rollback de APK | Tester re-descarga la tag anterior desde GitHub Releases e instala encima. **No pierde datos** (Drift SQLite local persiste; mismo certificado de firma). |
| Idempotencia | Re-ejecutar el mismo tag falla en el upload (action-gh-release rechaza tag existente). Bump de patch obligado. |

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
