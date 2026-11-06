#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCWiFiJoinStatus) {
    SCWiFiJoinStatusUnsupported = 0,
    SCWiFiJoinStatusSuccess,
    SCWiFiJoinStatusNotFound,
    SCWiFiJoinStatusFailed,
    SCWiFiJoinStatusTimeout
};

// Conexion directa a una red WiFi a partir de los datos del QR.
//
// En iOS 9 no existe NEHotspotConfiguration (llego en iOS 11), asi que se usa
// MobileWiFi.framework, la API privada que emplea el propio panel de Ajustes.
// Se carga con dlopen: si el framework o los simbolos no estan, la app sigue
// funcionando y la interfaz cae al modo "copiar y abrir Ajustes".
@interface SCWiFiJoiner : NSObject

+ (BOOL)isSupported;

// El bloque se llama siempre en el hilo principal y una sola vez.
+ (void)joinSSID:(NSString *)ssid
        password:(NSString *)password
          hidden:(BOOL)hidden
      completion:(void (^)(SCWiFiJoinStatus status, NSString *detail))completion;

+ (NSString *)currentSSID;
+ (void)openWiFiSettings;
+ (void)cancel;

@end
