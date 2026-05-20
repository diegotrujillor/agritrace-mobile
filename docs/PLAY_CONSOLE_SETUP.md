# Google Play Console — Setup runbook

> Una vez completados los pasos manuales aquí, el workflow `release-play.yml`
> publica automáticamente cada tag `v*.*.*` a la pista **Internal testing**.

## Estado actual

- Paquete: `co.agritrace.app`
- Builds: APK (`AgriTrace.apk`) + AAB firmados producidos en CI.
- Releases públicos GitHub: `https://github.com/diegotrujillor/agritrace-mobile/releases`
- Política de privacidad: [01-politica-privacidad.md](https://github.com/diegotrujillor/agritrace-docs/blob/main/01-preparacion-mvp/08-legal/01-politica-privacidad.md)
- Cuenta Play: **nueva personal** (sujeta a política 2023+: 14 días de
  Closed testing con ≥12 testers antes de habilitar Production).

## Pre-flight (assets ya generados en repo)

| Asset | Tamaño | Ruta |
|---|---|---|
| Ícono Play | 512×512 PNG | `assets/brand/play/icon-512.png` |
| Feature graphic | 1024×500 PNG | `assets/brand/play/feature-graphic.png` |
| Source SVG | — | `assets/brand/play/feature-graphic.svg` |
| Logo oficial | SVG | `assets/brand/agritrace-logo-mark.svg` |

Pendientes a capturar **en el Pixel 7 Pro** (Play exige ≥2):
- Screenshot 1: pantalla Dashboard con al menos una finca + lote.
- Screenshot 2: pantalla de actividades (timeline).
- Screenshot 3 (opcional): alerta climática.

Subir a `assets/brand/play/screenshots/` si se versionan en repo.

## Paso 1 — Crear cuenta Play Console

1. https://play.google.com/console/signup → cuenta **personal**.
2. Pagar **USD 25** (una sola vez).
3. **Verificación de identidad** (puede tomar varios días). Mientras
   tanto sólo se puede preparar borrador; nada se publica.
4. Aceptar Developer Distribution Agreement.

## Paso 2 — Crear la app

1. Play Console → **All apps → Create app**.
2. Nombre: `AgriTrace`
3. Default language: `es-CO`
4. App or game: **App**
5. Free or paid: **Free** (MVP)
6. Declaraciones obligatorias: confirmar políticas + US export laws.

## Paso 3 — Play App Signing (obligatorio)

Por defecto Play habilita **Play App Signing**: Google guarda la app
signing key; tu `agritrace-release.keystore` queda como **upload key**.

> **No subir** la upload key keystore a Play. Sólo el AAB firmado con
> ella. La upload key vive como `KEYSTORE_BASE64` en GitHub Secrets.

## Paso 4 — Ficha de Play Store (Store listing)

Menú izquierdo: **Grow → Store presence → Main store listing**.

### Textos sugeridos (es-CO)

**App name (30 chars)**
```
AgriTrace
```

**Short description (80 chars)**
```
Trazabilidad agrícola para pequeños productores del Valle del Cauca.
```

**Full description (≤4000 chars)**
```
AgriTrace es una app móvil para que pequeños y medianos productores
del Valle del Cauca registren sus fincas, lotes y actividades agrícolas
del día a día. Funciona sin conexión y sincroniza cuando vuelve la red.

Para qué sirve

• Registrar fincas y lotes con su cultivo principal (cacao, caña,
  hortalizas, frutas).
• Llevar un timeline de actividades (siembra, fertilización, riego,
  control fitosanitario, cosecha).
• Recibir alertas climáticas y recordatorios por lote.
• Generar reportes PDF de trazabilidad por lote.
• Operar 14 días sin internet — la sincronización es automática al
  reconectarse.

Para quién

Productores agrícolas en el piloto MVP del Valle del Cauca. La
información personal se trata bajo la Ley 1581 / Decreto 1377 (Habeas
Data) — ver la política de privacidad antes de registrarse.

Contacto
diegotrujillor@gmail.com
```

**Categoría**: `Productivity` (alterna: `Business`)
**Tags**: agricultura, trazabilidad, fincas, productor, Colombia.

### Gráficos requeridos

| Campo Play | Archivo |
|---|---|
| App icon | `assets/brand/play/icon-512.png` |
| Feature graphic | `assets/brand/play/feature-graphic.png` |
| Phone screenshots (mín. 2) | capturar del Pixel 7 Pro |

### Contacto

- Email: `diegotrujillor@gmail.com`
- Sitio web: `https://github.com/diegotrujillor/agritrace-docs`
- Política de privacidad: `https://github.com/diegotrujillor/agritrace-docs/blob/main/01-preparacion-mvp/08-legal/01-politica-privacidad.md`

## Paso 5 — Content rating, target audience, data safety

Submenú **Policy and programs**:

1. **App content → Privacy policy**: pegar la URL de privacidad.
2. **App content → Ads**: `Contains ads = No`.
3. **App content → App access**: marcar que requiere login (cuenta de
   prueba: email + clave del registro local — entregar como "Login
   credentials"). El reviewer Google necesita poder entrar a la app.
4. **App content → Content rating**: completar cuestionario (Productivity,
   audiencia general). Resultado esperado: **Everyone / PEGI 3**.
5. **App content → Target audience**: edad **18+** (manejo de datos
   personales bajo Ley 1581; evitar audiencias infantiles).
6. **App content → Data safety**: declarar datos recolectados (Email,
   Nombre, Teléfono, Ubicación aproximada vía lat/long de fincas).
   Marcar "Encrypted in transit" y "Users can request data deletion"
   (apunta a la ruta `/v1/users/me DELETE` ya implementada).

## Paso 6 — Primer AAB (manual)

La API de Play **no puede crear el primer release**; debe subirse
manualmente una vez.

1. Obtener el AAB firmado más reciente desde GitHub Actions:
   - https://github.com/diegotrujillor/agritrace-mobile/actions/workflows/release-play.yml
   - Abrir el run del tag actual → descargar artifact
     `agritrace-app-release-aab` (siempre archivado, incluso si la
     subida a Play falla).
2. Play Console → **Release → Testing → Internal testing → Create new release**.
3. Subir `app-release.aab`.
4. Release name: `<tag>` (ej. `1.3.3`).
5. Release notes (es-CO):
   ```
   Versión inicial del piloto. Registro, fincas, lotes, actividades,
   alertas, sincronización offline, PDF de trazabilidad.
   ```
6. **Save → Review → Start rollout to Internal testing**.
7. Añadir lista de testers (emails de productores piloto) en
   **Testers tab → Create email list**. Compartir el opt-in link
   (`https://play.google.com/apps/internaltest/...`). El instalador
   pasa por Play Store → **sin advertencia de Play Protect**.

## Paso 7 — Service account para CI uploads

Habilita los uploads automáticos por tag.

### En Google Cloud Console

1. https://console.cloud.google.com → crear proyecto `agritrace-play`
   (o reusar uno existente).
2. **APIs & Services → Library** → habilitar **Google Play Android
   Developer API**.
3. **IAM & Admin → Service Accounts → Create**:
   - Nombre: `play-publisher`
   - Skip role assignment (los permisos se otorgan en Play Console).
4. En el service account creado → **Keys → Add Key → Create new key →
   JSON**. Descargar el JSON.

### En Play Console

1. **Setup → API access** → Link the Google Cloud project que tiene el
   API habilitada.
2. Encontrar la service account en la lista → **Grant access**.
3. Permisos mínimos:
   - **Releases → Release to testing tracks** ✓
   - **Releases → Release to production** ✓ (cuando aplique)
   - **Store presence → Manage store presence** (opcional)
4. **Invite → Send**.

### En GitHub

1. Repo `agritrace-mobile` → **Settings → Secrets and variables →
   Actions → New repository secret**.
2. Nombre: `PLAY_SERVICE_ACCOUNT_JSON`
3. Valor: pegar el contenido completo del JSON descargado (raw,
   incluyendo `{ "type": "service_account", ... }`).

## Paso 8 — Verificar pipeline

1. Dispatch manual: Actions → **Release to Google Play → Run workflow
   → track=internal**. (O empujar un tag nuevo `v1.3.4`.)
2. Confirmar que el step `Upload AAB to Google Play` ahora pasa verde.
3. En Play Console → Internal testing → debe aparecer la nueva versión
   sin intervención manual.

## Paso 9 — Closed testing en paralelo

Política Play 2023+ (cuenta personal nueva): se requieren **14 días
continuos de Closed testing con ≥12 testers únicos** antes de que la
opción "Production" se desbloquee.

1. **Release → Testing → Closed testing → Create new release** con el
   mismo AAB.
2. Crear lista `closed-testers` con ≥12 emails (productores piloto +
   familiares/conocidos confiables).
3. Compartir opt-in link.
4. Mantener Closed activo 14 días continuos. Solicitar acceso a
   Production después.

## Estado actual del workflow

`release-play.yml` ya hace:
- Build firmado del AAB con `versionCode = github.run_number`.
- `flutter test` + `analyze` antes de empaquetar.
- Subida a la pista `track=internal` (default) — falla mientras
  `PLAY_SERVICE_ACCOUNT_JSON` no exista.
- **Siempre** archiva el AAB como artifact `agritrace-app-release-aab`
  (incluso si la subida falla — útil para el Paso 6).

Una vez completado el Paso 7, todo tag `v*.*.*` queda publicado en
Internal testing automáticamente.
