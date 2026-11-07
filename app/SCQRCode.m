#import "SCQRCode.h"
#import <CoreImage/CoreImage.h>

// El QR se dibuja siempre a 2x: en pantalla se reduce y en los archivos
// exportados queda con bordes nitidos.
static const CGFloat SCQRCodeScale = 2.0;

@implementation SCQRCode

+ (NSCache *)cache {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 60;
    });
    return cache;
}

+ (UIImage *)imageForString:(NSString *)string size:(CGFloat)size {
    if (string.length == 0 || size <= 0.0) { return nil; }

    NSString *clave = [NSString stringWithFormat:@"%.0f|%lu|%@",
                       size, (unsigned long)string.length, string];
    NSCache *cache = [self cache];
    UIImage *guardada = [cache objectForKey:clave];
    if (guardada) { return guardada; }

    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!filter) { return nil; }
    [filter setDefaults];

    // ISO-8859-1 es lo que entiende el generador; si el texto trae caracteres
    // fuera de ese juego se cae a UTF-8.
    NSData *datos = [string dataUsingEncoding:NSISOLatin1StringEncoding];
    if (!datos) { datos = [string dataUsingEncoding:NSUTF8StringEncoding]; }
    if (!datos) { return nil; }
    [filter setValue:datos forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];

    CIImage *salida = filter.outputImage;
    if (!salida) { return nil; }
    CGRect extension = salida.extent;
    if (extension.size.width <= 0.0 || extension.size.height <= 0.0) { return nil; }

    CGFloat margen = size * 0.08;
    CGFloat lado = size - margen * 2.0;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, SCQRCodeScale);
    CGContextRef contexto = UIGraphicsGetCurrentContext();
    if (!contexto) {
        UIGraphicsEndImageContext();
        return nil;
    }

    CGContextSetFillColorWithColor(contexto, [UIColor whiteColor].CGColor);
    CGContextFillRect(contexto, CGRectMake(0, 0, size, size));
    CGContextSetInterpolationQuality(contexto, kCGInterpolationNone);
    CGContextSetShouldAntialias(contexto, NO);

    CIContext *ciContexto = [CIContext contextWithOptions:nil];
    CGImageRef imagen = [ciContexto createCGImage:salida fromRect:extension];
    if (imagen) {
        CGContextDrawImage(contexto, CGRectMake(margen, margen, lado, lado), imagen);
        CGImageRelease(imagen);
    }

    UIImage *resultado = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (resultado) { [cache setObject:resultado forKey:clave]; }
    return resultado;
}

@end
