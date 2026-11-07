#import "SCImageScanner.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

@implementation SCImageScanner

+ (CGImagePropertyOrientation)orientationForImage:(UIImage *)image {
    switch (image.imageOrientation) {
        case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
        case UIImageOrientationUp:
        default: return kCGImagePropertyOrientationUp;
    }
}

+ (UIImage *)scaledImage:(UIImage *)image maxSide:(CGFloat)maxSide {
    CGSize size = image.size;
    CGFloat lado = MAX(size.width, size.height);
    if (lado <= maxSide || lado <= 0.0) { return image; }

    CGFloat factor = maxSide / lado;
    CGSize nuevo = CGSizeMake(roundf(size.width * factor), roundf(size.height * factor));
    UIGraphicsBeginImageContextWithOptions(nuevo, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, nuevo.width, nuevo.height)];
    UIImage *resultado = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultado ?: image;
}

+ (NSString *)payloadFromImageAtPath:(NSString *)path {
    if (!path.length) { return nil; }

    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef fuente = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!fuente) { return nil; }

    NSDictionary *opciones = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(1600)
    };
    CGImageRef miniatura = CGImageSourceCreateThumbnailAtIndex(
        fuente, 0, (__bridge CFDictionaryRef)opciones);
    CFRelease(fuente);
    if (!miniatura) { return nil; }

    UIImage *imagen = [UIImage imageWithCGImage:miniatura];
    CGImageRelease(miniatura);
    return [self payloadFromImage:imagen];
}

+ (NSString *)payloadFromImage:(UIImage *)image {
    if (!image) { return nil; }

    // Una foto de 5 MP ocupa ~20 MB en memoria; el iPad mini tiene 512 MB.
    UIImage *reducida = [self scaledImage:image maxSide:1600.0];
    CGImageRef cgImage = reducida.CGImage;
    if (!cgImage) { return nil; }

    CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
    if (!ciImage) { return nil; }

    NSDictionary *options = @{
        CIDetectorAccuracy: CIDetectorAccuracyHigh,
        CIDetectorImageOrientation: @([self orientationForImage:image])
    };
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
                                              context:nil
                                              options:options];
    if (!detector) { return nil; }

    NSArray *features = [detector featuresInImage:ciImage options:options];
    for (CIFeature *feature in features) {
        if (![feature isKindOfClass:[CIQRCodeFeature class]]) { continue; }
        CIQRCodeFeature *qr = (CIQRCodeFeature *)feature;
        if (qr.messageString.length) {
            return qr.messageString;
        }
    }
    return nil;
}

@end
