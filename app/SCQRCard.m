#import "SCQRCard.h"

#import "SCQRCode.h"
#import "SCTheme.h"

// Proporciones de la tarjeta de exportacion (pensadas sobre 620 pt de ancho).
static const CGFloat SCCardWidth = 620.0;

@implementation SCQRCard

+ (UIImage *)imageForResult:(SCQRResult *)result {
    return [self imageForResult:result width:SCCardWidth];
}

+ (UIImage *)imageForResult:(SCQRResult *)result width:(CGFloat)width {
    if (!result || width < 240.0) { return nil; }

    CGFloat pad = roundf(width * 0.071);
    CGFloat util = width - pad * 2.0;
    CGFloat qrLado = MIN(util, roundf(width * 0.613));
    CGFloat qrCaja = qrLado + 24.0;

    UIFont *tipoFont = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    UIFont *tituloFont = [UIFont systemFontOfSize:27.0 weight:UIFontWeightSemibold];
    UIFont *etiquetaFont = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    UIFont *valorFont = [UIFont systemFontOfSize:16.0];
    UIFont *enlaceFont = [SCTheme monoFont:13.0];
    UIFont *pieFont = [UIFont systemFontOfSize:12.0];

    NSString *tipo = [[SCQRResult displayNameForKind:result.kind] uppercaseString];
    NSString *titulo = result.title.length ? result.title : @"Código QR";
    NSString *enlace = (result.kind == SCQRKindURL)
        ? (result.action.length ? result.action : result.raw) : nil;

    NSArray *campos = result.fields ?: @[];
    NSUInteger limite = campos.count < 8 ? campos.count : 8;

    // --- Primera pasada: medir -------------------------------------------
    CGFloat altoTitulo = ceil([titulo boundingRectWithSize:CGSizeMake(util, 300.0)
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{ NSFontAttributeName: tituloFont }
                                                   context:nil].size.height);
    altoTitulo = MIN(MAX(altoTitulo, 32.0), 96.0);

    CGFloat altoEnlace = 0.0;
    if (enlace.length) {
        altoEnlace = ceil([enlace boundingRectWithSize:CGSizeMake(util, 140.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:@{ NSFontAttributeName: enlaceFont }
                                               context:nil].size.height);
        altoEnlace = MIN(altoEnlace, 60.0);
    }

    NSMutableArray *altosEtiqueta = [NSMutableArray array];
    NSMutableArray *altosValor = [NSMutableArray array];
    for (NSUInteger i = 0; i < limite; i++) {
        SCQRField *campo = campos[i];
        CGFloat he = ceil([[campo.label uppercaseString]
            boundingRectWithSize:CGSizeMake(util, 40.0)
                         options:NSStringDrawingUsesLineFragmentOrigin
                      attributes:@{ NSFontAttributeName: etiquetaFont }
                         context:nil].size.height);
        CGFloat hv = ceil([campo.value boundingRectWithSize:CGSizeMake(util, 240.0)
                                                    options:NSStringDrawingUsesLineFragmentOrigin
                                                 attributes:@{ NSFontAttributeName: valorFont }
                                                    context:nil].size.height);
        // En un iPad mini de 512 MB no conviene dibujar notas de miles de
        // lineas: se recortan a unas pocas y el texto completo sigue en la ficha.
        he = MIN(he, 26.0);
        hv = MIN(hv, 78.0);
        [altosEtiqueta addObject:@(MAX(he, 13.0))];
        [altosValor addObject:@(MAX(hv, 20.0))];
    }

    CGFloat alto = pad;
    alto += 15.0 + 10.0;                 // tipo
    alto += altoTitulo + 24.0;           // titulo
    alto += qrCaja + 24.0;               // QR
    if (altoEnlace > 0.0) { alto += altoEnlace + 18.0; }
    for (NSUInteger i = 0; i < limite; i++) {
        alto += [altosEtiqueta[i] doubleValue] + 4.0;
        alto += [altosValor[i] doubleValue] + 14.0;
    }
    if (campos.count > limite) { alto += 20.0; }
    alto += 18.0 + 1.0 + 16.0;           // separador
    alto += 16.0 + pad;                  // pie y margen inferior

    // --- Segunda pasada: dibujar -----------------------------------------
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, alto), NO, 2.0);
    CGContextRef contexto = UIGraphicsGetCurrentContext();
    if (!contexto) {
        UIGraphicsEndImageContext();
        return nil;
    }

    CGContextSetFillColorWithColor(contexto, [SCTheme background].CGColor);
    CGContextFillRect(contexto, CGRectMake(0, 0, width, alto));

    CGFloat y = pad;

    [tipo drawInRect:CGRectMake(pad, y, util, 15.0)
      withAttributes:@{
          NSFontAttributeName: tipoFont,
          NSForegroundColorAttributeName: [SCTheme accent],
          NSKernAttributeName: @(1.2)
      }];
    y += 15.0 + 10.0;

    [titulo drawInRect:CGRectMake(pad, y, util, altoTitulo)
        withAttributes:@{
            NSFontAttributeName: tituloFont,
            NSForegroundColorAttributeName: [SCTheme textPrimary]
        }];
    y += altoTitulo + 24.0;

    CGRect cajaQR = CGRectMake(roundf((width - qrCaja) / 2.0), y, qrCaja, qrCaja);
    [[UIColor whiteColor] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:cajaQR cornerRadius:18.0] fill];

    UIImage *qr = [SCQRCode imageForString:result.raw size:qrLado];
    if (qr) {
        [qr drawInRect:CGRectInset(cajaQR, 12.0, 12.0)];
    }
    y += qrCaja + 24.0;

    if (enlace.length) {
        [enlace drawInRect:CGRectMake(pad, y, util, altoEnlace)
            withAttributes:@{
                NSFontAttributeName: enlaceFont,
                NSForegroundColorAttributeName: [SCTheme textSecondary]
            }];
        y += altoEnlace + 18.0;
    }

    for (NSUInteger i = 0; i < limite; i++) {
        SCQRField *campo = campos[i];
        CGFloat he = [altosEtiqueta[i] doubleValue];
        CGFloat hv = [altosValor[i] doubleValue];

        [[campo.label uppercaseString] drawInRect:CGRectMake(pad, y, util, he)
                                   withAttributes:@{
                                       NSFontAttributeName: etiquetaFont,
                                       NSForegroundColorAttributeName: [SCTheme textTertiary],
                                       NSKernAttributeName: @(0.8)
                                   }];
        y += he + 4.0;

        [campo.value drawInRect:CGRectMake(pad, y, util, hv)
                 withAttributes:@{
                     NSFontAttributeName: valorFont,
                     NSForegroundColorAttributeName: [SCTheme textPrimary]
                 }];
        y += hv + 14.0;
    }

    if (campos.count > limite) {
        NSString *mas = [NSString stringWithFormat:@"+%lu campos más",
                         (unsigned long)(campos.count - limite)];
        [mas drawInRect:CGRectMake(pad, y - 6.0, util, 18.0)
         withAttributes:@{
             NSFontAttributeName: [UIFont systemFontOfSize:12.0],
             NSForegroundColorAttributeName: [SCTheme textTertiary]
         }];
    }

    y += 18.0;
    CGContextSetFillColorWithColor(contexto, [SCTheme stroke].CGColor);
    CGContextFillRect(contexto, CGRectMake(pad, y, util, 1.0));
    y += 1.0 + 16.0;

    NSMutableParagraphStyle *centrado = [[NSMutableParagraphStyle alloc] init];
    centrado.alignment = NSTextAlignmentCenter;
    [@"Generado con IScan" drawInRect:CGRectMake(pad, y, util, 20.0)
                       withAttributes:@{
                           NSFontAttributeName: pieFont,
                           NSForegroundColorAttributeName: [SCTheme textTertiary],
                           NSParagraphStyleAttributeName: centrado
                       }];

    UIImage *tarjeta = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tarjeta;
}

@end
