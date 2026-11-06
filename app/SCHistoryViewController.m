#import "SCHistoryViewController.h"

#import "SCTheme.h"
#import "SCGlyph.h"
#import "SCRecordStore.h"

static SCGlyphKind SCSymbolForKind(SCQRKind kind) {
    switch (kind) {
        case SCQRKindURL: return SCGlyphKindLink;
        case SCQRKindWiFi: return SCGlyphKindWiFi;
        case SCQRKindContact: return SCGlyphKindPerson;
        case SCQRKindEvent: return SCGlyphKindCalendar;
        case SCQRKindEmail: return SCGlyphKindMail;
        case SCQRKindPhone: return SCGlyphKindPhone;
        case SCQRKindSMS: return SCGlyphKindMessage;
        case SCQRKindLocation: return SCGlyphKindPin;
        case SCQRKindOTP: return SCGlyphKindShield;
        case SCQRKindText:
        default: return SCGlyphKindText;
    }
}

static NSString *SCTextoSinSaltos(NSString *texto) {
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

static NSString *SCFechaCorta(NSDate *fecha) {
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

// ---------------------------------------------------------------------------
// Celda
// ---------------------------------------------------------------------------

@interface SCHistoryCell : UITableViewCell

@property (nonatomic, strong) UIView *tile;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

- (void)configureWithResult:(SCQRResult *)result;

@end

@implementation SCHistoryCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [SCTheme surface];
        self.contentView.backgroundColor = [SCTheme surface];
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        UIView *seleccion = [[UIView alloc] initWithFrame:CGRectZero];
        seleccion.backgroundColor = [SCTheme surfaceAlt];
        self.selectedBackgroundView = seleccion;

        _tile = [SCTheme tileWithColor:[SCTheme accentSoft] size:44.0 radius:12.0];
        [self.contentView addSubview:_tile];

        _icon = [[UIImageView alloc] initWithFrame:CGRectMake(11.0, 11.0, 22.0, 22.0)];
        _icon.contentMode = UIViewContentModeScaleAspectFit;
        [_tile addSubview:_icon];

        _titleLabel = [SCTheme labelWithText:@""
                                       font:[SCTheme bodyFont]
                                      color:[SCTheme textPrimary]];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [SCTheme labelWithText:@""
                                          font:[SCTheme captionFont]
                                         color:[SCTheme textSecondary]];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_subtitleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat ancho = self.contentView.bounds.size.width;
    CGFloat margen = 16.0;
    self.tile.frame = CGRectMake(margen, 13.0, 44.0, 44.0);

    CGFloat textoX = CGRectGetMaxX(self.tile.frame) + 14.0;
    CGFloat disponible = ancho - textoX - 34.0;
    if (disponible < 40.0) { disponible = 40.0; }

    self.titleLabel.frame = CGRectMake(textoX, 15.0, disponible, 21.0);
    self.subtitleLabel.frame = CGRectMake(textoX, 37.0, disponible, 16.0);
}

- (void)configureWithResult:(SCQRResult *)result {
    UIColor *acento = [SCTheme accent];
    self.tile.backgroundColor = [SCTheme accentSoft];
    self.icon.image = [SCGlyph image:SCSymbolForKind(result.kind)
                               size:22.0
                              color:acento];

    NSString *titulo = SCTextoSinSaltos(result.title);
    if (!titulo.length) {
        titulo = [SCQRResult displayNameForKind:result.kind];
    }
    self.titleLabel.text = titulo;

    NSString *fecha = SCFechaCorta(result.date);
    NSString *tipo = [SCQRResult displayNameForKind:result.kind];
    self.subtitleLabel.text = fecha.length
        ? [NSString stringWithFormat:@"%@ · %@", tipo, fecha]
        : tipo;
}

@end

// ---------------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------------

@interface SCHistoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) NSArray *items;

@end

@implementation SCHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Historial";
    self.view.backgroundColor = [SCTheme background];
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 70.0;
    self.tableView.separatorColor = [SCTheme stroke];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72.0, 0, 0);
    self.tableView.backgroundColor = [SCTheme background];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 12.0, 0);
    if ([self.tableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {
        self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    }
    [self.tableView registerClass:[SCHistoryCell class]
           forCellReuseIdentifier:@"SCHistoryCell"];
    [self.view addSubview:self.tableView];

    self.emptyView = [self buildEmptyView];
    self.tableView.backgroundView = self.emptyView;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cerrar"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(close)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Borrar"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(confirmClear)];
    self.navigationItem.rightBarButtonItem.tintColor = [SCTheme danger];

    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (UIView *)buildEmptyView {
    CGRect marco = self.tableView.bounds;
    UIView *vista = [[UIView alloc] initWithFrame:marco];
    vista.backgroundColor = [SCTheme background];
    vista.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight;

    UIImageView *icono = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 56.0, 56.0)];
    icono.image = [SCGlyph image:SCGlyphKindHistory size:56.0 color:[SCTheme textTertiary]];
    icono.contentMode = UIViewContentModeScaleAspectFit;
    icono.center = CGPointMake(CGRectGetMidX(marco), CGRectGetMidY(marco) - 74.0);
    icono.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin |
                             UIViewAutoresizingFlexibleBottomMargin;
    [vista addSubview:icono];

    UILabel *titulo = [SCTheme labelWithText:@"Sin lecturas todavía"
                                        font:[SCTheme headlineFont]
                                       color:[SCTheme textPrimary]];
    titulo.textAlignment = NSTextAlignmentCenter;
    titulo.frame = CGRectMake(24.0, CGRectGetMidY(marco) - 8.0,
                              marco.size.width - 48.0, 26.0);
    titulo.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleTopMargin |
                              UIViewAutoresizingFlexibleBottomMargin;
    [vista addSubview:titulo];

    UILabel *detalle = [SCTheme labelWithText:
        @"Los códigos que leas aparecerán aquí, listos para volver a abrirlos."
                                           font:[SCTheme subheadFont]
                                          color:[SCTheme textSecondary]];
    detalle.textAlignment = NSTextAlignmentCenter;
    detalle.frame = CGRectMake(24.0, CGRectGetMidY(marco) + 22.0,
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

- (void)refresh {
    self.items = [[SCRecordStore sharedStore] records];
    [self.tableView reloadData];
    self.tableView.backgroundView.hidden = (self.items.count > 0);
    self.navigationItem.rightBarButtonItem.enabled = (self.items.count > 0);
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCHistoryCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"SCHistoryCell"
                                        forIndexPath:indexPath];
    SCQRResult *result = self.items[(NSUInteger)indexPath.row];
    [cell configureWithResult:result];
    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row < 0 || (NSUInteger)indexPath.row >= self.items.count) {
        return;
    }
    SCQRResult *result = self.items[(NSUInteger)indexPath.row];
    if (self.onSelectResult) {
        self.onSelectResult(result);
    }
}

// ---------------------------------------------------------------------------
// Acciones
// ---------------------------------------------------------------------------

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)confirmClear {
    if (self.items.count == 0) { return; }

    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Borrar historial"
                         message:@"Se eliminarán todas las lecturas guardadas. "
                                @"Esta acción no se puede deshacer."
                  preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Borrar todo"
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *accion) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }
        [[SCRecordStore sharedStore] clear];
        [strongSelf refresh];
    }]];

    [self presentViewController:alerta animated:YES completion:nil];
}

@end
