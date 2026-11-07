#import "SCGlyph.h"
#import <math.h>

// Todos los trazos se definen en una rejilla de 24x24 y luego se escalan, asi
// el mismo dibujo vale para 12 pt (pie de celda) y para 64 pt (cabecera).

static void SCRRect(CGContextRef ctx, CGFloat x, CGFloat y, CGFloat w, CGFloat h,
                    CGFloat radius) {
    CGPathRef path = CGPathCreateWithRoundedRect(CGRectMake(x, y, w, h),
                                                 radius, radius, NULL);
    CGContextAddPath(ctx, path);
    CGPathRelease(path);
}

static void SCEllipse(CGContextRef ctx, CGFloat cx, CGFloat cy, CGFloat r) {
    CGContextAddEllipseInRect(ctx, CGRectMake(cx - r, cy - r, r * 2.0, r * 2.0));
}

static void SCLine(CGContextRef ctx, CGFloat x1, CGFloat y1,
                   CGFloat x2, CGFloat y2) {
    CGContextMoveToPoint(ctx, x1, y1);
    CGContextAddLineToPoint(ctx, x2, y2);
}

static void SCPolyline(CGContextRef ctx, const CGFloat *puntos, NSUInteger n) {
    if (n < 2) { return; }
    CGContextMoveToPoint(ctx, puntos[0], puntos[1]);
    for (NSUInteger i = 1; i < n; i++) {
        CGContextAddLineToPoint(ctx, puntos[i * 2], puntos[i * 2 + 1]);
    }
}

@implementation SCGlyph

+ (UIImage *)image:(SCGlyphKind)kind size:(CGFloat)size color:(UIColor *)color {
    return [self image:kind size:size color:color weight:2.0];
}

+ (UIImage *)image:(SCGlyphKind)kind
              size:(CGFloat)size
             color:(UIColor *)color
            weight:(CGFloat)weight {
    if (size <= 0.0) { size = 24.0; }
    if (!color) { color = [UIColor whiteColor]; }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { return nil; }

    CGFloat escala = size / 24.0;
    CGContextScaleCTM(ctx, escala, escala);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, weight);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    switch (kind) {
        case SCGlyphKindPhoto: {
            SCRRect(ctx, 3.0, 5.0, 18.0, 14.0, 3.0);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 8.4, 10.2, 1.7);
            CGContextStrokePath(ctx);
            const CGFloat montana[] = { 3.6, 16.8, 9.2, 11.4, 13.0, 15.2, 16.2, 12.4, 20.4, 16.8 };
            SCPolyline(ctx, montana, 5);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindHistory: {
            SCEllipse(ctx, 12.0, 12.0, 8.4);
            CGContextStrokePath(ctx);
            const CGFloat agujas[] = { 12.0, 6.6, 12.0, 12.2, 15.8, 14.4 };
            SCPolyline(ctx, agujas, 3);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindCopy: {
            SCRRect(ctx, 8.6, 8.6, 11.2, 11.2, 2.6);
            CGContextStrokePath(ctx);
            const CGFloat marco[] = { 15.8, 8.6, 15.8, 5.6, 5.6, 5.6, 5.6, 15.8, 8.6, 15.8 };
            SCPolyline(ctx, marco, 5);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindClose: {
            SCLine(ctx, 6.0, 6.0, 18.0, 18.0);
            SCLine(ctx, 18.0, 6.0, 6.0, 18.0);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindShare: {
            const CGFloat caja[] = { 8.6, 6.2, 6.2, 6.2, 4.2, 8.2, 4.2, 20.2,
                                     19.8, 20.2, 19.8, 8.2, 17.8, 6.2, 15.4, 6.2 };
            SCPolyline(ctx, caja, 8);
            CGContextStrokePath(ctx);
            SCLine(ctx, 12.0, 15.6, 12.0, 2.9);
            CGContextStrokePath(ctx);
            const CGFloat flecha[] = { 8.8, 6.1, 12.0, 2.9, 15.2, 6.1 };
            SCPolyline(ctx, flecha, 3);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindTrash: {
            SCLine(ctx, 3.6, 6.6, 20.4, 6.6);
            const CGFloat cuerpo[] = { 5.9, 6.6, 5.9, 20.2, 18.1, 20.2, 18.1, 6.6 };
            SCPolyline(ctx, cuerpo, 4);
            const CGFloat tapa[] = { 9.0, 6.6, 9.0, 3.5, 15.0, 3.5, 15.0, 6.6 };
            SCPolyline(ctx, tapa, 4);
            CGContextStrokePath(ctx);
            SCLine(ctx, 10.1, 10.4, 10.1, 16.4);
            SCLine(ctx, 13.9, 10.4, 13.9, 16.4);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindWiFi: {
            CGContextAddArc(ctx, 12.0, 18.6, 3.4, -2.70, -0.44, 0);
            CGContextStrokePath(ctx);
            CGContextAddArc(ctx, 12.0, 18.6, 7.4, -2.70, -0.44, 0);
            CGContextStrokePath(ctx);
            CGContextAddArc(ctx, 12.0, 18.6, 11.4, -2.70, -0.44, 0);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 18.6, 1.35);
            CGContextFillPath(ctx);
            break;
        }
        case SCGlyphKindLink: {
            SCRRect(ctx, 2.4, 9.0, 11.0, 6.4, 3.2);
            CGContextStrokePath(ctx);
            SCRRect(ctx, 10.6, 9.0, 11.0, 6.4, 3.2);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindPerson: {
            SCEllipse(ctx, 12.0, 8.2, 3.5);
            CGContextStrokePath(ctx);
            CGContextAddArc(ctx, 12.0, 22.6, 8.6, M_PI, 2.0 * M_PI, 0);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindCalendar: {
            SCRRect(ctx, 3.6, 5.6, 16.8, 15.0, 3.0);
            CGContextStrokePath(ctx);
            SCLine(ctx, 3.6, 10.2, 20.4, 10.2);
            SCLine(ctx, 8.2, 3.2, 8.2, 7.2);
            SCLine(ctx, 15.8, 3.2, 15.8, 7.2);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 8.4, 14.6, 1.05);
            SCEllipse(ctx, 12.0, 14.6, 1.05);
            SCEllipse(ctx, 15.6, 14.6, 1.05);
            CGContextFillPath(ctx);
            break;
        }
        case SCGlyphKindMail: {
            SCRRect(ctx, 3.0, 6.0, 18.0, 12.6, 3.0);
            CGContextStrokePath(ctx);
            const CGFloat solapa[] = { 3.8, 7.4, 12.0, 13.0, 20.2, 7.4 };
            SCPolyline(ctx, solapa, 3);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindPhone: {
            SCRRect(ctx, 7.4, 2.6, 9.2, 18.8, 2.9);
            CGContextStrokePath(ctx);
            SCLine(ctx, 10.7, 18.2, 13.3, 18.2);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindMessage: {
            SCRRect(ctx, 3.0, 4.6, 18.0, 12.6, 4.0);
            CGContextStrokePath(ctx);
            const CGFloat cola[] = { 8.6, 17.0, 8.6, 21.2, 13.2, 17.0 };
            SCPolyline(ctx, cola, 3);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 8.3, 10.9, 1.0);
            SCEllipse(ctx, 12.0, 10.9, 1.0);
            SCEllipse(ctx, 15.7, 10.9, 1.0);
            CGContextFillPath(ctx);
            break;
        }
        case SCGlyphKindPin: {
            SCEllipse(ctx, 12.0, 9.2, 5.2);
            CGContextStrokePath(ctx);
            SCLine(ctx, 7.4, 12.6, 12.0, 21.4);
            SCLine(ctx, 16.6, 12.6, 12.0, 21.4);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 9.2, 2.0);
            CGContextFillPath(ctx);
            break;
        }
        case SCGlyphKindKey: {
            SCEllipse(ctx, 8.2, 9.6, 4.0);
            CGContextStrokePath(ctx);
            SCLine(ctx, 11.0, 12.4, 20.0, 21.4);
            SCLine(ctx, 16.5, 17.9, 18.5, 15.9);
            SCLine(ctx, 18.7, 20.1, 20.7, 18.1);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindText: {
            SCLine(ctx, 4.6, 7.0, 19.4, 7.0);
            SCLine(ctx, 4.6, 12.0, 16.0, 12.0);
            SCLine(ctx, 4.6, 17.0, 12.4, 17.0);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindLock: {
            SCRRect(ctx, 4.9, 10.6, 14.2, 9.2, 2.8);
            CGContextStrokePath(ctx);
            CGContextAddArc(ctx, 12.0, 10.6, 4.2, M_PI, 2.0 * M_PI, 0);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 15.2, 1.4);
            CGContextFillPath(ctx);
            break;
        }
        case SCGlyphKindEye: {
            CGContextMoveToPoint(ctx, 2.6, 12.0);
            CGContextAddCurveToPoint(ctx, 7.0, 5.6, 17.0, 5.6, 21.4, 12.0);
            CGContextAddCurveToPoint(ctx, 17.0, 18.4, 7.0, 18.4, 2.6, 12.0);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 12.0, 2.9);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindEyeOff: {
            CGContextMoveToPoint(ctx, 2.6, 12.0);
            CGContextAddCurveToPoint(ctx, 7.0, 5.6, 17.0, 5.6, 21.4, 12.0);
            CGContextAddCurveToPoint(ctx, 17.0, 18.4, 7.0, 18.4, 2.6, 12.0);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 12.0, 2.9);
            CGContextStrokePath(ctx);
            SCLine(ctx, 4.0, 4.0, 20.0, 20.0);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindShield: {
            CGContextMoveToPoint(ctx, 12.0, 2.8);
            CGContextAddLineToPoint(ctx, 20.2, 6.2);
            CGContextAddLineToPoint(ctx, 20.2, 12.0);
            CGContextAddCurveToPoint(ctx, 20.2, 17.4, 16.8, 20.4, 12.0, 21.6);
            CGContextAddCurveToPoint(ctx, 7.2, 20.4, 3.8, 17.4, 3.8, 12.0);
            CGContextAddLineToPoint(ctx, 3.8, 6.2);
            CGContextClosePath(ctx);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindCheck: {
            const CGFloat check[] = { 4.8, 12.6, 9.9, 17.6, 19.4, 6.8 };
            SCPolyline(ctx, check, 3);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindScan: {
            const CGFloat e1[] = { 3.0, 8.0, 3.0, 3.0, 8.0, 3.0 };
            const CGFloat e2[] = { 16.0, 3.0, 21.0, 3.0, 21.0, 8.0 };
            const CGFloat e3[] = { 21.0, 16.0, 21.0, 21.0, 16.0, 21.0 };
            const CGFloat e4[] = { 8.0, 21.0, 3.0, 21.0, 3.0, 16.0 };
            SCPolyline(ctx, e1, 3);
            SCPolyline(ctx, e2, 3);
            SCPolyline(ctx, e3, 3);
            SCPolyline(ctx, e4, 3);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindCamera: {
            SCRRect(ctx, 2.6, 7.0, 18.8, 13.4, 3.0);
            CGContextStrokePath(ctx);
            const CGFloat bump[] = { 8.4, 7.0, 9.8, 4.4, 14.2, 4.4, 15.6, 7.0 };
            SCPolyline(ctx, bump, 4);
            CGContextStrokePath(ctx);
            SCEllipse(ctx, 12.0, 13.5, 4.0);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindFolder: {
            SCRRect(ctx, 3.0, 6.6, 18.0, 12.4, 2.6);
            CGContextStrokePath(ctx);
            const CGFloat pestana[] = { 3.0, 9.4, 3.0, 6.6, 9.2, 6.6, 11.0, 9.4, 21.0, 9.4 };
            SCPolyline(ctx, pestana, 5);
            CGContextStrokePath(ctx);
            break;
        }
        case SCGlyphKindSave: {
            SCLine(ctx, 12.0, 3.2, 12.0, 15.0);
            CGContextStrokePath(ctx);
            const CGFloat flecha[] = { 7.4, 10.4, 12.0, 15.2, 16.6, 10.4 };
            SCPolyline(ctx, flecha, 3);
            CGContextStrokePath(ctx);
            const CGFloat bandeja[] = { 4.2, 16.8, 4.2, 20.6, 19.8, 20.6, 19.8, 16.8 };
            SCPolyline(ctx, bandeja, 4);
            CGContextStrokePath(ctx);
            break;
        }
        default:
            break;
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
