#import <Foundation/Foundation.h>
#import "SCQRResult.h"

// Interpreta el contenido de un QR y lo convierte en una ficha con campos y
// una accion principal. Cubre los formatos habituales: WiFi, vCard, MECARD,
// iCalendar, MATMSG, otpauth, mailto, tel, sms, geo, URLs y texto libre.
@interface SCQRParser : NSObject

+ (SCQRResult *)parse:(NSString *)text;

// Expuesto para poder comprobarlo aislado (formato WIFI:T:..;S:..;P:..;;).
+ (NSDictionary *)parseWiFiPayload:(NSString *)payload;

@end
