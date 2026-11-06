#import <UIKit/UIKit.h>
#import "SCQRResult.h"

// Ficha del codigo leido: campos, accion principal y acciones secundarias.
@interface SCResultViewController : UIViewController

- (instancetype)initWithResult:(SCQRResult *)result;

// Se llama al cerrar la ficha, para reanudar la camara.
@property (nonatomic, copy) void (^onClose)(void);

@end
