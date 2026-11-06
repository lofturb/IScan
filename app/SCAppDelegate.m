#import "SCAppDelegate.h"

#import "SCTheme.h"
#import "SCScannerViewController.h"

@implementation SCAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [SCTheme applyAppearance];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [SCTheme background];

    // La camara ocupa toda la pantalla; la barra de navegacion solo hace falta
    // en las fichas y en el historial, que se presentan como modales.
    SCScannerViewController *scanner = [[SCScannerViewController alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:scanner];
    nav.navigationBarHidden = YES;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
