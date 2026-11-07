#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Lee un QR dentro de una imagen (por ejemplo una foto de la galeria).
// CoreImage es lo unico que hay en iOS 9: no detecta codigos de barras 1D,
// pero si cualquier QR.
@interface SCImageScanner : NSObject

+ (NSString *)payloadFromImage:(UIImage *)image;

// Igual que el anterior, pero lee el archivo con ImageIO y lo reduce antes de
// tenerlo entero en memoria: imprescindible con fotos grandes en un iPad mini.
+ (NSString *)payloadFromImageAtPath:(NSString *)path;

@end
