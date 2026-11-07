#import <UIKit/UIKit.h>
#import "SCQRResult.h"

// Compone una imagen lista para compartir o guardar: el QR del codigo junto a
// su informacion (tipo, titulo y campos). Siempre a 2x.
@interface SCQRCard : NSObject

+ (UIImage *)imageForResult:(SCQRResult *)result;
+ (UIImage *)imageForResult:(SCQRResult *)result width:(CGFloat)width;

@end
