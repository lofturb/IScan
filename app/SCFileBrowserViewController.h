#import <UIKit/UIKit.h>

// Navegador de archivos de imagen del propio iPad. En un dispositivo con
// jailbreak y sin sandbox puede entrar en Documentos, Descargas, DCIM e iCloud
// Drive; si una carpeta no existe simplemente no se muestra.
//
// Al elegir una imagen se lee su QR en segundo plano y se avisa con el texto
// encontrado (y el nombre del archivo).
@interface SCFileBrowserViewController : UIViewController

@property (nonatomic, copy) void (^onPickPayload)(NSString *payload, NSString *fileName);

@end
