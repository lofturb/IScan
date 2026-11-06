#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SCGlyphKind) {
    SCGlyphKindPhoto,
    SCGlyphKindHistory,
    SCGlyphKindCopy,
    SCGlyphKindClose,
    SCGlyphKindShare,
    SCGlyphKindTrash,
    SCGlyphKindWiFi,
    SCGlyphKindLink,
    SCGlyphKindPerson,
    SCGlyphKindCalendar,
    SCGlyphKindMail,
    SCGlyphKindPhone,
    SCGlyphKindMessage,
    SCGlyphKindPin,
    SCGlyphKindKey,
    SCGlyphKindText,
    SCGlyphKindLock,
    SCGlyphKindEye,
    SCGlyphKindEyeOff,
    SCGlyphKindShield,
    SCGlyphKindCheck,
    SCGlyphKindScan,
    SCGlyphKindCamera
};

// Iconos vectoriales dibujados en codigo (no hay SF Symbols en iOS 9 y asi
// evitamos depender de PNGs para cada tamano).
@interface SCGlyph : NSObject

+ (UIImage *)image:(SCGlyphKind)kind size:(CGFloat)size color:(UIColor *)color;
+ (UIImage *)image:(SCGlyphKind)kind
              size:(CGFloat)size
             color:(UIColor *)color
            weight:(CGFloat)weight;

@end
