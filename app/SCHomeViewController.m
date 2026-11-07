#import "SCHomeViewController.h"

#import "SCTheme.h"
#import "SCGlyph.h"
#import "SCQRResult.h"
#import "SCQRCode.h"
#import "SCQRParser.h"
#import "SCRecordStore.h"
#import "SCScannerViewController.h"
#import "SCHistoryViewController.h"
#import "SCFileBrowserViewController.h"
#import "SCResultViewController.h"

// ---------------------------------------------------------------------------
// Tarjeta de accion
// ---------------------------------------------------------------------------

@interface SCHomeCard : UIControl

@property (nonatomic, strong) UIView *iconTile;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *chevronView;

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                         icon:(SCGlyphKind)icon
                      primary:(BOOL)primary;

@end

@implementation SCHomeCard

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                         icon:(SCGlyphKind)icon
                      primary:(BOOL)primary {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = primary ? [SCTheme accent] : [SCTheme surface];
        self.layer.cornerRadius = 18.0;
        self.layer.borderWidth = primary ? 0.0 : 1.0;
        self.layer.borderColor = [SCTheme stroke].CGColor;
        self.layer.masksToBounds = YES;

        UIColor *iconoTinte = primary ? [UIColor whiteColor] : [SCTheme accent];
        _iconTile = [SCTheme tileWithColor:(primary
                                            ? [UIColor colorWithWhite:1.0 alpha:0.18]
                                            : [SCTheme accentSoft])
                                      size:46.0
                                    radius:13.0];
        [self addSubview:_iconTile];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(11.0, 11.0, 24.0, 24.0)];
        _iconView.image = [SCGlyph image:icon size:24.0 color:iconoTinte];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [_iconTile addSubview:_iconView];

        _titleLabel = [SCTheme labelWithText:title
                                       font:[UIFont systemFontOfSize:18.0
                                                             weight:UIFontWeightSemibold]
                                      color:(primary ? [UIColor whiteColor]
                                                     : [SCTheme textPrimary])];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _subtitleLabel = [SCTheme labelWithText:subtitle
                                          font:[UIFont systemFontOfSize:13.0]
                                         color:(primary
                                                ? [UIColor colorWithWhite:1.0 alpha:0.78]
                                                : [SCTheme textSecondary])];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_subtitleLabel];

        _chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _chevronView.image = [SCGlyph image:SCGlyphKindChevron
                                      size:14.0
                                     color:(primary
                                            ? [UIColor colorWithWhite:1.0 alpha:0.80]
                                            : [SCTheme textTertiary])];
        _chevronView.contentMode = UIViewContentModeCenter;
        [self addSubview:_chevronView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = self.bounds.size.width;
    CGFloat alto = self.bounds.size.height;

    self.iconTile.frame = CGRectMake(18.0, roundf((alto - 46.0) / 2.0), 46.0, 46.0);

    CGFloat textoX = CGRectGetMaxX(self.iconTile.frame) + 14.0;
    CGFloat disponible = ancho - textoX - 18.0 - 18.0 - 6.0;
    if (disponible < 30.0) { disponible = 30.0; }

    self.titleLabel.frame = CGRectMake(textoX, roundf(alto / 2.0 - 23.0),
                                       disponible, 23.0);
    self.subtitleLabel.frame = CGRectMake(textoX, roundf(alto / 2.0 + 1.0),
                                          disponible, 18.0);
    self.chevronView.frame = CGRectMake(ancho - 18.0 - 14.0,
                                        roundf((alto - 16.0) / 2.0), 14.0, 16.0);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.alpha = highlighted ? 0.82 : 1.0;
    } completion:nil];
}

@end

// ---------------------------------------------------------------------------
// Fila de lectura reciente
// ---------------------------------------------------------------------------

static NSString *SCHomeFecha(NSDate *fecha) {
    if (!fecha) { return @""; }

    NSDateFormatter *formato = [[NSDateFormatter alloc] init];
    formato.locale = [NSLocale localeWithLocaleIdentifier:@"es_ES"];

    NSCalendar *calendario = [NSCalendar currentCalendar];
    if ([calendario isDateInToday:fecha]) {
        formato.dateFormat = @"'Hoy', HH:mm";
    } else if ([calendario isDateInYesterday:fecha]) {
        formato.dateFormat = @"'Ayer', HH:mm";
    } else if ([calendario isDate:fecha
                     equalToDate:[NSDate date]
               toUnitGranularity:NSCalendarUnitYear]) {
        formato.dateFormat = @"d MMM, HH:mm";
    } else {
        formato.dateFormat = @"d MMM yyyy";
    }
    return [formato stringFromDate:fecha];
}

static NSString *SCHomeLinea(NSString *texto) {
    if (!texto.length) { return @""; }
    NSArray *partes = [texto componentsSeparatedByCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]];
    NSMutableArray *limpias = [NSMutableArray array];
    for (NSString *parte in partes) {
        NSString *t = [parte stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
        if (t.length) { [limpias addObject:t]; }
    }
    return [limpias componentsJoinedByString:@" "];
}

@interface SCHomeRecentRow : UIControl

@property (nonatomic, strong) UIImageView *qrView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *chevronView;

- (void)configureWithResult:(SCQRResult *)result;

@end

@implementation SCHomeRecentRow

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [SCTheme surface];
        self.layer.cornerRadius = 14.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [SCTheme stroke].CGColor;
        self.layer.masksToBounds = YES;

        _qrView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _qrView.backgroundColor = [UIColor whiteColor];
        _qrView.contentMode = UIViewContentModeScaleAspectFit;
        _qrView.layer.cornerRadius = 6.0;
        _qrView.layer.masksToBounds = YES;
        [self addSubview:_qrView];

        _titleLabel = [SCTheme labelWithText:@""
                                       font:[SCTheme bodyFont]
                                      color:[SCTheme textPrimary]];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];

        _subtitleLabel = [SCTheme labelWithText:@""
                                          font:[SCTheme captionFont]
                                         color:[SCTheme textSecondary]];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_subtitleLabel];

        _chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _chevronView.image = [SCGlyph image:SCGlyphKindChevron
                                      size:14.0
                                     color:[SCTheme textTertiary]];
        _chevronView.contentMode = UIViewContentModeCenter;
        [self addSubview:_chevronView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = self.bounds.size.width;
    CGFloat alto = self.bounds.size.height;

    CGFloat qrLado = 42.0;
    self.qrView.frame = CGRectMake(14.0, roundf((alto - qrLado) / 2.0),
                                   qrLado, qrLado);

    CGFloat textoX = CGRectGetMaxX(self.qrView.frame) + 14.0;
    CGFloat disponible = ancho - textoX - 18.0 - 14.0 - 6.0;
    if (disponible < 40.0) { disponible = 40.0; }

    self.titleLabel.frame = CGRectMake(textoX, roundf(alto / 2.0 - 21.0),
                                       disponible, 21.0);
    self.subtitleLabel.frame = CGRectMake(textoX, roundf(alto / 2.0 + 1.0),
                                          disponible, 16.0);
    self.chevronView.frame = CGRectMake(ancho - 18.0 - 14.0,
                                        roundf((alto - 16.0) / 2.0), 14.0, 16.0);
}

- (void)configureWithResult:(SCQRResult *)result {
    self.qrView.image = result.raw.length
        ? [SCQRCode imageForString:result.raw size:42.0] : nil;

    NSString *titulo = SCHomeLinea(result.title);
    if (!titulo.length) {
        titulo = [SCQRResult displayNameForKind:result.kind];
    }
    self.titleLabel.text = titulo;

    NSString *fecha = SCHomeFecha(result.date);
    NSString *tipo = [SCQRResult displayNameForKind:result.kind];
    if (result.kind == SCQRKindURL && result.raw.length) {
        self.subtitleLabel.text = SCHomeLinea(result.raw);
        self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    } else {
        self.subtitleLabel.text = fecha.length
            ? [NSString stringWithFormat:@"%@ · %@", tipo, fecha]
            : tipo;
        self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.12
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.alpha = highlighted ? 0.82 : 1.0;
    } completion:nil];
}

@end

// ---------------------------------------------------------------------------
// Pantalla de inicio
// ---------------------------------------------------------------------------

@interface SCHomeViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSArray *recentResults;
@property (nonatomic, assign) NSUInteger totalRecords;
@property (nonatomic, assign) CGFloat layoutWidth;

@end

@implementation SCHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [SCTheme background];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [SCTheme background];
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = [SCTheme background];
    [self.scrollView addSubview:self.contentView];

    [self refreshRecords];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshRecords];
    self.layoutWidth = 0.0;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.scrollView.frame = self.view.bounds;

    CGFloat ancho = self.view.bounds.size.width;
    if (ancho < 100.0) { return; }
    if (fabs(ancho - self.layoutWidth) > 0.5) {
        self.layoutWidth = ancho;
        [self rebuild];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)refreshRecords {
    NSArray *todos = [[SCRecordStore sharedStore] records];
    self.totalRecords = todos.count;

    NSUInteger maximo = MIN(todos.count, (NSUInteger)3);
    self.recentResults = maximo > 0
        ? [todos subarrayWithRange:NSMakeRange(0, maximo)]
        : @[];
}

// ---------------------------------------------------------------------------
// Construccion
// ---------------------------------------------------------------------------

- (void)rebuild {
    CGFloat ancho = self.view.bounds.size.width;
    if (ancho < 100.0) { return; }

    for (UIView *vista in self.contentView.subviews) {
        [vista removeFromSuperview];
    }

    CGFloat margen = (ancho >= 700.0) ? 40.0 : 24.0;
    CGFloat util = ancho - margen * 2.0;
    CGFloat y = 42.0;

    // Cabecera.
    UIView *marca = [SCTheme tileWithColor:[SCTheme accentSoft] size:56.0 radius:16.0];
    marca.frame = CGRectMake(margen, y, 56.0, 56.0);
    UIImageView *logo = [[UIImageView alloc] initWithFrame:CGRectMake(13.0, 13.0, 30.0, 30.0)];
    logo.image = [SCGlyph image:SCGlyphKindScan size:30.0 color:[SCTheme accent]];
    logo.contentMode = UIViewContentModeScaleAspectFit;
    [marca addSubview:logo];
    [self.contentView addSubview:marca];

    CGFloat textoX = CGRectGetMaxX(marca.frame) + 16.0;
    UILabel *titulo = [SCTheme labelWithText:@"IScan"
                                       font:[UIFont systemFontOfSize:30.0
                                                             weight:UIFontWeightSemibold]
                                      color:[SCTheme textPrimary]];
    titulo.frame = CGRectMake(textoX, y + 1.0, ancho - margen - textoX, 36.0);
    [self.contentView addSubview:titulo];

    UILabel *subtitulo = [SCTheme labelWithText:@"Lee cualquier código QR"
                                          font:[SCTheme subheadFont]
                                         color:[SCTheme textSecondary]];
    subtitulo.frame = CGRectMake(textoX, y + 37.0, ancho - margen - textoX, 20.0);
    [self.contentView addSubview:subtitulo];

    y = CGRectGetMaxY(marca.frame) + 30.0;

    // Accion principal.
    SCHomeCard *escanear = [[SCHomeCard alloc] initWithTitle:@"Escanear QR"
                                                     subtitle:@"Apunta la cámara a un código"
                                                         icon:SCGlyphKindCamera
                                                      primary:YES];
    escanear.frame = CGRectMake(margen, y, util, 96.0);
    [escanear addTarget:self
                 action:@selector(openScanner)
       forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:escanear];

    y = CGRectGetMaxY(escanear.frame) + 14.0;

    // Historial y archivos.
    NSString *resumen = self.totalRecords > 0
        ? [NSString stringWithFormat:@"%lu códigos guardados",
           (unsigned long)self.totalRecords]
        : @"Todavía no hay lecturas";

    BOOL estrecho = (util < 540.0);
    CGFloat separacion = 14.0;
    CGFloat mitad = 0.0;

    if (estrecho) {
        SCHomeCard *historial = [[SCHomeCard alloc] initWithTitle:@"Historial"
                                                         subtitle:resumen
                                                             icon:SCGlyphKindHistory
                                                          primary:NO];
        historial.frame = CGRectMake(margen, y, util, 84.0);
        [historial addTarget:self
                      action:@selector(showHistory)
            forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:historial];
        y = CGRectGetMaxY(historial.frame) + 10.0;

        SCHomeCard *archivos = [[SCHomeCard alloc] initWithTitle:@"Archivos"
                                                        subtitle:@"Leer QR de imágenes"
                                                            icon:SCGlyphKindFolder
                                                         primary:NO];
        archivos.frame = CGRectMake(margen, y, util, 84.0);
        [archivos addTarget:self
                     action:@selector(showFiles)
           forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:archivos];
        y = CGRectGetMaxY(archivos.frame) + 14.0;
    } else {
        mitad = floorf((util - separacion) / 2.0);

        SCHomeCard *historial = [[SCHomeCard alloc] initWithTitle:@"Historial"
                                                         subtitle:resumen
                                                             icon:SCGlyphKindHistory
                                                          primary:NO];
        historial.frame = CGRectMake(margen, y, mitad, 88.0);
        [historial addTarget:self
                      action:@selector(showHistory)
            forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:historial];

        SCHomeCard *archivos = [[SCHomeCard alloc] initWithTitle:@"Archivos"
                                                        subtitle:@"Leer QR de imágenes"
                                                            icon:SCGlyphKindFolder
                                                         primary:NO];
        archivos.frame = CGRectMake(margen + mitad + separacion, y,
                                    util - mitad - separacion, 88.0);
        [archivos addTarget:self
                     action:@selector(showFiles)
           forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:archivos];

        y += 88.0 + 30.0;
    }

    // Ultimas lecturas.
    if (self.recentResults.count > 0) {
        UILabel *seccion = [[UILabel alloc] initWithFrame:CGRectMake(margen, y, util - 90.0, 16.0)];
        seccion.attributedText = [[NSAttributedString alloc]
            initWithString:@"ÚLTIMAS LECTURAS"
                attributes:@{
                    NSFontAttributeName: [UIFont systemFontOfSize:10.5
                                                           weight:UIFontWeightSemibold],
                    NSForegroundColorAttributeName: [SCTheme textTertiary],
                    NSKernAttributeName: @(0.9)
                }];
        [self.contentView addSubview:seccion];

        UIButton *verTodo = [UIButton buttonWithType:UIButtonTypeCustom];
        verTodo.frame = CGRectMake(ancho - margen - 80.0, y - 4.0, 80.0, 24.0);
        verTodo.titleLabel.font = [UIFont systemFontOfSize:14.0
                                                   weight:UIFontWeightSemibold];
        verTodo.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [verTodo setTitle:@"Ver todo" forState:UIControlStateNormal];
        [verTodo setTitleColor:[SCTheme accent] forState:UIControlStateNormal];
        [verTodo addTarget:self
                    action:@selector(showHistory)
          forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:verTodo];

        y = CGRectGetMaxY(seccion.frame) + 12.0;

        NSUInteger indice = 0;
        for (SCQRResult *result in self.recentResults) {
            SCHomeRecentRow *fila = [[SCHomeRecentRow alloc] initWithFrame:CGRectZero];
            fila.frame = CGRectMake(margen, y, util, 68.0);
            fila.tag = (NSInteger)indice;
            [fila configureWithResult:result];
            [fila addTarget:self
                     action:@selector(recentTapped:)
           forControlEvents:UIControlEventTouchUpInside];
            [self.contentView addSubview:fila];

            y = CGRectGetMaxY(fila.frame) + 10.0;
            indice += 1;
        }
        y += 8.0;
    } else {
        UIView *vacio = [SCTheme cardView];
        vacio.frame = CGRectMake(margen, y, util, 92.0);
        [self.contentView addSubview:vacio];

        UIImageView *icono = [[UIImageView alloc] initWithFrame:CGRectMake(18.0, 26.0, 40.0, 40.0)];
        icono.image = [SCGlyph image:SCGlyphKindHistory size:40.0 color:[SCTheme textTertiary]];
        icono.contentMode = UIViewContentModeScaleAspectFit;
        [vacio addSubview:icono];

        UILabel *tituloVacio = [SCTheme labelWithText:@"Todavía no hay lecturas"
                                                font:[UIFont systemFontOfSize:16.0
                                                                      weight:UIFontWeightSemibold]
                                               color:[SCTheme textPrimary]];
        tituloVacio.frame = CGRectMake(74.0, 24.0, util - 92.0, 22.0);
        [vacio addSubview:tituloVacio];

        UILabel *detalleVacio = [SCTheme labelWithText:
            @"Escanea un QR o abre una imagen desde Archivos."
                                                    font:[SCTheme captionFont]
                                                   color:[SCTheme textSecondary]];
        detalleVacio.frame = CGRectMake(74.0, 48.0, util - 92.0, 20.0);
        [vacio addSubview:detalleVacio];

        y = CGRectGetMaxY(vacio.frame) + 22.0;
    }

    self.contentView.frame = CGRectMake(0, 0, ancho, y);
    self.scrollView.contentSize = CGSizeMake(ancho, y);
}

// ---------------------------------------------------------------------------
// Acciones
// ---------------------------------------------------------------------------

- (void)openScanner {
    SCScannerViewController *scanner = [[SCScannerViewController alloc] init];
    if (self.navigationController) {
        [self.navigationController pushViewController:scanner animated:YES];
    } else {
        UINavigationController *nav =
            [[UINavigationController alloc] initWithRootViewController:scanner];
        nav.navigationBarHidden = YES;
        [self presentViewController:nav animated:YES completion:nil];
    }
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

- (void)showFiles {
    SCFileBrowserViewController *navegador =
        [[SCFileBrowserViewController alloc] init];

    __weak typeof(self) weakSelf = self;
    navegador.onPickPayload = ^(NSString *payload, NSString *fileName) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [strongSelf dismissViewControllerAnimated:YES completion:^{
            [strongSelf handlePayload:payload];
        }];
    };

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:navegador];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)recentTapped:(SCHomeRecentRow *)sender {
    NSInteger indice = sender.tag;
    if (indice < 0 || (NSUInteger)indice >= self.recentResults.count) { return; }
    [self presentResult:self.recentResults[(NSUInteger)indice]];
}

- (void)handlePayload:(NSString *)payload {
    if (!payload.length) { return; }

    SCQRResult *result = [SCQRParser parse:payload];
    [[SCRecordStore sharedStore] add:result];
    [self presentResult:result];
}

- (void)presentResult:(SCQRResult *)result {
    SCResultViewController *detalle =
        [[SCResultViewController alloc] initWithResult:result];

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:detalle];
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
