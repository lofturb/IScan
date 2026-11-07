#import <UIKit/UIKit.h>

// Genera un codigo QR con CoreImage (CIQRCodeGenerator, disponible desde
// iOS 7) y lo cachea para no repetir el dibujo al desplazar el historial.
@interface SCQRCode : NSObject

// Devuelve el QR de `string` en un cuadrado de `size` puntos, con fondo blanco
// y margen de silencio. La imagen se dibuja a 2x para que quede nitida.
+ (UIImage *)imageForString:(NSString *)string size:(CGFloat)size;

@end
