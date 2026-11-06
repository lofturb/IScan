#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Paleta y piezas de interfaz compartidas. Tema oscuro: la app es un visor
// sobre la camara y el contraste alto ayuda en la pantalla no retina del
// iPad mini 1.
@interface SCTheme : NSObject

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;

+ (UIColor *)background;
+ (UIColor *)surface;
+ (UIColor *)surfaceAlt;
+ (UIColor *)stroke;
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)textTertiary;
+ (UIColor *)accent;
+ (UIColor *)accentSoft;
+ (UIColor *)success;
+ (UIColor *)successSoft;
+ (UIColor *)warning;
+ (UIColor *)danger;

+ (UIFont *)titleFont;
+ (UIFont *)headlineFont;
+ (UIFont *)bodyFont;
+ (UIFont *)subheadFont;
+ (UIFont *)captionFont;
+ (UIFont *)tinyFont;
+ (UIFont *)monoFont:(CGFloat)size;

// Tarjeta con esquinas redondeadas y borde sutil.
+ (UIView *)cardView;
+ (UIView *)tileWithColor:(UIColor *)color size:(CGFloat)size radius:(CGFloat)radius;

// Boton plano, sin UIButtonConfiguration (no existe en iOS 9).
+ (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                   foreground:(UIColor *)foreground
                         icon:(UIImage *)icon;

// Aviso breve que aparece y se va solo.
+ (void)toast:(NSString *)message inView:(UIView *)view;

// Etiqueta multilinea ya configurada.
+ (UILabel *)labelWithText:(NSString *)text
                      font:(UIFont *)font
                     color:(UIColor *)color;

// Aplica el aspecto oscuro a barras de navegacion.
+ (void)applyAppearance;

@end
