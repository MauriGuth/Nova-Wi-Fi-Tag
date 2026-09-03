# Nova Wi-Fi Tag

App iOS + App Clip para que un invitado se conecte a tu Wi-Fi **tocando un sticker NFC con el iPhone, sin instalar nada**.

```
sticker NFC ──► https://wifi.novasolutions.ar/t/<tagId>
                 │
                 ├─ iPhone: iOS muestra la tarjeta del App Clip "Nova Wi-Fi" → Abrir
                 │          → el clip lee la URL, pide GET /api/tags/<tagId>.json
                 │          → botón "Conectarme a <nombre>" → NEHotspotConfiguration → iOS confirma y conecta
                 │
                 ├─ Android: el segundo registro NDEF (Wi-Fi WSC) hace que el teléfono ofrezca conectarse solo
                 │
                 └─ Sin App Clip / desktop: la misma URL abre la página de fallback (clave, perfil .mobileconfig, QR)
```

Tag de prueba: `casa`. Tag de demo para el revisor de App Store: `demo` (red ficticia `NovaDemo`).

## Estado

| Parte | Qué hay | Qué te falta hacer |
|---|---|---|
| A · iOS | `project.yml` (XcodeGen), app `NovaWifiTag`, clip `NovaWifiTagClip`, código en `Shared/`, entitlements, Info.plist, íconos, Team ID `ABS5DYM6TB` | `xcodegen generate` y compilar en tu Mac |
| B · Web | `web/` desplegado en producción en el proyecto Vercel `wifi-tag` (AASA con el Team ID real, `/t/casa`, `/api/tags/casa.json`, `gen.py`) | Asignar el dominio `wifi.novasolutions.ar` |
| C · Manual | Este README, `ExportOptions.plist`, scripts en `scripts/`, imagen 1800×1200 en `assets/` | Pasos 1–5 de abajo |

> **Team ID.** Ya está configurado `ABS5DYM6TB` (el de *Membership details* en https://developer.apple.com/account) en `project.yml`, `ExportOptions.plist` y `web/.well-known/apple-app-site-association`.
> En Xcode elegí el equipo que muestra ese ID, no el "Personal Team" (`ZN8QX5WGT3`) que aparece en el certificado gratuito. Si algún día cambia, `scripts/set-team-id.sh <ID>` lo reemplaza en los tres archivos.

## Estructura

```
project.yml                     spec de XcodeGen → NovaWifiTag.xcodeproj (no se versiona, se genera)
ExportOptions.plist             para xcodebuild -exportArchive (sube a App Store Connect)
Shared/                         código común app + clip
  NovaConfig.swift              host y URLs (/t/<id>, /api/tags/<id>.json)
  TagCredentials.swift          modelo: id, name, ssid, password, security (WPA2 / WPA2-WPA3 / WPA-WPA2 / OPEN)
  TagAPIClient.swift            GET del JSON con URLSession (async/await)
  InvocationURL.swift           parseo de /t/<tagId>
  WifiJoiner.swift              NEHotspotConfiguration (joinOnce=false, alreadyAssociated = éxito, errores en español)
  ConnectViewModel.swift        estados: esperando / cargando / listo / conectando / conectado / error
  ConnectCardView.swift         pantalla "Conectarme" (la misma en app y clip)
NovaWifiTag/                    app completa (ar.novasolutions.wifitag)
  Storage/                      lista de redes en el Keychain
  NFC/                          WSCPayload (TLVs), TagMessageBuilder (NDEF + tamaño), NFCTagWriter (CoreNFC)
  Views/                        Mis redes, alta/edición, detalle, Conectarme, Grabar sticker
NovaWifiTagClip/                App Clip (ar.novasolutions.wifitag.Clip): una sola pantalla
web/                            proyecto Vercel "wifi-tag" (reemplaza a ~/wifi-tag)
  .well-known/apple-app-site-association
  api/tags/<id>.json            credenciales que lee el clip
  t/<id>/index.html             página de fallback   ┐ generados por
  t/<id>/wifi.mobileconfig      perfil Wi-Fi iOS      ┘ gen.py
  gen.py, templates/page.html, vercel.json, robots.txt, index.html (→ /t/casa)
scripts/                        set-team-id.sh · build-sim.sh · archive.sh · verify-web.sh · make-icons.py
assets/appclip-card-1800x1200.png   imagen para la App Clip Experience
```

## Parte A · Proyecto iOS

Requisitos: Xcode 15.4 o posterior (por el `method = app-store-connect` de `ExportOptions.plist`; con un Xcode más viejo usá `app-store`), `brew install xcodegen`.

```bash
xcodegen generate                      # crea NovaWifiTag.xcodeproj (el Team ID ya está en project.yml)
xcodebuild -project NovaWifiTag.xcodeproj -scheme NovaWifiTag     -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project NovaWifiTag.xcodeproj -scheme NovaWifiTagClip -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
# o todo junto: scripts/build-sim.sh
```

Cómo está armado:

- **Targets.** `NovaWifiTag` (`application`) embebe a `NovaWifiTagClip` (`application.on-demand-install-capable`) vía la dependencia del target; XcodeGen genera la fase *Embed App Clips*. iOS 16.0 mínimo, SwiftUI, sin dependencias externas, solo iPhone.
- **Entitlements** (archivos `.entitlements` escritos a mano y referenciados desde `project.yml` con `CODE_SIGN_ENTITLEMENTS`; no se usa la clave `entitlements:` de XcodeGen porque regeneraría los archivos vacíos):
  - App: `associated-appclip-app-identifiers`, `networking.HotspotConfiguration`, `networking.wifi-info`, `nfc.readersession.formats = [NDEF, TAG]`, `associated-domains = [applinks:wifi.novasolutions.ar, applinks:wifi.novasolutions.ar?mode=developer]`.
  - Clip: `parent-application-identifiers`, `associated-domains = [appclips:wifi.novasolutions.ar, appclips:wifi.novasolutions.ar?mode=developer]`, `networking.HotspotConfiguration`, `networking.wifi-info`.
  - `wifi-info` (Access Wi-Fi Information) se usa después de `apply` para comprobar con `NEHotspotNetwork.fetchCurrent` que el iPhone quedó unido al SSID pedido: `apply` puede terminar sin error aunque iOS muestre "No se pudo conectar a la red".
  - La entrada sin sufijo es la que usan TestFlight y App Store. La entrada `?mode=developer` solo la respetan los builds instalados desde Xcode en un iPhone con *Ajustes → Desarrollador → Associated Domains Development* activado: hace que el iPhone lea el AASA directo de tu servidor en vez de la CDN de Apple.
- **Solo iPhone.** `TARGETED_DEVICE_FAMILY = 1` está puesto a nivel target (el preset iOS de XcodeGen pondría `1,2`); si algún día querés iPad, agregá las cuatro orientaciones en los Info.plist o App Store Connect rechaza el build (ITMS-90474).
- **Info.plist.** La app declara `NFCReaderUsageDescription`; el clip declara `NSAppClip` con `NSAppClipRequestEphemeralUserNotification = false` y `NSAppClipRequestLocationConfirmation = false`.
- **Invocación.** El clip usa `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` y lee `activity.webpageURL`. El scheme `NovaWifiTagClip` tiene la variable de entorno `_XCAppClipURL = https://wifi.novasolutions.ar/t/casa` para simular el tap desde Xcode. La app completa recibe la misma URL como enlace universal y abre la pantalla "Conectarme".
- **App completa** (Apple exige que tenga todo lo que hace el clip): lista de redes guardada en el Keychain, "Conectarme" con el mismo código del clip y "Grabar sticker" con CoreNFC. Al grabar se muestra el tamaño del mensaje NDEF y avisa si supera los 137 bytes de un NTAG213 (el sticker `casa` con URL + Wi-Fi ocupa 124 bytes).
- **Registro Wi-Fi para Android** (`application/vnd.wfa.wsc`): TLVs big-endian, Credential `0x100E` con Network Index `0x1026` (=1), SSID `0x1045`, Auth Type `0x1003` (`0x0020` WPA2-Personal, `0x0022` WPA/WPA2 mixta, `0x0001` abierta), Encryption Type `0x100F` (`0x0008` AES, `0x000C` TKIP+AES, `0x0001` ninguna), Network Key `0x1027` y MAC `0x1020` (6 × `0xFF`). WPA2/WPA3 se graba como WPA2-Personal porque WSC no define WPA3.
- **Simulador.** Compila, pero `NEHotspotConfiguration` y CoreNFC no funcionan ahí: la app lo avisa. Probá en un iPhone.

## Parte B · Backend estático (Vercel, proyecto `wifi-tag`)

La carpeta `web/` es el proyecto completo. Lo que había en `~/wifi-tag` quedó reestructurado así:

| Antes | Ahora |
|---|---|
| `/index.html` | `/t/casa/index.html` (`/` redirige a `/t/casa`) |
| `/wifi.mobileconfig` | `/t/casa/wifi.mobileconfig` (`/wifi.mobileconfig` redirige 308, para no romper enlaces viejos) |
| — | `/.well-known/apple-app-site-association` (JSON, sin redirects) |
| — | `/api/tags/casa.json` y `/api/tags/demo.json` (`Cache-Control: no-store`) |

`vercel.json` pone `Content-Type: application/json` en el AASA, `application/x-apple-aspen-config` en `*.mobileconfig`, `X-Robots-Tag: noindex` en todo y `trailingSlash: false` (así `/t/casa` sirve la página directo, sin `/` final, que es lo que va en el sticker).

Generar un tag nuevo (página + perfil + JSON):

```bash
cd web
pip3 install segno                      # una vez (QR)
./gen.py --id casa --name "Wi-Fi de Mauri" --ssid IPLAN-Mauri-5.8GHz --password Huentelaf1 --security WPA2 --org Mauri
./gen.py --id demo --name "Red de prueba Nova" --ssid NovaDemo --password demo-2026-nova
```

Publicar y verificar:

```bash
cd web && npx vercel --prod             # CLI logueada, scope sistema-de-stock, proyecto wifi-tag
scripts/verify-web.sh https://wifi-tag.vercel.app        # hoy
scripts/verify-web.sh https://wifi.novasolutions.ar      # cuando esté el dominio
```

> Para que `npx vercel --prod` apunte al proyecto existente desde esta carpeta: `cd web && npx vercel link` (elegí `sistema-de-stock` / `wifi-tag`). Después podés borrar `~/wifi-tag` o dejarlo como copia; la fuente de verdad pasa a ser `web/` en este repo.

Ya está desplegado en producción (ver "Verificación" al final).

## Parte C · Lo que te queda a vos

### 1. Dominio en Vercel

1. Vercel → proyecto `wifi-tag` → *Settings → Domains* → **Add** `wifi.novasolutions.ar`.
2. DNS de `novasolutions.ar`: `CNAME wifi → cname.vercel-dns.com`. (Hoy `wifi.novasolutions.ar` ya responde desde Vercel con `DEPLOYMENT_NOT_FOUND`, así que es probable que el CNAME ya exista y solo falte asignarlo al proyecto.)
3. Verificá: `scripts/verify-web.sh https://wifi.novasolutions.ar`.
4. Apple no lee el AASA desde tu servidor sino desde su CDN. Chequeá que lo tome (puede tardar hasta 24 h): `curl -s https://app-site-association.cdn-apple.com/a/v1/wifi.novasolutions.ar`. Mientras tanto, para probar en tu iPhone con builds de Xcode (clip y app), activá *Ajustes → Desarrollador → Associated Domains Development* (para eso están las entradas `?mode=developer` de los entitlements).

### 2. Xcode: cuenta y capabilities

1. `xcodegen generate`; abrí `NovaWifiTag.xcodeproj`.
2. *Xcode → Settings → Accounts*: iniciá sesión con la cuenta del Developer Program. Tiene que aparecer el equipo `ABS5DYM6TB`; si solo ves el Personal Team, la cuenta no es la del programa pago.
3. En cada target, *Signing & Capabilities* tiene que mostrar *Automatically manage signing* con tu equipo y las capabilities que salen de los `.entitlements`:
   - `NovaWifiTag`: Associated Domains, Hotspot Configuration, Access Wi-Fi Information, Near Field Communication Tag Reading, App Clip (identificador asociado).
   - `NovaWifiTagClip`: Associated Domains, Hotspot Configuration, Access Wi-Fi Information, On Demand Install Capable (Xcode lo agrega solo para este tipo de target).
4. Xcode registra los App IDs `ar.novasolutions.wifitag` y `ar.novasolutions.wifitag.Clip` y habilita esas capabilities en el portal. Si ves *"Provisioning profile doesn't include the … entitlement"*, entrá a https://developer.apple.com/account/resources/identifiers/list, habilitá la capability faltante en el App ID y en Xcode tocá *Try Again*.

### 3. Probar en el iPhone

- **Desde Xcode**: elegí el scheme `NovaWifiTagClip`, tu iPhone como destino y *Run*. El clip arranca con `_XCAppClipURL = https://wifi.novasolutions.ar/t/casa`, muestra "Wi-Fi de Mauri" y el botón "Conectarme a Wi-Fi de Mauri". iOS pide confirmación y conecta (`alreadyAssociated` también cuenta como éxito).
- **Tap real con el sticker** (antes de que la experiencia esté aprobada en App Store Connect):
  1. Dejá el clip instalado desde Xcode.
  2. *Ajustes → Desarrollador → Local Experiences → Register Local Experience*: URL Prefix `https://wifi.novasolutions.ar/t/casa`, Bundle ID `ar.novasolutions.wifitag.Clip`, título "Nova Wi-Fi", subtítulo "Conectate al Wi-Fi", acción **Open**, y una imagen cualquiera.
  3. Grabá el sticker (paso 5) y acercá el iPhone con la pantalla encendida: aparece la tarjeta del clip → *Abrir* → *Conectarme*.
  4. Para probar el enlace universal en la app completa: instalá el scheme `NovaWifiTag` (con *Associated Domains Development* activado, o esperá a que la CDN de Apple tenga el AASA) y volvé a tocar el sticker; abre la app directo en "Conectarme".
- Si en vez de la tarjeta se abre Safari: revisá que el primer registro NDEF sea la URL, que la Local Experience esté registrada con la URL exacta y que el iPhone sea XS o posterior (lectura NFC en segundo plano).

### 4. App Store Connect

1. https://appstoreconnect.apple.com → *Apps → +*: nombre "Nova Wi-Fi Tag", bundle ID `ar.novasolutions.wifitag`, SKU `nova-wifi-tag`.
2. Subí el build (con el clip embebido). `ExportOptions.plist` ya está con `method = app-store-connect` y `destination = upload`:

   ```bash
   xcodegen generate
   xcodebuild -project NovaWifiTag.xcodeproj -scheme NovaWifiTag -configuration Release \
     -destination 'generic/platform=iOS' -archivePath build/NovaWifiTag.xcarchive archive -allowProvisioningUpdates
   xcodebuild -exportArchive -archivePath build/NovaWifiTag.xcarchive \
     -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
   # o: scripts/archive.sh
   ```

   Si preferís subir con Transporter, cambiá `destination` a `export` y arrastrá el `.ipa` de `build/export`. Tamaño del clip: `du -sh build/NovaWifiTag.xcarchive/Products/Applications/NovaWifiTag.app/AppClips/NovaWifiTagClip.app` (límite 15 MB en iOS 16; este clip pesa muy poco).
3. En la app → pestaña **App Clip** (aparece cuando el build procesado incluye el clip):
   - **Default App Clip Experience**: imagen `assets/appclip-card-1800x1200.png` (podés reemplazarla por una con tu marca, 1800×1200 px, sin transparencia), subtítulo "Conectate al Wi-Fi sin escribir la clave", acción **Abrir** (Open).
   - **Advanced App Clip Experience** → *Edit Advanced Experiences → +*: URL `https://wifi.novasolutions.ar/t/casa`, título "Wi-Fi de Mauri", subtítulo "Tocá Abrir y después Conectarme", imagen 1800×1200, acción **Abrir**. Apple matchea por prefijo: si registrás `https://wifi.novasolutions.ar/t/` cubrís todos los stickers con una sola experiencia; agregá la de `/t/demo` si querés que el revisor la vea listada.
4. *App Review Information → Notes* (usá este texto, ajustalo si cambiás el demo):

   > Nova Wi-Fi Tag lets a guest join a home Wi-Fi network by tapping an NFC sticker with their iPhone. The sticker holds the URL https://wifi.novasolutions.ar/t/<tagId>. iOS shows the App Clip card; the clip fetches the network credentials from https://wifi.novasolutions.ar/api/tags/<tagId>.json and calls NEHotspotConfigurationManager, so iOS asks the user to confirm before joining. The full app additionally stores networks locally (Keychain), offers the same "Connect" screen, and writes NFC stickers with CoreNFC.
   >
   > How to test: invoke the App Clip with https://wifi.novasolutions.ar/t/demo (or open that URL with the full app installed). It shows the demo network "NovaDemo" and the button "Conectarme a Red de prueba Nova". Tapping it triggers the iOS join prompt; because "NovaDemo" (password demo-2026-nova) is a fictional network, iOS reports that the network could not be found and the app shows that error. With a real network the flow ends with the device connected. No account or login is required. Hotspot Configuration is used only to join the network the user tapped.

5. Enviá a revisión. Con el build en TestFlight también podés probar el clip: TestFlight → la app → *App Clip Invocations → + Invocation URL*.

### 5. Grabar el sticker

- **Con la app**: *Mis redes → + → nombre, SSID `IPLAN-Mauri-5.8GHz`, clave, seguridad, Tag ID `casa` → Guardar → Grabar sticker*. Muestra los dos registros y el tamaño; con URL + Wi-Fi son 124 bytes (entra en NTAG213: 137 bytes). Acercá el sticker cuando iOS lo pida.
- **Con NFC Tools** (iOS o Android): *Write → Add a record*:
  1. **URL**: `https://wifi.novasolutions.ar/t/casa` (tiene que ser el primer registro: iOS solo lanza el App Clip si el registro 1 es la URL).
  2. **Wi-Fi network**: SSID `IPLAN-Mauri-5.8GHz`, autenticación WPA2-Personal, cifrado AES, clave `Huentelaf1`.
  3. *Write*.
- Cuando el sticker esté grabado con el mensaje correcto, la app (o NFC Tools) lo lee y podés dejarlo de solo lectura si querés que nadie lo sobrescriba.

## Verificación

- Backend en producción (`https://wifi-tag.vercel.app`, y `wifi.novasolutions.ar` cuando asignes el dominio): `scripts/verify-web.sh` comprueba AASA (200, `application/json`), `/api/tags/casa.json`, `/t/casa` (HTML) y el `.mobileconfig` (`application/x-apple-aspen-config`).
- Lógica Swift sin UI (modelo, cliente, WSC, NDEF, parseo de URL) verificada con un toolchain Swift 6 en modo de lenguaje 5: los bytes del registro WSC y los tamaños NDEF coinciden con los calculados a mano.
- `xcodegen generate` + `xcodebuild` para simulador: corrélos en tu Mac (`scripts/build-sim.sh`); este repo se generó sin Xcode.

## Notas

- El JSON de `/api/tags/<id>.json` es público, igual que la página de fallback: cualquiera con la URL ve la clave. Si querés reducir exposición, usá tagIds no adivinables (`gen.py --id casa-7f3a9`) o cambiá la clave del Wi-Fi periódicamente y regenerá.
- Para que la app y el clip acepten un tagId nuevo, alcanza con generar sus archivos con `gen.py` y hacer deploy: el clip no tiene nada hardcodeado por tag.
- Las entradas `?mode=developer` de los associated domains solo las usan los builds instalados desde Xcode; TestFlight y App Store usan las entradas sin sufijo. Podés dejar las dos.
- Revisión estática del código: además del typecheck en Linux, el Swift, el `project.yml`, los plist y el backend pasaron por una ronda de revisores independientes (SwiftUI/iOS 16, CoreNFC, NetworkExtension, XcodeGen, App Clip, WSC, Vercel) con verificación cruzada contra la documentación de Apple/XcodeGen; lo confirmado ya está corregido. Igual, la prueba real es `scripts/build-sim.sh` en tu Mac y el tap en el iPhone.
