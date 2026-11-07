#import "SCAppDelegate.h"

#import "SCTheme.h"
#import "SCHomeViewController.h"

@implementation SCAppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [SCTheme applyAppearance];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [SCTheme background];

    // La pantalla de inicio es la raiz. El escaner se abre encima a pantalla
    // completa; las fichas y el historial se presentan como modales.
    SCHomeViewController *inicio = [[SCHomeViewController alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:inicio];
    nav.navigationBarHidden = YES;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
