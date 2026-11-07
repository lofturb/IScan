#import "SCFileBrowserViewController.h"

#import "SCTheme.h"
#import "SCGlyph.h"
#import "SCImageScanner.h"

static BOOL SCEsImagen(NSString *nombre) {
    static NSSet *extensiones = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        extensiones = [NSSet setWithArray:@[
            @"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tif", @"tiff"
        ]];
    });
    return [extensiones containsObject:nombre.pathExtension.lowercaseString];
}

static NSString *SCRutaCorta(NSString *ruta) {
    if (!ruta.length) { return @""; }
    return [ruta stringByReplacingOccurrencesOfString:@"/var/mobile"
                                           withString:@"~"];
}

// ---------------------------------------------------------------------------
// Celda
// ---------------------------------------------------------------------------

@interface SCFileCell : UITableViewCell

@property (nonatomic, strong) UIView *tile;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *detailLabel;

- (void)configureWithName:(NSString *)name
                   detail:(NSString *)detail
                   folder:(BOOL)folder;

@end

@implementation SCFileCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [SCTheme surface];
        self.contentView.backgroundColor = [SCTheme surface];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;

        UIView *seleccion = [[UIView alloc] initWithFrame:CGRectZero];
        seleccion.backgroundColor = [SCTheme surfaceAlt];
        self.selectedBackgroundView = seleccion;

        _tile = [SCTheme tileWithColor:[SCTheme accentSoft] size:44.0 radius:12.0];
        [self.contentView addSubview:_tile];

        _icon = [[UIImageView alloc] initWithFrame:CGRectMake(11.0, 11.0, 22.0, 22.0)];
        _icon.contentMode = UIViewContentModeScaleAspectFit;
        [_tile addSubview:_icon];

        _nameLabel = [SCTheme labelWithText:@""
                                      font:[SCTheme bodyFont]
                                     color:[SCTheme textPrimary]];
        _nameLabel.numberOfLines = 1;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_nameLabel];

        _detailLabel = [SCTheme labelWithText:@""
                                        font:[SCTheme captionFont]
                                       color:[SCTheme textSecondary]];
        _detailLabel.numberOfLines = 1;
        _detailLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_detailLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = self.contentView.bounds.size.width;
    CGFloat margen = 16.0;
    self.tile.frame = CGRectMake(margen, 12.0, 44.0, 44.0);

    CGFloat textoX = CGRectGetMaxX(self.tile.frame) + 14.0;
    CGFloat disponible = ancho - textoX - 16.0;
    if (self.accessoryType != UITableViewCellAccessoryNone) { disponible -= 24.0; }
    if (disponible < 40.0) { disponible = 40.0; }

    self.nameLabel.frame = CGRectMake(textoX, 13.0, disponible, 21.0);
    self.detailLabel.frame = CGRectMake(textoX, 34.0, disponible, 16.0);
}

- (void)configureWithName:(NSString *)name
                   detail:(NSString *)detail
                   folder:(BOOL)folder {
    self.nameLabel.text = name;
    self.detailLabel.text = detail;
    self.icon.image = [SCGlyph image:(folder ? SCGlyphKindFolder : SCGlyphKindPhoto)
                               size:22.0
                              color:[SCTheme accent]];
    self.tile.backgroundColor = [SCTheme accentSoft];
    self.accessoryType = folder ? UITableViewCellAccessoryDisclosureIndicator
                                : UITableViewCellAccessoryNone;
}

@end

// ---------------------------------------------------------------------------
// Navegador
// ---------------------------------------------------------------------------

@interface SCFileBrowserViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL rootsMode;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSArray *entries;

@end

@implementation SCFileBrowserViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _rootsMode = YES;
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _path = [path copy];
        _rootsMode = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [SCTheme background];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.title = self.rootsMode ? @"Archivos"
                                : (self.path.lastPathComponent ?: @"Carpeta");

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 68.0;
    self.tableView.separatorColor = [SCTheme stroke];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 74.0, 0, 0);
    self.tableView.backgroundColor = [SCTheme background];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    [self.tableView registerClass:[SCFileCell class]
           forCellReuseIdentifier:@"SCFileCell"];
    [self.view addSubview:self.tableView];

    self.emptyView = [self buildEmptyView];
    self.tableView.backgroundView = self.emptyView;

    if (self.rootsMode) {
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Cancelar"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(close)];
    }

    [self reload];
}

- (UIView *)buildEmptyView {
    CGRect marco = self.tableView.bounds;
    UIView *vista = [[UIView alloc] initWithFrame:marco];
    vista.backgroundColor = [SCTheme background];
    vista.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight;

    UIImageView *icono = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 48.0, 48.0)];
    icono.image = [SCGlyph image:SCGlyphKindFolder size:48.0 color:[SCTheme textTertiary]];
    icono.contentMode = UIViewContentModeScaleAspectFit;
    icono.center = CGPointMake(CGRectGetMidX(marco), CGRectGetMidY(marco) - 56.0);
    icono.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin |
                             UIViewAutoresizingFlexibleBottomMargin;
    [vista addSubview:icono];

    UILabel *titulo = [SCTheme labelWithText:@"No hay imágenes aquí"
                                        font:[SCTheme headlineFont]
                                       color:[SCTheme textPrimary]];
    titulo.textAlignment = NSTextAlignmentCenter;
    titulo.frame = CGRectMake(24.0, CGRectGetMidY(marco) - 6.0,
                              marco.size.width - 48.0, 26.0);
    titulo.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleBottomMargin;
    [vista addSubview:titulo];

    UILabel *detalle = [SCTheme labelWithText:
        @"Copia aquí los PNG o JPG con el QR, o entra en otra carpeta."
                                           font:[SCTheme subheadFont]
                                          color:[SCTheme textSecondary]];
    detalle.textAlignment = NSTextAlignmentCenter;
    detalle.frame = CGRectMake(24.0, CGRectGetMidY(marco) + 24.0,
                               marco.size.width - 48.0, 48.0);
    detalle.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                               UIViewAutoresizingFlexibleTopMargin |
                               UIViewAutoresizingFlexibleBottomMargin;
    [vista addSubview:detalle];

    return vista;
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

- (NSArray *)rootLocations {
    NSMutableArray *raices = [NSMutableArray array];

    NSArray *documentos = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                              NSUserDomainMask, YES);
    NSString *propios = documentos.firstObject;
    if (propios.length) {
        [raices addObject:@{ @"name": @"Documentos de IScan",
                             @"path": propios,
                             @"detail": @"Carpeta de la app (iTunes / Filza)" }];
    }

    NSArray *candidatas = @[
        @[ @"Documentos del iPad", @"/var/mobile/Documents", @"Carpeta del usuario" ],
        @[ @"Descargas", @"/var/mobile/Downloads", @"Descargas de Safari" ],
        @[ @"Fotos", @"/var/mobile/Media/DCIM", @"Cámara y capturas" ],
        @[ @"iCloud Drive", @"/var/mobile/Library/Mobile Documents/com~apple~CloudDocs",
           @"Archivos de iCloud" ],
        @[ @"Mediateca", @"/var/mobile/Media", @"Todo el almacenamiento de medios" ]
    ];

    NSFileManager *gestor = [NSFileManager defaultManager];
    for (NSArray *candidata in candidatas) {
        NSString *ruta = candidata[1];
        BOOL esCarpeta = NO;
        if ([gestor fileExistsAtPath:ruta isDirectory:&esCarpeta] && esCarpeta) {
            [raices addObject:@{ @"name": candidata[0],
                                 @"path": ruta,
                                 @"detail": candidata[2] }];
        }
    }
    return raices;
}

- (NSString *)detailForFolder:(NSString *)ruta {
    return SCRutaCorta(ruta);
}

- (NSString *)detailForFile:(NSString *)ruta {
    NSDictionary *atributos = [[NSFileManager defaultManager]
                               attributesOfItemAtPath:ruta error:NULL];
    NSNumber *tamano = atributos[NSFileSize];
    NSDate *fecha = atributos[NSFileModificationDate];

    NSMutableArray *partes = [NSMutableArray array];
    NSString *extension = ruta.pathExtension.uppercaseString;
    if (extension.length) { [partes addObject:extension]; }

    if ([tamano isKindOfClass:[NSNumber class]]) {
        NSByteCountFormatter *formato = [[NSByteCountFormatter alloc] init];
        formato.allowedUnits = NSByteCountFormatterUseKB | NSByteCountFormatterUseMB;
        formato.countStyle = NSByteCountFormatterCountStyleFile;
        NSString *texto = [formato stringFromByteCount:tamano.longLongValue];
        if (texto.length) { [partes addObject:texto]; }
    }

    if ([fecha isKindOfClass:[NSDate class]]) {
        NSDateFormatter *formato = [[NSDateFormatter alloc] init];
        formato.locale = [NSLocale localeWithLocaleIdentifier:@"es_ES"];
        formato.dateFormat = @"d MMM yyyy, HH:mm";
        NSString *texto = [formato stringFromDate:fecha];
        if (texto.length) { [partes addObject:texto]; }
    }

    return [partes componentsJoinedByString:@" · "];
}

- (void)reload {
    if (self.rootsMode) {
        self.entries = [self rootLocations];
        self.title = @"Archivos";
    } else {
        NSFileManager *gestor = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *nombres = [gestor contentsOfDirectoryAtPath:self.path error:&error];
        if (!nombres) {
            NSLog(@"[IScan] No se pudo leer %@: %@", self.path, error);
            nombres = @[];
        }

        NSMutableArray *entradas = [NSMutableArray array];
        for (NSString *nombre in nombres) {
            if (nombre.length == 0 || [nombre hasPrefix:@"."]) { continue; }

            NSString *ruta = [self.path stringByAppendingPathComponent:nombre];
            BOOL esCarpeta = NO;
            if (![gestor fileExistsAtPath:ruta isDirectory:&esCarpeta]) { continue; }

            if (esCarpeta) {
                [entradas addObject:@{ @"name": nombre,
                                       @"path": ruta,
                                       @"folder": @YES,
                                       @"detail": [self detailForFolder:ruta] }];
            } else if (SCEsImagen(nombre)) {
                [entradas addObject:@{ @"name": nombre,
                                       @"path": ruta,
                                       @"folder": @NO,
                                       @"detail": [self detailForFile:ruta] }];
            }
        }

        self.entries = [entradas sortedArrayUsingComparator:
            ^NSComparisonResult(id objA, id objB) {
                NSDictionary *a = (NSDictionary *)objA;
                NSDictionary *b = (NSDictionary *)objB;
                BOOL carpetaA = [a[@"folder"] boolValue];
                BOOL carpetaB = [b[@"folder"] boolValue];
                if (carpetaA != carpetaB) {
                    return carpetaA ? NSOrderedAscending : NSOrderedDescending;
                }
                return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
            }];
        self.title = self.path.lastPathComponent ?: @"Carpeta";
    }

    [self.tableView reloadData];
    self.tableView.backgroundView.hidden = (self.entries.count > 0);
}

// ---------------------------------------------------------------------------
// Tabla
// ---------------------------------------------------------------------------

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCFileCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SCFileCell"
                                                      forIndexPath:indexPath];
    NSDictionary *entrada = self.entries[(NSUInteger)indexPath.row];
    [cell configureWithName:entrada[@"name"]
                     detail:entrada[@"detail"]
                     folder:[entrada[@"folder"] boolValue]];
    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row < 0 || (NSUInteger)indexPath.row >= self.entries.count) {
        return;
    }
    NSDictionary *entrada = self.entries[(NSUInteger)indexPath.row];

    if ([entrada[@"folder"] boolValue]) {
        SCFileBrowserViewController *siguiente =
            [[SCFileBrowserViewController alloc] initWithPath:entrada[@"path"]];
        [self.navigationController pushViewController:siguiente animated:YES];
        return;
    }

    [self scanPath:entrada[@"path"] name:entrada[@"name"]];
}

// ---------------------------------------------------------------------------
// Lectura
// ---------------------------------------------------------------------------

- (void)scanPath:(NSString *)ruta name:(NSString *)nombre {
    UIView *hud = [SCTheme tileWithColor:[[SCTheme background] colorWithAlphaComponent:0.94]
                                    size:112.0
                                  radius:16.0];
    hud.center = CGPointMake(CGRectGetMidX(self.view.bounds),
                             CGRectGetMidY(self.view.bounds));
    hud.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                           UIViewAutoresizingFlexibleRightMargin |
                           UIViewAutoresizingFlexibleTopMargin |
                           UIViewAutoresizingFlexibleBottomMargin;

    UIActivityIndicatorView *rueda = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    rueda.center = CGPointMake(56.0, 42.0);
    [rueda startAnimating];
    [hud addSubview:rueda];

    UILabel *texto = [SCTheme labelWithText:@"Leyendo…"
                                       font:[SCTheme captionFont]
                                      color:[SCTheme textSecondary]];
    texto.textAlignment = NSTextAlignmentCenter;
    texto.frame = CGRectMake(8.0, 72.0, 96.0, 18.0);
    [hud addSubview:texto];

    [self.view addSubview:hud];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *payload = [SCImageScanner payloadFromImageAtPath:ruta];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud removeFromSuperview];

            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }

            if (payload.length) {
                if (strongSelf.onPickPayload) {
                    strongSelf.onPickPayload(payload, nombre);
                }
            } else {
                [strongSelf showAlert:@"Sin código QR"
                              message:@"No se encontró ningún QR legible en esa imagen."];
            }
        });
    });
}

// ---------------------------------------------------------------------------
// Acciones
// ---------------------------------------------------------------------------

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showAlert:(NSString *)titulo message:(NSString *)mensaje {
    UIAlertController *alerta =
        [UIAlertController alertControllerWithTitle:titulo
                                            message:mensaje
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

@end
