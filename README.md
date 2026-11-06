# IScan

Lector de códigos QR para **iOS 9 / armv7**, pensado para un iPad mini 1 con
jailbreak. Lee cualquier QR —WiFi, enlaces, contactos, eventos, correo,
teléfono, SMS, ubicaciones, `otpauth` y texto— y, si el código es de tipo WiFi,
**intenta conectarse directamente a la red**. Si no puede, copia la contraseña
y abre Ajustes para pegarla.

La interfaz está en español, en tema oscuro y construida enteramente en código
(sin storyboards ni XIB), para que se vea nítida en la pantalla no retina del
iPad mini 1.

## Contenido que entiende

| Tipo | Formatos |
| --- | --- |
| WiFi | `WIFI:T:WPA;S:red;P:clave;H:true;;` |
| Enlaces | `http`, `https`, `ftp`, `mailto`, `tel`, `sms`, `geo` y esquemas de apps |
| Contactos | vCard 2.1/3.0 y MECARD |
| Eventos | iCalendar (`BEGIN:VEVENT`) |
| Correo | `mailto:` y `MATMSG:` |
| Teléfono | `tel:` |
| SMS | `sms:` / `SMSTO:` |
| Ubicación | `geo:` y enlaces de mapas |
| 2FA | `otpauth://totp/...` y `otpauth://hotp/...` |
| Texto | Cualquier otra carga útil |

Desde la cámara se leen además Aztec, PDF417, Data Matrix y varios códigos de
barras 1D. Las fotos de la galería se procesan con `CIDetector`, que en iOS 9
solo detecta QR.

## WiFi directa en iOS 9

`NEHotspotConfiguration` llegó en iOS 11, así que IScan carga
`/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi` con
`dlopen` y usa la API que emplea el propio panel de Ajustes. El binario lleva
el entitlement `com.apple.wifi.manager-access` y `ldid` lo firma en el paquete.

El flujo es siempre el mismo:

1. Si el QR trae SSID y contraseña, IScan escanea redes y se asocia.
2. Comprueba por polling que el SSID actual es el esperado.
3. Si la asociación falla, no hay red o el framework no está disponible,
   copia la contraseña al portapapeles y abre **Ajustes › WiFi**.

Nada de esto impide usar la app en un dispositivo sin jailbreak: simplemente
se queda en el plan B.

## Requisitos

- iPad mini 1, iPad 2/3/4 o cualquier dispositivo **armv7** con **iOS 9.0–9.3**.
- Jailbreak y **AppSync Unified** para instalar el IPA.
- Para compilar: Theos, toolchain LLVM con soporte armv7 y el SDK de iOS 9.3
  (o dejar que GitHub Actions lo haga).

## Compilar

### En GitHub Actions (recomendado en Windows)

El repositorio incluye `.github/workflows/build-ipa.yml`. Al hacer push a
`main` o lanzar el workflow a mano:

1. Instala Theos, el toolchain de L1ghtmann y el SDK 9.3.
2. Parchea `liblaunch.tbd`, que falta en el SDK 9.3.
3. Genera iconos e imágenes de arranque con `tools/generar_recursos.py`.
4. Compila con `make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa`.
5. Verifica el binario y publica el `.ipa` como artefacto y como Release.

### En local (macOS o Linux)

```sh
export THEOS=$HOME/theos
git clone --recursive https://github.com/theos/theos.git "$THEOS"

cd app
make clean
make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
```

El IPA queda en `app/packages/`. Para comprobar el resultado sin un Mac:

```sh
python3 tools/comprobar_fuentes.py
python3 tools/verificar_ipa.py app/packages/*.ipa
```

`verificar_ipa.py` lee la cabecera Mach-O y confirma que el binario es armv7 de
32 bits, que el mínimo es iOS 9, que el bundle es `com.loftur.iscan` y que los
iconos y las imágenes de arranque viajan dentro del `.app`.

## Instalar en el iPad

1. Copia el `.ipa` al iPad (Filza, AirDrop, `ifuse`, scp…).
2. Ábrelo con Filza y elige **Instalar**; o usa `ipainstaller`.
3. Si el icono no aparece, respeta el primer arranque de SpringBoard o
   reinicia el dispositivo.

El binario va firmado con `ldid`, no con una cuenta de desarrollador. Sin
AppSync Unified, iOS rechazará la instalación.

## Estructura

```
app/
  main.m, SCAppDelegate.*          arranque y ventana
  SCScannerViewController.*        cámara, ventana de escaneo, galería
  SCResultViewController.*         ficha del código y acciones
  SCHistoryViewController.*        historial de lecturas
  SCQRParser.*                     intérprete de todos los formatos
  SCQRResult.*                     modelo y serialización
  SCRecordStore.*                  historial JSON en Documents
  SCWiFiJoiner.*                   puente con MobileWiFi
  SCImageScanner.*                 QR en fotos (CIDetector)
  SCTheme.*, SCGlyph.*             paleta, tipografía e iconos vectoriales
  Resources/                       Info.plist, iconos y launch images
tools/
  generar_recursos.py              iconos y launch images sin dependencias
  comprobar_fuentes.py             coherencia de fuentes y metadatos
  verificar_ipa.py                 Mach-O armv7 + estructura del IPA
```

El historial se guarda en `Documents/historial-iscan.json` y solo contiene el
tipo, el texto original y la fecha; al cargarlo se vuelve a interpretar. Se
conservan las últimas 150 lecturas y no sale del dispositivo.

## Avisos

- La conexión WiFi usa una API privada de Apple. No hay App Store ni soporte
  oficial; funciona en iOS 9 con jailbreak y puede cambiar entre versiones.
- La app pide cámara, fotos, contactos y calendario. Los permisos se declaran
  en `Info.plist` con textos en español.
- `NSAllowsArbitraryLoads` está activo para poder abrir paneles locales de
  routers y redes de invitados.

## Licencia

MIT. Consulta [LICENSE](LICENSE).
