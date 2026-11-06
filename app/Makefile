# ---------------------------------------------------------------------------
#  IScan -- lector de codigos QR para iOS 9 / armv7 (iPad mini 1, iPad 2...).
#
#  Lee cualquier QR: WiFi, URLs, contactos vCard, eventos, correo, telefono,
#  SMS, ubicaciones y texto. Con intento de conexion directa a la WiFi del QR.
#
#  Compilar:  make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IScan

# Todos los .m del proyecto. Si anades un archivo, anadelo aqui o no enlaza.
IScan_FILES = \
	main.m \
	SCAppDelegate.m \
	SCTheme.m \
	SCGlyph.m \
	SCQRResult.m \
	SCQRParser.m \
	SCRecordStore.m \
	SCWiFiJoiner.m \
	SCImageScanner.m \
	SCScannerViewController.m \
	SCResultViewController.m \
	SCHistoryViewController.m

# AVFoundation: camara y deteccion nativa de codigos.
# CoreImage e ImageIO: lectura de QR en fotos de la galeria.
# SystemConfiguration: comprobar la red WiFi actual.
# AddressBook* y EventKit: guardar contactos y eventos.
IScan_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore CoreImage \
	ImageIO CoreMedia CoreVideo AVFoundation SystemConfiguration \
	AddressBook AddressBookUI EventKit

# -Werror convierte cualquier aviso en error: silenciamos solo lo justo.
IScan_CFLAGS = -fobjc-arc \
	-Wno-deprecated-declarations \
	-Wno-unused-parameter \
	-Wno-unused-variable \
	-Wno-unused-function \
	-Wno-objc-method-access

# Los iconos y las imagenes de arranque viajan dentro del .app.
IScan_RESOURCE_DIRS = Resources

IScan_LDFLAGS = -Wl,-dead_strip

# Permisos de jailbreak: WiFi (API privada de MobileWiFi) y carpetas propias.
IScan_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
