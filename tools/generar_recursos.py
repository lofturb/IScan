# -*- coding: utf-8 -*-
"""
Genera los iconos e imagenes de arranque de IScan.

Sin dependencias: los PNG se escriben a mano con zlib + struct, asi que
funciona en Windows 7 con Python 3.8 sin Pillow.

Produce:
  app/Resources/Icon-*.png, LaunchImage-*.png, iTunesArtwork
  app/recursos-generados.txt

Uso (desde la raiz del proyecto):
    python tools/generar_recursos.py
"""

import io
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------------------
# Paleta
# ---------------------------------------------------------------------------

FONDO_ICONO = (0x2F, 0x6B, 0xFF, 255)   # azul de marca
BLANCO = (0xF7, 0xFA, 0xFF, 255)
ACENTO = (0x9B, 0xC4, 0xFF, 255)        # azul claro para un par de modulos
NEGRO = (0x0B, 0x0D, 0x10, 255)         # fondo de la app
TINTA = (0x0E, 0x12, 0x18, 255)         # hueco de los patrones del QR


def raiz_proyecto():
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


RAIZ = raiz_proyecto()
DESTINO = os.path.join(RAIZ, "app", "Resources")


# ---------------------------------------------------------------------------
# Rasterizado con supersampling
# ---------------------------------------------------------------------------

def escribir_png(ruta, ancho, alto, pixeles):
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def lienzo(ancho, alto, color):
    return bytearray(bytes(color) * (ancho * alto))


def muestras(lado):
    if lado <= 48:
        return 4
    if lado <= 220:
        return 3
    return 2


def rellenar(pixeles, ancho, alto, forma, color, alfa=1.0):
    """Pinta la region de `forma` (test + caja) con bordes suaves."""
    test, caja = forma
    sup = muestras(max(ancho, alto))
    n = float(sup * sup)
    x0 = max(0, int(caja[0]) - 1)
    y0 = max(0, int(caja[1]) - 1)
    x1 = min(ancho, int(caja[2]) + 1)
    y1 = min(alto, int(caja[3]) + 1)
    r, g, b, _ = color

    for y in range(y0, y1):
        for x in range(x0, x1):
            dentro = 0
            for sy in range(sup):
                py = y + (sy + 0.5) / sup
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    if test(px, py):
                        dentro += 1
            if not dentro:
                continue
            cob = (dentro / n) * alfa
            base = (y * ancho + x) * 4
            if cob >= 0.999:
                pixeles[base] = r
                pixeles[base + 1] = g
                pixeles[base + 2] = b
            else:
                resto = 1.0 - cob
                pixeles[base] = int(pixeles[base] * resto + r * cob + 0.5)
                pixeles[base + 1] = int(pixeles[base + 1] * resto + g * cob + 0.5)
                pixeles[base + 2] = int(pixeles[base + 2] * resto + b * cob + 0.5)


def rect(x0, y0, x1, y1):
    def test(x, y):
        return x0 <= x <= x1 and y0 <= y <= y1
    return test, (x0, y0, x1, y1)


def rrect(x0, y0, x1, y1, radio):
    def test(x, y):
        if x < x0 or x > x1 or y < y0 or y > y1:
            return False
        cx = min(max(x, x0 + radio), x1 - radio)
        cy = min(max(y, y0 + radio), y1 - radio)
        dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= radio * radio
    return test, (x0, y0, x1, y1)


# ---------------------------------------------------------------------------
# Motivo: un QR estilizado (tres patrones de posicion + modulos)
# ---------------------------------------------------------------------------

def motivo(pixeles, ancho, alto, x0, y0, lado, tinta, color, acento):
    """Dibuja el motivo QR dentro del cuadrado (x0, y0, lado)."""
    def pos(fx, fy, tam):
        return x0 + fx * lado, y0 + fy * lado, tam * lado

    # Tres patrones de posicion (cuadrado blanco, hueco y punto central).
    for fx, fy in ((0.00, 0.00), (0.62, 0.00), (0.00, 0.62)):
        px, py, t = pos(fx, fy, 0.30)
        px2, py2 = px + t, py + t
        rellenar(pixeles, ancho, alto, rect(px, py, px2, py2), color)
        i = t * 0.18
        rellenar(pixeles, ancho, alto, rect(px + i, py + i, px2 - i, py2 - i),
                 tinta)
        d = t * 0.34
        m = (t - d) / 2.0
        rellenar(pixeles, ancho, alto, rect(px + m, py + m, px + m + d, py + m + d),
                 color)

    # Modulos sueltos, con una diagonal en el color claro.
    modulos = [
        (0.62, 0.62, color), (0.76, 0.62, color), (0.90, 0.62, acento),
        (0.62, 0.76, color), (0.76, 0.76, acento), (0.90, 0.76, color),
        (0.62, 0.90, acento), (0.76, 0.90, color), (0.90, 0.90, color),
    ]
    for fx, fy, tono in modulos:
        px, py, t = pos(fx, fy, 0.10)
        rellenar(pixeles, ancho, alto, rect(px, py, px + t, py + t),
                 tono)


def icono(lado):
    # Sangrado completo: iOS aplica su propia mascara redondeada al icono.
    pixeles = lienzo(lado, lado, FONDO_ICONO)
    margen = 0.19 * lado
    motivo(pixeles, lado, lado, margen, margen, lado - margen * 2.0,
           FONDO_ICONO, BLANCO, ACENTO)
    return pixeles


def arranque(ancho, alto):
    pixeles = lienzo(ancho, alto, NEGRO)
    lado = int(min(ancho, alto) * 0.26)
    x0 = (ancho - lado) // 2
    y0 = int(alto * 0.36)
    radio = 0.2237 * lado
    rellenar(pixeles, ancho, alto, rrect(x0, y0, x0 + lado, y0 + lado, radio),
             FONDO_ICONO)
    margen = 0.19 * lado
    motivo(pixeles, ancho, alto, x0 + margen, y0 + margen, lado - margen * 2.0,
           FONDO_ICONO, BLANCO, ACENTO)
    return pixeles


ICONOS = [
    ("Icon-29.png", 29),
    ("Icon-29@2x.png", 58),
    ("Icon-40.png", 40),
    ("Icon-40@2x.png", 80),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("Icon-83.5@2x.png", 167),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage-700.png", 320, 480),
    ("LaunchImage-700@2x.png", 640, 960),
    ("LaunchImage-700-568h@2x.png", 640, 1136),
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
    ("LaunchImage.png", 320, 480),
    ("LaunchImage@2x.png", 640, 960),
    ("LaunchImage-568h@2x.png", 640, 1136),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    print("  Raiz:    %s" % RAIZ)
    print("  Destino: %s" % DESTINO)
    print("")

    for nombre, lado in ICONOS:
        escribir_png(os.path.join(DESTINO, nombre), lado, lado, icono(lado))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))
        print("    %s" % nombre)

    for nombre, ancho, alto in ARRANQUES:
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto,
                     arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))
        print("    %s" % nombre)

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("")
    print("Generados %d archivos en app/Resources" % len(hechos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
