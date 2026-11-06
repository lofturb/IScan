# IScan 1.0.0

Primera versión de **IScan**, un lector de códigos QR para iOS 9 en iPad mini 1
(armv7). Lee cualquier contenido y, cuando el código es de tipo WiFi, intenta
conectarse directamente a la red.

## Qué incluye

- Lectura con la cámara de QR, Aztec, PDF417, Data Matrix y códigos de barras
  1D (Code 128, Code 39, EAN-13, EAN-8, UPC-E, ITF-14…).
- Lectura de QR desde una foto de la galería.
- Interpretación de WiFi, enlaces, vCard/MECARD, eventos iCalendar, correo,
  teléfono, SMS, ubicaciones, `otpauth` y texto libre.
- Conexión directa a la WiFi del QR con la API privada de iOS 9. Si falla,
  IScan copia la contraseña y abre Ajustes para pegarla.
- Guardado de contactos y eventos con las hojas del sistema.
- Historial de las últimas 150 lecturas, con opción de borrarlo.
- Interfaz oscura en español, sin storyboards ni XIB.

## Instalación

1. Descarga el `.ipa` adjunto a este Release.
2. En el iPad con jailbreak, asegúrate de tener **AppSync Unified** instalado.
3. Abre el `.ipa` con Filza (o instálalo con `ifuse`/AltDeploy) y reinicia la
   app si el icono no aparece al momento.

El binario está compilado para **armv7** y **iOS 9.0 o posterior**, y firmado
con `ldid` y los entitlements de la app (WiFi privada, sin sandbox). No es una
firma de Apple: en un dispositivo sin jailbreak no se instalará.

## Nota sobre la WiFi

`NEHotspotConfiguration` no existe en iOS 9; IScan usa `MobileWiFi.framework`
cargado con `dlopen`. Es la misma API que emplea Ajustes. En algunos modelos o
versiones de iOS el framework puede rechazar la asociación: en ese caso la app
siempre ofrece el plan B (copiar contraseña y abrir Ajustes › WiFi).

## Código

Repositorio: <https://github.com/lofturb/IScan>

El IPA se genera automáticamente con GitHub Actions (Theos + toolchain LLVM de
L1ghtmann + SDK 9.3). Consulta el README para compilarlo en local.
