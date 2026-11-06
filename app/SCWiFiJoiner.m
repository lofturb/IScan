#import "SCWiFiJoiner.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <SystemConfiguration/CaptiveNetwork.h>

// Tipos opacos de MobileWiFi.
typedef struct __WiFiManagerClient *WiFiManagerClientRef;
typedef struct __WiFiDeviceClient *WiFiDeviceClientRef;
typedef struct __WiFiNetwork *WiFiNetworkRef;

typedef WiFiManagerClientRef (*SCWiFiManagerCreateFn)(CFAllocatorRef, int);
typedef CFArrayRef (*SCWiFiManagerCopyDevicesFn)(WiFiManagerClientRef);
typedef CFArrayRef (*SCWiFiManagerCopyNetworksFn)(WiFiManagerClientRef);
typedef void (*SCWiFiManagerScheduleFn)(WiFiManagerClientRef, CFRunLoopRef, CFStringRef);
typedef void (*SCWiFiManagerUnscheduleFn)(WiFiManagerClientRef, CFRunLoopRef, CFStringRef);
typedef int (*SCWiFiScanAsyncFn)(WiFiDeviceClientRef, CFDictionaryRef, void *, const void *);
typedef int (*SCWiFiAssociateAsyncFn)(WiFiDeviceClientRef, WiFiNetworkRef, void *, CFDictionaryRef);
typedef void (*SCWiFiNetworkSetPasswordFn)(WiFiNetworkRef, CFStringRef);
typedef CFStringRef (*SCWiFiNetworkGetSSIDFn)(WiFiNetworkRef);
typedef WiFiNetworkRef (*SCWiFiDeviceCopyCurrentNetworkFn)(WiFiDeviceClientRef);

static void *SCWiFiHandle = NULL;
static BOOL SCWiFiLoaded = NO;
static SCWiFiManagerCreateFn SCWiFiManagerCreate = NULL;
static SCWiFiManagerCopyDevicesFn SCWiFiCopyDevices = NULL;
static SCWiFiManagerCopyNetworksFn SCWiFiCopyNetworks = NULL;
static SCWiFiManagerScheduleFn SCWiFiSchedule = NULL;
static SCWiFiManagerUnscheduleFn SCWiFiUnschedule = NULL;
static SCWiFiScanAsyncFn SCWiFiScanAsync = NULL;
static SCWiFiAssociateAsyncFn SCWiFiAssociateAsync = NULL;
static SCWiFiNetworkSetPasswordFn SCWiFiSetPassword = NULL;
static SCWiFiNetworkGetSSIDFn SCWiFiGetSSID = NULL;
static SCWiFiDeviceCopyCurrentNetworkFn SCWiFiCopyCurrentNetwork = NULL;

static void SCWiFiScanCallback(WiFiDeviceClientRef device, CFArrayRef results,
                               int error, const void *object);

@interface SCWiFiJoiner ()

@property (nonatomic, copy) void (^completion)(SCWiFiJoinStatus, NSString *);
@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) CFTypeRef manager;
@property (nonatomic, assign) CFTypeRef devices;
@property (nonatomic, assign) CFTypeRef device;
@property (nonatomic, assign) CFTypeRef network;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSInteger attempts;
@property (nonatomic, assign) NSInteger scans;

- (void)begin;
- (void)scan;
- (void)associate;
- (void)poll:(NSTimer *)timer;
- (void)scanTimedOut:(NSTimer *)timer;
- (void)handleScanResults:(CFArrayRef)results;
- (void)finish:(SCWiFiJoinStatus)status detail:(NSString *)detail;
- (void)stop;

@end

@implementation SCWiFiJoiner

+ (instancetype)shared {
    static SCWiFiJoiner *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[SCWiFiJoiner alloc] init];
    });
    return shared;
}

+ (BOOL)ensureLoaded {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCWiFiHandle = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi",
                              RTLD_LAZY);
        if (!SCWiFiHandle) {
            NSLog(@"[IScan] MobileWiFi no disponible: %s", dlerror());
            return;
        }
        SCWiFiManagerCreate = (SCWiFiManagerCreateFn)dlsym(SCWiFiHandle, "WiFiManagerClientCreate");
        SCWiFiCopyDevices = (SCWiFiManagerCopyDevicesFn)dlsym(SCWiFiHandle, "WiFiManagerClientCopyDevices");
        SCWiFiCopyNetworks = (SCWiFiManagerCopyNetworksFn)dlsym(SCWiFiHandle, "WiFiManagerClientCopyNetworks");
        SCWiFiSchedule = (SCWiFiManagerScheduleFn)dlsym(SCWiFiHandle, "WiFiManagerClientScheduleWithRunLoop");
        SCWiFiUnschedule = (SCWiFiManagerUnscheduleFn)dlsym(SCWiFiHandle, "WiFiManagerClientUnscheduleFromRunLoop");
        SCWiFiScanAsync = (SCWiFiScanAsyncFn)dlsym(SCWiFiHandle, "WiFiDeviceClientScanAsync");
        SCWiFiAssociateAsync = (SCWiFiAssociateAsyncFn)dlsym(SCWiFiHandle, "WiFiDeviceClientAssociateAsync");
        SCWiFiSetPassword = (SCWiFiNetworkSetPasswordFn)dlsym(SCWiFiHandle, "WiFiNetworkSetPassword");
        SCWiFiGetSSID = (SCWiFiNetworkGetSSIDFn)dlsym(SCWiFiHandle, "WiFiNetworkGetSSID");
        SCWiFiCopyCurrentNetwork = (SCWiFiDeviceCopyCurrentNetworkFn)dlsym(SCWiFiHandle, "WiFiDeviceClientCopyCurrentNetwork");

        SCWiFiLoaded = (SCWiFiManagerCreate && SCWiFiCopyDevices && SCWiFiCopyNetworks &&
                        SCWiFiSchedule && SCWiFiUnschedule && SCWiFiScanAsync &&
                        SCWiFiAssociateAsync && SCWiFiSetPassword && SCWiFiGetSSID);
        NSLog(@"[IScan] MobileWiFi cargado: %@", SCWiFiLoaded ? @"si" : @"no");
    });
    return SCWiFiLoaded;
}

+ (BOOL)isSupported {
    return [self ensureLoaded];
}

+ (NSString *)ssidFromNetwork:(WiFiNetworkRef)network {
    if (!network || !SCWiFiGetSSID) { return nil; }
    CFStringRef name = SCWiFiGetSSID(network);
    if (!name) { return nil; }
    return (__bridge NSString *)name;
}

+ (NSString *)currentSSID {
    if ([self ensureLoaded] && SCWiFiCopyCurrentNetwork) {
        SCWiFiJoiner *joiner = [self shared];
        if (joiner.device) {
            WiFiNetworkRef network = SCWiFiCopyCurrentNetwork((WiFiDeviceClientRef)joiner.device);
            if (network) {
                NSString *name = [self ssidFromNetwork:network];
                CFRelease(network);
                if (name.length) { return name; }
            }
        }
    }

    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (!interfaces) { return nil; }
    NSString *found = nil;
    for (CFIndex i = 0; i < CFArrayGetCount(interfaces); i++) {
        CFStringRef interface = (CFStringRef)CFArrayGetValueAtIndex(interfaces, i);
        CFDictionaryRef info = CNCopyCurrentNetworkInfo(interface);
        if (!info) { continue; }
        NSString *name = [(__bridge NSDictionary *)info objectForKey:@"SSID"];
        if (name.length) { found = [name copy]; }
        CFRelease(info);
        if (found) { break; }
    }
    CFRelease(interfaces);
    return found;
}

+ (void)openWiFiSettings {
    NSArray *candidatos = @[ @"prefs:root=WIFI", @"prefs:root=Settings&path=Wi-Fi" ];
    for (NSString *texto in candidatos) {
        NSURL *url = [NSURL URLWithString:texto];
        if (!url) { continue; }
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
            return;
        }
    }
    NSURL *settings = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (settings) {
        [[UIApplication sharedApplication] openURL:settings];
    }
}

+ (void)joinSSID:(NSString *)ssid
        password:(NSString *)password
          hidden:(BOOL)hidden
      completion:(void (^)(SCWiFiJoinStatus, NSString *))completion {
    SCWiFiJoiner *joiner = [self shared];
    [joiner stop];

    joiner.ssid = ssid ?: @"";
    joiner.password = password ?: @"";
    joiner.hidden = hidden;
    joiner.completion = completion;
    joiner.finished = NO;
    joiner.attempts = 0;
    joiner.scans = 0;

    if (![self ensureLoaded] || joiner.ssid.length == 0) {
        [joiner finish:SCWiFiJoinStatusUnsupported
                detail:@"Este dispositivo no permite conectar solo con la API privada."];
        return;
    }

    [joiner begin];
}

+ (void)cancel {
    [[self shared] stop];
}

// ---------------------------------------------------------------------------

- (void)begin {
    self.manager = SCWiFiManagerCreate(kCFAllocatorDefault, 0);
    if (!self.manager) {
        [self finish:SCWiFiJoinStatusFailed detail:@"No se pudo abrir el gestor de WiFi."];
        return;
    }

    self.devices = SCWiFiCopyDevices((WiFiManagerClientRef)self.manager);
    if (!self.devices || CFArrayGetCount((CFArrayRef)self.devices) == 0) {
        [self finish:SCWiFiJoinStatusFailed detail:@"El iPad no tiene una interfaz WiFi activa."];
        return;
    }
    self.device = (CFTypeRef)CFArrayGetValueAtIndex((CFArrayRef)self.devices, 0);

    SCWiFiSchedule((WiFiManagerClientRef)self.manager, CFRunLoopGetMain(),
                   kCFRunLoopDefaultMode);

    // 1) Si la red ya es conocida, se asocia directamente.
    CFArrayRef conocidas = SCWiFiCopyNetworks((WiFiManagerClientRef)self.manager);
    WiFiNetworkRef red = [self findSSID:self.ssid inArray:conocidas];
    if (red) {
        self.network = (CFTypeRef)CFRetain(red);
        if (conocidas) { CFRelease(conocidas); }
        [self associate];
        return;
    }
    if (conocidas) { CFRelease(conocidas); }

    // 2) Si no, se escanea la zona (asi funciona con redes de invitados).
    [self scan];
}

- (WiFiNetworkRef)findSSID:(NSString *)ssid inArray:(CFArrayRef)array {
    if (!array) { return NULL; }
    CFIndex total = CFArrayGetCount(array);
    for (CFIndex i = 0; i < total; i++) {
        WiFiNetworkRef network = (WiFiNetworkRef)CFArrayGetValueAtIndex(array, i);
        NSString *name = [[self class] ssidFromNetwork:network];
        if (name.length && [name isEqualToString:ssid]) {
            return network;
        }
    }
    return NULL;
}

- (void)scan {
    if (!self.device) {
        [self finish:SCWiFiJoinStatusFailed detail:@"No hay interfaz WiFi."];
        return;
    }
    self.scans += 1;

    NSDictionary *options = @{ @"SCAN_TYPE": @(1), @"SCAN_MERGE": @(1) };
    int code = SCWiFiScanAsync((WiFiDeviceClientRef)self.device,
                               (__bridge CFDictionaryRef)options,
                               (void *)SCWiFiScanCallback,
                               (__bridge const void *)self);
    if (code != 0) {
        NSLog(@"[IScan] ScanAsync devolvio %d", code);
    }

    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:12.0
                                                  target:self
                                                selector:@selector(scanTimedOut:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)scanTimedOut:(NSTimer *)timer {
    if (self.finished) { return; }
    if (self.scans < 2) {
        [self scan];
        return;
    }
    [self finish:SCWiFiJoinStatusNotFound
          detail:@"No se encontrÃ³ la red. Comprueba que estÃ© al alcance."];
}

- (void)handleScanResults:(CFArrayRef)results {
    if (self.finished) { return; }
    if (!results) { return; }

    WiFiNetworkRef red = [self findSSID:self.ssid inArray:results];
    if (!red) {
        // Algunos escaneos devuelven solo redes nuevas: se reintenta una vez.
        if (self.scans < 2) { [self scan]; }
        return;
    }

    [self.timer invalidate];
    self.timer = nil;
    self.network = (CFTypeRef)CFRetain(red);
    [self associate];
}

- (void)associate {
    if (self.finished) { return; }

    if (self.password.length > 0 && SCWiFiSetPassword) {
        SCWiFiSetPassword((WiFiNetworkRef)self.network,
                          (__bridge CFStringRef)self.password);
    }

    int code = SCWiFiAssociateAsync((WiFiDeviceClientRef)self.device,
                                    (WiFiNetworkRef)self.network,
                                    NULL, NULL);
    if (code != 0) {
        NSLog(@"[IScan] AssociateAsync devolvio %d", code);
        [self finish:SCWiFiJoinStatusFailed
              detail:@"El iPad rechazÃ³ la conexiÃ³n. La contraseÃ±a puede ser incorrecta."];
        return;
    }

    self.attempts = 0;
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.7
                                                  target:self
                                                selector:@selector(poll:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)poll:(NSTimer *)timer {
    if (self.finished) { return; }
    self.attempts += 1;

    NSString *actual = [[self class] currentSSID];
    if (actual.length && [actual isEqualToString:self.ssid]) {
        [self finish:SCWiFiJoinStatusSuccess
              detail:[NSString stringWithFormat:@"Conectado a Â«%@Â».", self.ssid]];
        return;
    }

    if (self.attempts >= 28) {
        [self finish:SCWiFiJoinStatusTimeout
              detail:@"La red no confirmÃ³ la conexiÃ³n. Prueba desde Ajustes."];
    }
}

// ---------------------------------------------------------------------------

- (void)finish:(SCWiFiJoinStatus)status detail:(NSString *)detail {
    if (self.finished) { return; }
    self.finished = YES;

    void (^completion)(SCWiFiJoinStatus, NSString *) = self.completion;
    self.completion = nil;

    [self stop];

    if (!completion) { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(status, detail ?: @"");
    });
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;

    if (self.manager && SCWiFiUnschedule) {
        SCWiFiUnschedule((WiFiManagerClientRef)self.manager,
                         CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    }
    if (self.network) {
        CFRelease(self.network);
        self.network = NULL;
    }
    if (self.devices) {
        CFRelease(self.devices);
        self.devices = NULL;
    }
    if (self.manager) {
        CFRelease(self.manager);
        self.manager = NULL;
    }
    self.device = NULL;
    self.completion = nil;
}

@end

// El callback de escaneo es una funcion C: el contexto lleva el objeto.
static void SCWiFiScanCallback(WiFiDeviceClientRef device, CFArrayRef results,
                               int error, const void *object) {
    if (!object) { return; }
    SCWiFiJoiner *joiner = (__bridge SCWiFiJoiner *)object;
    if (error != 0) {
        NSLog(@"[IScan] Error de escaneo: %d", error);
        return;
    }
    [joiner handleScanResults:results];
}
