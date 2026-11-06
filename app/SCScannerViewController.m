#import "SCScannerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#import "SCTheme.h"
#import "SCGlyph.h"
#import "SCQRParser.h"
#import "SCQRResult.h"
#import "SCRecordStore.h"
#import "SCImageScanner.h"
#import "SCResultViewController.h"
#import "SCHistoryViewController.h"

@interface SCScannerViewController () <AVCaptureMetadataOutputObjectsDelegate,
                                       UIImagePickerControllerDelegate,
                                       UINavigationControllerDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) CAShapeLayer *dimLayer;
@property (nonatomic, strong) CAShapeLayer *cornerLayer;
@property (nonatomic, strong) UIView *scanLine;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *hintSubLabel;

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) CAGradientLayer *topGradient;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) CAGradientLayer *bottomGradient;
@property (nonatomic, strong) UIButton *photoButton;
@property (nonatomic, strong) UIButton *historyButton;

@property (nonatomic, strong) UIView *permissionCard;
@property (nonatomic, strong) UILabel *permissionTitle;
@property (nonatomic, strong) UILabel *permissionDetail;
@property (nonatomic, strong) UIButton *permissionSettings;
@property (nonatomic, strong) UIButton *permissionPhoto;

@property (nonatomic, assign) BOOL configured;
@property (nonatomic, assign) BOOL handlingResult;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) CGRect scanRect;

@end

@implementation SCScannerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.sessionQueue = dispatch_queue_create("com.loftur.iscan.session",
                                              DISPATCH_QUEUE_SERIAL);

    [self buildInterface];
    [self buildPermissionCard];

    NSNotificationCenter *centro = [NSNotificationCenter defaultCenter];
    [centro addObserver:self
               selector:@selector(appDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [centro addObserver:self
               selector:@selector(appWillEnterForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];

    [self requestCameraAccess];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.session.isRunning) {
        [self.session stopRunning];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.started && !self.handlingResult) {
        [self startSession];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopSession];
}

// ---------------------------------------------------------------------------
// Interfaz
// ---------------------------------------------------------------------------

- (void)buildInterface {
    CGRect bounds = self.view.bounds;

    self.previewContainer = [[UIView alloc] initWithFrame:bounds];
    self.previewContainer.backgroundColor = [UIColor blackColor];
    self.previewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                             UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.previewContainer];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToFocus:)];
    [self.previewContainer addGestureRecognizer:tap];

    self.overlayView = [[UIView alloc] initWithFrame:bounds];
    self.overlayView.userInteractionEnabled = NO;
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.overlayView];

    self.dimLayer = [CAShapeLayer layer];
    self.dimLayer.fillColor = [UIColor colorWithWhite:0.0 alpha:0.55].CGColor;
    self.dimLayer.fillRule = kCAFillRuleEvenOdd;
    [self.overlayView.layer addSublayer:self.dimLayer];

    self.cornerLayer = [CAShapeLayer layer];
    self.cornerLayer.fillColor = [UIColor clearColor].CGColor;
    self.cornerLayer.strokeColor = [SCTheme accent].CGColor;
    self.cornerLayer.lineWidth = 3.5;
    self.cornerLayer.lineCap = kCALineCapRound;
    self.cornerLayer.lineJoin = kCALineJoinRound;
    [self.overlayView.layer addSublayer:self.cornerLayer];

    self.scanLine = [[UIView alloc] initWithFrame:CGRectZero];
    self.scanLine.backgroundColor = [[SCTheme accent] colorWithAlphaComponent:0.9];
    self.scanLine.layer.cornerRadius = 1.0;
    [self.overlayView addSubview:self.scanLine];

    self.hintLabel = [SCTheme labelWithText:@"Apunta al código QR"
                                       font:[SCTheme subheadFont]
                                      color:[SCTheme textPrimary]];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    [self.overlayView addSubview:self.hintLabel];

    self.hintSubLabel = [SCTheme labelWithText:@"WiFi, enlaces, contactos, eventos y más"
                                          font:[SCTheme tinyFont]
                                         color:[SCTheme textTertiary]];
    self.hintSubLabel.textAlignment = NSTextAlignmentCenter;
    [self.overlayView addSubview:self.hintSubLabel];

    // Barra superior con titulo.
    self.topBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.topGradient = [CAGradientLayer layer];
    self.topGradient.colors = @[ (id)[UIColor colorWithWhite:0.0 alpha:0.72].CGColor,
                                 (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor ];
    [self.topBar.layer addSublayer:self.topGradient];
    [self.view addSubview:self.topBar];

    UILabel *titulo = [SCTheme labelWithText:@"IScan"
                                        font:[SCTheme titleFont]
                                       color:[SCTheme textPrimary]];
    titulo.tag = 101;
    titulo.frame = CGRectMake(24.0, 30.0, 320.0, 30.0);
    [self.topBar addSubview:titulo];

    UILabel *subtitulo = [SCTheme labelWithText:@"Lector de códigos"
                                           font:[SCTheme captionFont]
                                          color:[SCTheme textSecondary]];
    subtitulo.tag = 102;
    subtitulo.frame = CGRectMake(24.0, 60.0, 320.0, 18.0);
    [self.topBar addSubview:subtitulo];

    // Barra inferior con acciones.
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.bottomGradient = [CAGradientLayer layer];
    self.bottomGradient.colors = @[ (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
                                    (id)[UIColor colorWithWhite:0.0 alpha:0.85].CGColor ];
    [self.bottomBar.layer addSublayer:self.bottomGradient];
    [self.view addSubview:self.bottomBar];

    self.photoButton = [SCTheme buttonWithTitle:@"Galería"
                                     background:[[SCTheme surface] colorWithAlphaComponent:0.94]
                                     foreground:[SCTheme textPrimary]
                                           icon:[SCGlyph image:SCGlyphKindPhoto
                                                           size:18.0
                                                          color:[SCTheme textPrimary]]];
    [self.photoButton addTarget:self
                         action:@selector(choosePhoto)
               forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.photoButton];

    self.historyButton = [SCTheme buttonWithTitle:@"Historial"
                                       background:[[SCTheme surface] colorWithAlphaComponent:0.94]
                                       foreground:[SCTheme textPrimary]
                                             icon:[SCGlyph image:SCGlyphKindHistory
                                                             size:18.0
                                                            color:[SCTheme textPrimary]]];
    [self.historyButton addTarget:self
                           action:@selector(showHistory)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.historyButton];
}

- (void)buildPermissionCard {
    UIView *card = [SCTheme cardView];
    card.hidden = YES;
    card.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                            UIViewAutoresizingFlexibleBottomMargin |
                            UIViewAutoresizingFlexibleLeftMargin |
                            UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:card];
    self.permissionCard = card;

    UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(24.0, 24.0, 28.0, 28.0)];
    icon.image = [SCGlyph image:SCGlyphKindCamera size:28.0 color:[SCTheme accent]];
    icon.tintColor = [SCTheme accent];
    [card addSubview:icon];

    self.permissionTitle = [SCTheme labelWithText:@"Sin acceso a la cámara"
                                            font:[SCTheme headlineFont]
                                           color:[SCTheme textPrimary]];
    self.permissionTitle.frame = CGRectMake(64.0, 22.0, 320.0, 24.0);
    [card addSubview:self.permissionTitle];

    self.permissionDetail = [SCTheme labelWithText:@""
                                             font:[SCTheme subheadFont]
                                            color:[SCTheme textSecondary]];
    self.permissionDetail.frame = CGRectMake(24.0, 64.0, 392.0, 90.0);
    [card addSubview:self.permissionDetail];

    self.permissionSettings = [SCTheme buttonWithTitle:@"Abrir Ajustes"
                                            background:[SCTheme accent]
                                            foreground:[UIColor whiteColor]
                                                  icon:nil];
    [self.permissionSettings addTarget:self
                                action:@selector(openSettings)
                      forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.permissionSettings];

    self.permissionPhoto = [SCTheme buttonWithTitle:@"Elegir una foto"
                                         background:[SCTheme surfaceAlt]
                                         foreground:[SCTheme textPrimary]
                                               icon:[SCGlyph image:SCGlyphKindPhoto
                                                               size:18.0
                                                              color:[SCTheme textPrimary]]];
    [self.permissionPhoto addTarget:self
                             action:@selector(choosePhoto)
                   forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.permissionPhoto];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect bounds = self.view.bounds;
    CGFloat ancho = bounds.size.width;
    CGFloat alto = bounds.size.height;

    self.previewContainer.frame = bounds;
    self.overlayView.frame = bounds;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.previewLayer.frame = bounds;
    [CATransaction commit];

    self.topBar.frame = CGRectMake(0, 0, ancho, 110.0);
    self.topGradient.frame = self.topBar.bounds;
    self.bottomBar.frame = CGRectMake(0, alto - 170.0, ancho, 170.0);
    self.bottomGradient.frame = self.bottomBar.bounds;

    CGFloat margen = 20.0;
    CGFloat botonAncho = MIN(190.0, (ancho - margen * 3.0) / 2.0);
    CGFloat botonAlto = 52.0;
    CGFloat total = botonAncho * 2.0 + 12.0;
    CGFloat x0 = roundf((ancho - total) / 2.0);
    self.photoButton.frame = CGRectMake(x0, alto - 34.0 - botonAlto, botonAncho, botonAlto);
    self.historyButton.frame = CGRectMake(x0 + botonAncho + 12.0,
                                          alto - 34.0 - botonAlto,
                                          botonAncho, botonAlto);

    // Ventana de escaneo: cuadrada y centrada, un poco por encima del centro.
    CGFloat menor = MIN(ancho, alto);
    CGFloat lado = MIN(roundf(menor * 0.56), 380.0);
    lado = MAX(lado, 240.0);
    CGFloat cx = roundf(ancho / 2.0);
    CGFloat cy = roundf(alto / 2.0 - 26.0);
    CGRect ventana = CGRectMake(cx - lado / 2.0, cy - lado / 2.0, lado, lado);

    if (!CGRectEqualToRect(ventana, self.scanRect)) {
        self.scanRect = ventana;
        [self updateScanGeometry];
    }

    CGFloat centroX = ancho / 2.0;
    self.hintLabel.frame = CGRectMake(centroX - 160.0,
                                      CGRectGetMaxY(ventana) + 22.0, 320.0, 20.0);
    self.hintSubLabel.frame = CGRectMake(centroX - 160.0,
                                         CGRectGetMaxY(ventana) + 44.0, 320.0, 18.0);

    [self layoutPermissionCard];
}

- (void)updateScanGeometry {
    CGRect ventana = self.scanRect;
    UIBezierPath *camino = [UIBezierPath bezierPathWithRect:self.overlayView.bounds];
    UIBezierPath *hueco = [UIBezierPath bezierPathWithRoundedRect:ventana
                                                     cornerRadius:26.0];
    [camino appendPath:hueco];
    self.dimLayer.path = camino.CGPath;
    self.dimLayer.frame = self.overlayView.bounds;

    CGFloat x = ventana.origin.x;
    CGFloat y = ventana.origin.y;
    CGFloat w = ventana.size.width;
    CGFloat h = ventana.size.height;
    CGFloat largo = 30.0;
    UIBezierPath *esquinas = [UIBezierPath bezierPath];
    [esquinas moveToPoint:CGPointMake(x, y + largo)];
    [esquinas addLineToPoint:CGPointMake(x, y)];
    [esquinas addLineToPoint:CGPointMake(x + largo, y)];
    [esquinas moveToPoint:CGPointMake(x + w - largo, y)];
    [esquinas addLineToPoint:CGPointMake(x + w, y)];
    [esquinas addLineToPoint:CGPointMake(x + w, y + largo)];
    [esquinas moveToPoint:CGPointMake(x + w, y + h - largo)];
    [esquinas addLineToPoint:CGPointMake(x + w, y + h)];
    [esquinas addLineToPoint:CGPointMake(x + w - largo, y + h)];
    [esquinas moveToPoint:CGPointMake(x + largo, y + h)];
    [esquinas addLineToPoint:CGPointMake(x, y + h)];
    [esquinas addLineToPoint:CGPointMake(x, y + h - largo)];
    self.cornerLayer.path = esquinas.CGPath;
    self.cornerLayer.frame = self.overlayView.bounds;

    self.scanLine.frame = CGRectMake(x + 14.0, y + 10.0, w - 28.0, 2.0);
    [self.scanLine.layer removeAnimationForKey:@"linea"];

    CABasicAnimation *movimiento =
        [CABasicAnimation animationWithKeyPath:@"position.y"];
    movimiento.fromValue = @(self.scanLine.layer.position.y);
    movimiento.toValue = @(CGRectGetMaxY(ventana) - 10.0);
    movimiento.duration = 2.3;
    movimiento.autoreverses = YES;
    movimiento.repeatCount = HUGE_VALF;
    movimiento.timingFunction = [CAMediaTimingFunction
                                 functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.scanLine.layer addAnimation:movimiento forKey:@"linea"];
}

- (void)layoutPermissionCard {
    if (!self.permissionCard || self.permissionCard.hidden) { return; }

    CGSize tamano = self.view.bounds.size;
    CGFloat ancho = MIN(440.0, tamano.width - 48.0);
    CGFloat alto = 286.0;
    self.permissionCard.frame = CGRectMake(roundf((tamano.width - ancho) / 2.0),
                                           roundf((tamano.height - alto) / 2.0),
                                           ancho, alto);

    self.permissionDetail.frame = CGRectMake(24.0, 64.0, ancho - 48.0, 92.0);
    self.permissionSettings.frame = CGRectMake(24.0, alto - 118.0, ancho - 48.0, 48.0);
    self.permissionPhoto.frame = CGRectMake(24.0, alto - 62.0, ancho - 48.0, 46.0);
}

// ---------------------------------------------------------------------------
// Permiso y sesion de camara
// ---------------------------------------------------------------------------

- (void)requestCameraAccess {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self showPermissionMessage:@"No hay cámara disponible"
                             detail:@"Este dispositivo no tiene cámara utilizable. Puedes leer "
                                    "códigos desde una foto guardada en la galería."];
        return;
    }

    AVAuthorizationStatus estado =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    if (estado == AVAuthorizationStatusAuthorized) {
        [self startCamera];
        return;
    }
    if (estado == AVAuthorizationStatusNotDetermined) {
        __weak typeof(self) weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                 completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    [weakSelf startCamera];
                } else {
                    [weakSelf showPermissionMessage:@"Sin acceso a la cámara"
                                             detail:@"IScan necesita la cámara para leer códigos. "
                                                    @"Puedes activarla en Ajustes › IScan, o leer "
                                                    @"un QR desde una foto."];
                }
            });
        }];
        return;
    }

    [self showPermissionMessage:@"Sin acceso a la cámara"
                         detail:@"IScan necesita la cámara para leer códigos. Puedes activarla "
                                @"en Ajustes › IScan, o leer un QR desde una foto."];
}

- (void)showPermissionMessage:(NSString *)titulo detail:(NSString *)detalle {
    self.permissionTitle.text = titulo;
    self.permissionDetail.text = detalle;
    self.permissionCard.hidden = NO;
    self.overlayView.hidden = YES;
    self.bottomBar.hidden = YES;
    [self layoutPermissionCard];
}

- (void)hidePermissionMessage {
    self.permissionCard.hidden = YES;
    self.overlayView.hidden = NO;
    self.bottomBar.hidden = NO;
}

- (void)startCamera {
    [self hidePermissionMessage];
    dispatch_async(self.sessionQueue, ^{
        if (!self.configured) {
            [self configureSession];
        }
        if (self.session && !self.session.isRunning) {
            [self.session startRunning];
        }
    });
    self.started = YES;
}

- (void)configureSession {
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;

    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showPermissionMessage:@"No hay cámara disponible"
                                 detail:@"No se encontró ninguna cámara en el dispositivo."];
        });
        return;
    }

    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                       error:&error];
    if (!input || error) {
        NSLog(@"[IScan] No se pudo abrir la camara: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showPermissionMessage:@"La cámara no responde"
                                 detail:@"No se pudo iniciar la cámara. Cierra otras apps que "
                                        @"la estén usando y vuelve a intentarlo."];
        });
        return;
    }

    [session beginConfiguration];
    if ([session canAddInput:input]) {
        [session addInput:input];
    }

    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    if ([session canAddOutput:output]) {
        [session addOutput:output];

        NSArray *deseados = @[
            AVMetadataObjectTypeQRCode,
            AVMetadataObjectTypeAztecCode,
            AVMetadataObjectTypePDF417Code,
            AVMetadataObjectTypeDataMatrixCode,
            AVMetadataObjectTypeCode128Code,
            AVMetadataObjectTypeCode39Code,
            AVMetadataObjectTypeCode39Mod43Code,
            AVMetadataObjectTypeCode93Code,
            AVMetadataObjectTypeEAN13Code,
            AVMetadataObjectTypeEAN8Code,
            AVMetadataObjectTypeUPCECode,
            AVMetadataObjectTypeITF14Code,
            AVMetadataObjectTypeInterleaved2of5Code
        ];
        NSSet *disponibles = [NSSet setWithArray:output.availableMetadataObjectTypes];
        NSMutableArray *tipos = [NSMutableArray array];
        for (NSString *tipo in deseados) {
            if ([disponibles containsObject:tipo]) { [tipos addObject:tipo]; }
        }
        if (tipos.count > 0) {
            output.metadataObjectTypes = tipos;
            [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        } else {
            NSLog(@"[IScan] Este dispositivo no ofrece tipos de metadatos");
        }
    }
    [session commitConfiguration];

    self.session = session;
    self.configured = YES;

    AVCaptureVideoPreviewLayer *preview =
        [AVCaptureVideoPreviewLayer layerWithSession:session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    dispatch_async(dispatch_get_main_queue(), ^{
        preview.frame = self.previewContainer.bounds;
        [self.previewContainer.layer insertSublayer:preview atIndex:0];
        self.previewLayer = preview;
    });
}

- (void)startSession {
    if (!self.session) { return; }
    dispatch_async(self.sessionQueue, ^{
        if (!self.session.isRunning) {
            [self.session startRunning];
        }
    });
}

- (void)stopSession {
    if (!self.session) { return; }
    dispatch_async(self.sessionQueue, ^{
        if (self.session.isRunning) {
            [self.session stopRunning];
        }
    });
}

- (void)appDidEnterBackground:(NSNotification *)note {
    [self stopSession];
}

- (void)appWillEnterForeground:(NSNotification *)note {
    if (!self.handlingResult && !self.presentedViewController) {
        [self startSession];
    }
}

// ---------------------------------------------------------------------------
// Escaneo
// ---------------------------------------------------------------------------

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection {
    if (self.handlingResult) { return; }

    NSString *payload = nil;
    for (AVMetadataObject *objeto in metadataObjects) {
        if (![objeto isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            continue;
        }
        AVMetadataMachineReadableCodeObject *codigo =
            (AVMetadataMachineReadableCodeObject *)objeto;
        if (codigo.stringValue.length) {
            payload = codigo.stringValue;
            break;
        }
    }
    if (!payload.length) { return; }

    [self handlePayload:payload];
}

- (void)handlePayload:(NSString *)payload {
    if (self.handlingResult) { return; }
    self.handlingResult = YES;

    [self stopSession];
    [self flashSuccess];

    SCQRResult *result = [SCQRParser parse:payload];
    [[SCRecordStore sharedStore] add:result];

    [self presentResult:result];
}

- (void)presentResult:(SCQRResult *)result {
    SCResultViewController *detalle =
        [[SCResultViewController alloc] initWithResult:result];

    __weak typeof(self) weakSelf = self;
    detalle.onClose = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        strongSelf.handlingResult = NO;
        [strongSelf startSession];
    };

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:detalle];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)flashSuccess {
    self.cornerLayer.strokeColor = [SCTheme success].CGColor;

    CABasicAnimation *pulso = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulso.fromValue = @(1.0);
    pulso.toValue = @(0.35);
    pulso.duration = 0.16;
    pulso.autoreverses = YES;
    pulso.repeatCount = 2;
    [self.cornerLayer addAnimation:pulso forKey:@"pulso"];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.cornerLayer.strokeColor = [SCTheme accent].CGColor;
        }
    });
}

// ---------------------------------------------------------------------------
// Galeria e historial
// ---------------------------------------------------------------------------

- (void)choosePhoto {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIAlertController *alerta =
            [UIAlertController alertControllerWithTitle:@"Galería no disponible"
                                                message:@"No se puede abrir la galería en este dispositivo."
                                         preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
                                                   style:UIAlertActionStyleCancel
                                                 handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
        return;
    }

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[ @"public.image" ];
    picker.delegate = self;

    if ([picker respondsToSelector:@selector(popoverPresentationController)]) {
        UIPopoverPresentationController *popover = picker.popoverPresentationController;
        if (self.permissionCard.hidden) {
            popover.sourceView = self.photoButton;
            popover.sourceRect = self.photoButton.bounds;
        } else {
            popover.sourceView = self.permissionPhoto;
            popover.sourceRect = self.permissionPhoto.bounds;
        }
    }
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *imagen = info[UIImagePickerControllerOriginalImage];

    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        if (!imagen) { return; }

        NSString *payload = [SCImageScanner payloadFromImage:imagen];
        if (payload.length) {
            [strongSelf handlePayload:payload];
        } else {
            [strongSelf showNoCodeAlert];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)showNoCodeAlert {
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Sin código QR"
                         message:@"No se encontró ningún QR legible en esa imagen."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)showHistory {
    SCHistoryViewController *historial = [[SCHistoryViewController alloc] init];

    __weak typeof(self) weakSelf = self;
    historial.onSelectResult = ^(SCQRResult *result) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf dismissViewControllerAnimated:YES completion:^{
            [strongSelf presentResult:result];
        }];
    };

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:historial];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)openSettings {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

// ---------------------------------------------------------------------------
// Enfoque al tocar
// ---------------------------------------------------------------------------

- (void)tapToFocus:(UITapGestureRecognizer *)gesture {
    if (!self.previewLayer || !self.session) { return; }

    CGPoint punto = [gesture locationInView:self.previewContainer];
    AVCaptureDevice *device = nil;
    for (AVCaptureDeviceInput *input in self.session.inputs) {
        if ([input.device hasMediaType:AVMediaTypeVideo]) {
            device = input.device;
            break;
        }
    }
    if (!device) { return; }

    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if (device.isFocusPointOfInterestSupported &&
            [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            device.focusPointOfInterest =
                [self.previewLayer captureDevicePointOfInterestForPoint:punto];
            device.focusMode = AVCaptureFocusModeAutoFocus;
        }
        if (device.isExposurePointOfInterestSupported &&
            [device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
            device.exposurePointOfInterest =
                [self.previewLayer captureDevicePointOfInterestForPoint:punto];
            device.exposureMode = AVCaptureExposureModeAutoExpose;
        }
        [device unlockForConfiguration];
    }

    UIView *anillo = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 74.0, 74.0)];
    anillo.center = punto;
    anillo.backgroundColor = [UIColor clearColor];
    anillo.layer.borderColor = [[SCTheme accent] colorWithAlphaComponent:0.9].CGColor;
    anillo.layer.borderWidth = 1.5;
    anillo.layer.cornerRadius = 37.0;
    anillo.alpha = 0.0;
    [self.previewContainer addSubview:anillo];

    [UIView animateWithDuration:0.16 animations:^{
        anillo.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.45
                              delay:0.35
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            anillo.alpha = 0.0;
            anillo.transform = CGAffineTransformMakeScale(0.82, 0.82);
        } completion:^(BOOL done) {
            [anillo removeFromSuperview];
        }];
    }];
}

@end
