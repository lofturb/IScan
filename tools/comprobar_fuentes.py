# -*- coding: utf-8 -*-
"""
Comprueba que las fuentes, los metadatos y los recursos de IScan son coherentes.

Uso:
    python tools/comprobar_fuentes.py

No compila nada. Evita los despistes habituales en un proyecto de Theos:
olvidar un .m en el Makefile, cambiar el bundle ID en un sitio y no en otro,
dejar un #import a una cabecera que ya no existe o perder un icono. Se ejecuta
en local y en el CI antes de `make package`.
"""

import os
import plistlib
import re
import sys

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIZ = _BASE
if "--raiz" in sys.argv:
    _i = sys.argv.index("--raiz")
    if _i + 1 < len(sys.argv):
        RAIZ = os.path.abspath(sys.argv[_i + 1])
elif not os.path.isdir(os.path.join(_BASE, "app")):
    if os.path.isdir(os.path.join(os.getcwd(), "app")):
        RAIZ = os.getcwd()

APP = os.path.join(RAIZ, "app")
RECURSOS = os.path.join(APP, "Resources")
MAKEFILE = os.path.join(APP, "Makefile")
CONTROL = os.path.join(APP, "control")
INFO = os.path.join(RECURSOS, "Info.plist")
ENTITLEMENTS = os.path.join(APP, "entitlements.plist")

ICONOS = (
    "Icon-29.png", "Icon-29@2x.png", "Icon-40.png", "Icon-40@2x.png",
    "Icon-60.png", "Icon-60@2x.png", "Icon-60@3x.png",
    "Icon-76.png", "Icon-76@2x.png", "Icon-83.5@2x.png",
    "iTunesArtwork",
)

FRAMEWORKS = (
    "UIKit", "Foundation", "AVFoundation", "CoreImage", "ImageIO",
    "CoreMedia", "CoreVideo", "SystemConfiguration", "AddressBook",
    "AddressBookUI", "EventKit",
)

PROBLEMAS = 0


def error(texto):
    global PROBLEMAS
    PROBLEMAS += 1
    print("  ERROR: %s" % texto)


def aviso(texto):
    print("  AVISO: %s" % texto)


def leer(ruta):
    with open(ruta, encoding="utf-8") as f:
        return f.read()


def fuentes_declaradas(makefile, app):
    patron = re.compile(r"^\s*%s_FILES\s*=\s*((?:.*\\\n)*.*)$" % re.escape(app),
                        re.M)
    m = patron.search(makefile)
    if not m:
        raise RuntimeError("no se encontro %s_FILES en app/Makefile" % app)
    texto = m.group(1).replace("\\\n", " ")
    return [x for x in texto.split() if x.endswith(".m")]


def main():
    print("=== Fuentes ===")
    if not os.path.isfile(MAKEFILE):
        error("no existe app/Makefile")
        return 1

    try:
        makefile = leer(MAKEFILE)
    except Exception as e:  # noqa: BLE001
        error("no se pudo leer app/Makefile: %s" % e)
        return 1

    m = re.search(r"^\s*APPLICATION_NAME\s*=\s*(\S+)\s*$", makefile, re.M)
    if not m:
        error("no se encontro APPLICATION_NAME en app/Makefile")
        return 1
    app = m.group(1)

    if not re.search(r"^\s*ARCHS\s*=\s*armv7\s*$", makefile, re.M):
        error("ARCHS debe ser exactamente armv7")
    m = re.search(r"^\s*TARGET\s*=\s*(\S+)\s*$", makefile, re.M)
    if not m:
        error("falta TARGET en app/Makefile")
    else:
        partes = m.group(1).split(":")
        if len(partes) != 4:
            error("TARGET no tiene el formato iphone:clang:SDK:MINIMO")
        elif partes[0] != "iphone" or partes[1] != "clang":
            error("TARGET no compila para iphone con clang")
        elif not partes[2].startswith("9."):
            aviso("SDK de compilacion %s (lo probado es 9.3)" % partes[2])
        elif not partes[3].startswith("9.0"):
            error("la version minima debe ser 9.0, no %s" % partes[3])

    if "-fobjc-arc" not in makefile:
        error("IScan_CFLAGS no activa ARC (-fobjc-arc)")

    try:
        declaradas = fuentes_declaradas(makefile, app)
    except RuntimeError as e:
        error(str(e))
        return 1

    print("  Aplicacion: %s" % app)
    print("  Fuentes en el Makefile: %d" % len(declaradas))

    en_disco = sorted(n for n in os.listdir(APP)
                      if n.endswith(".m") and os.path.isfile(os.path.join(APP, n)))
    for nombre in en_disco:
        if nombre not in declaradas:
            error("%s esta en app/ pero no en %s_FILES" % (nombre, app))
    for nombre in declaradas:
        ruta = os.path.join(APP, nombre)
        if not os.path.isfile(ruta):
            error("%s esta en %s_FILES pero no existe" % (nombre, app))
        elif os.path.getsize(ruta) == 0:
            error("%s esta vacio" % nombre)

    for nombre in en_disco:
        ruta = os.path.join(APP, nombre)
        if os.path.getsize(ruta) == 0:
            continue
        try:
            texto = leer(ruta)
        except UnicodeDecodeError:
            error("%s no esta guardado en UTF-8" % nombre)
            continue
        if "#import" not in texto:
            error("%s no importa ninguna cabecera" % nombre)

        # Cabeceras locales: #import "SCFoo.h" debe existir junto al fuente.
        for cabecera in re.findall(r'#import\s+"([^"]+)"', texto):
            if not os.path.isfile(os.path.join(APP, cabecera)):
                error("%s importa %s, que no existe" % (nombre, cabecera))

    for nombre in sorted(n for n in os.listdir(APP)
                         if n.endswith(".h") and os.path.isfile(os.path.join(APP, n))):
        try:
            leer(os.path.join(APP, nombre))
        except UnicodeDecodeError:
            error("%s no esta guardado en UTF-8" % nombre)

    frameworks = re.search(r"^\s*%s_FRAMEWORKS\s*=\s*((?:.*\\\n)*.*)$"
                           % re.escape(app), makefile, re.M)
    if not frameworks:
        error("no se encontro %s_FRAMEWORKS" % app)
    else:
        lista = frameworks.group(1).replace("\\\n", " ").split()
        for framework in FRAMEWORKS:
            if framework not in lista:
                error("falta %s en %s_FRAMEWORKS" % (framework, app))

    print("")
    print("=== Metadatos ===")
    try:
        with open(INFO, "rb") as f:
            info = plistlib.load(f)
    except Exception as e:  # noqa: BLE001
        error("no se pudo leer app/Resources/Info.plist: %s" % e)
        return 1

    try:
        control = leer(CONTROL)
    except Exception as e:  # noqa: BLE001
        error("no se pudo leer app/control: %s" % e)
        return 1

    paquete = re.search(r"^Package:\s*(\S+)", control, re.M)
    version = re.search(r"^Version:\s*(\S+)", control, re.M)
    paquete = paquete.group(1) if paquete else None
    version = version.group(1) if version else None

    bundle = info.get("CFBundleIdentifier")
    ejecutable = info.get("CFBundleExecutable")
    version_info = info.get("CFBundleShortVersionString")
    minimo = info.get("MinimumOSVersion")

    print("  Bundle ID (Info.plist): %s" % bundle)
    print("  Paquete (control):      %s" % paquete)
    print("  Ejecutable:             %s" % ejecutable)
    print("  Version (Info.plist):   %s" % version_info)
    print("  Version (control):      %s" % version)
    print("  iOS minimo:             %s" % minimo)

    if bundle != paquete:
        error("CFBundleIdentifier y Package no coinciden")
    if bundle != "com.loftur.iscan":
        error("el bundle ID esperado es com.loftur.iscan")
    if ejecutable != app:
        error("CFBundleExecutable (%s) no coincide con APPLICATION_NAME (%s)"
              % (ejecutable, app))
    if version_info != version:
        error("CFBundleShortVersionString y Version no coinciden")
    if not minimo:
        error("falta MinimumOSVersion en Info.plist")
    elif str(minimo) not in ("9.0", "9.0.0"):
        aviso("MinimumOSVersion es %s (el objetivo es 9.0)" % minimo)

    familias = info.get("UIDeviceFamily") or []
    if 2 not in familias:
        error("UIDeviceFamily no incluye iPad (2)")
    capacidades = info.get("UIRequiredDeviceCapabilities") or []
    if "armv7" not in capacidades:
        error("UIRequiredDeviceCapabilities no exige armv7")

    if "UILaunchImages" not in info:
        aviso("falta UILaunchImages: iOS 9 puede mostrar barras negras")
    else:
        for entrada in info["UILaunchImages"]:
            nombre = entrada.get("UILaunchImageName")
            if not nombre:
                error("UILaunchImages tiene una entrada sin nombre")
                continue
            if not any(n.startswith(nombre) and n.endswith(".png")
                       for n in os.listdir(RECURSOS)):
                error("UILaunchImages usa %s, pero no hay PNG con ese nombre"
                      % nombre)

    for clave in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
                  "NSContactsUsageDescription", "NSCalendarsUsageDescription"):
        valor = info.get(clave)
        if not isinstance(valor, str) or not valor.strip():
            error("falta %s en Info.plist" % clave)

    for clave in ("UIStatusBarStyle", "UIRequiresPersistentWiFi"):
        if clave not in info:
            aviso("falta %s en Info.plist" % clave)

    for icono in ICONOS:
        ruta = os.path.join(RECURSOS, icono)
        if not os.path.isfile(ruta):
            error("falta el icono %s" % icono)
        elif os.path.getsize(ruta) == 0:
            error("el icono %s esta vacio" % icono)

    for clave in ("CFBundleIcons", "CFBundleIcons~ipad"):
        bloque = info.get(clave) or {}
        primario = bloque.get("CFBundlePrimaryIcon") or {}
        for nombre in primario.get("CFBundleIconFiles") or []:
            candidatos = [n for n in os.listdir(RECURSOS)
                          if n.startswith(nombre) and n.endswith(".png")]
            if not candidatos:
                error("%s referencia %s, que no existe" % (clave, nombre))

    print("")
    print("=== Entitlements ===")
    if os.path.isfile(ENTITLEMENTS):
        try:
            with open(ENTITLEMENTS, "rb") as f:
                ent = plistlib.load(f)
        except Exception as e:  # noqa: BLE001
            error("no se pudo leer app/entitlements.plist: %s" % e)
            ent = {}
        ident = ent.get("application-identifier")
        grupos = ent.get("keychain-access-groups") or []
        print("  application-identifier: %s" % ident)
        if ident != bundle:
            error("application-identifier no coincide con CFBundleIdentifier")
        if grupos and bundle not in grupos:
            aviso("el bundle ID no esta en keychain-access-groups")
        if not ent.get("com.apple.private.security.no-sandbox"):
            aviso("falta com.apple.private.security.no-sandbox")
        if not ent.get("platform-application"):
            aviso("falta platform-application")
        if not ent.get("com.apple.wifi.manager-access"):
            error("falta com.apple.wifi.manager-access (WiFi directa)")
        if not ent.get("get-task-allow"):
            aviso("falta get-task-allow (util para depurar)")
    else:
        error("no existe app/entitlements.plist")

    print("")
    print("=== Recursos compartidos ===")
    for nombre in ("recursos-generados.txt",):
        ruta = os.path.join(APP, nombre)
        if not os.path.isfile(ruta):
            aviso("no existe app/%s" % nombre)

    print("")
    if PROBLEMAS:
        print("=== Resultado: %d problema(s) ===" % PROBLEMAS)
        return 1
    print("=== Resultado: correcto ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
