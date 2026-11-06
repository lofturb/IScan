#import <UIKit/UIKit.h>
#import "SCQRResult.h"

// Historial de lecturas dentro de un UINavigationController. Tocar una fila
// devuelve el resultado para que el scanner lo presente como si se acabara de
// leer.
@interface SCHistoryViewController : UIViewController

@property (nonatomic, copy) void (^onSelectResult)(SCQRResult *result);

@end
