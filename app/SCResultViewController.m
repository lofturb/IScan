#import "SCResultViewController.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <EventKit/EventKit.h>

#import "SCTheme.h"
#import "SCGlyph.h"
#import "SCWiFiJoiner.h"
#import "SCQRCode.h"
#import "SCQRCard.h"

static SCGlyphKind SCGlyphForKind(SCQRKind kind) {
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

@interface SCResultViewController () <ABNewPersonViewControllerDelegate>

@property (nonatomic, strong) SCQRResult *result;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *leftButton;
@property (nonatomic, strong) UIButton *rightButton;
@property (nonatomic, strong) UIButton *qrButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableArray *valueLabels;
@property (nonatomic, strong) NSMutableArray *eyeButtons;
@property (nonatomic, strong) NSMutableIndexSet *revealed;
@property (nonatomic, strong) EKEventStore *eventStore;
@property (nonatomic, assign) CGFloat layoutWidth;

@end

@implementation SCResultViewController

- (instancetype)initWithResult:(SCQRResult *)result {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _result = result;
        _valueLabels = [NSMutableArray array];
        _eyeButtons = [NSMutableArray array];
        _revealed = [NSMutableIndexSet indexSet];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SCTheme surface];
    self.preferredContentSize = CGSizeMake(560.0, 660.0);

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.backgroundColor = [SCTheme surface];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                       UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = [SCTheme surface];
    [self.scrollView addSubview:self.contentView];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.backgroundColor = [SCTheme surfaceAlt];
    self.closeButton.layer.cornerRadius = 17.0;
    self.closeButton.tintColor = [SCTheme textSecondary];
    [self.closeButton setImage:[SCGlyph image:SCGlyphKindClose
                                        size:15.0
                                       color:[SCTheme textSecondary]]
                      forState:UIControlStateNormal];
    [self.closeButton addTarget:self
                         action:@selector(close)
               forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = self.view.bounds.size.width;
    if (width < 100.0) { return; }

    self.scrollView.frame = self.view.bounds;
    self.closeButton.frame = CGRectMake(width - 22.0 - 34.0, 20.0, 34.0, 34.0);

    if (fabs(width - self.layoutWidth) > 0.5) {
        self.layoutWidth = width;
        [self rebuild];
    }
}

// ---------------------------------------------------------------------------
// Construccion del contenido
// ---------------------------------------------------------------------------

- (void)rebuild {
    for (UIView *vista in self.contentView.subviews) {
        [vista removeFromSuperview];
    }
    [self.valueLabels removeAllObjects];
    [self.eyeButtons removeAllObjects];

    CGFloat ancho = self.view.bounds.size.width;
    CGFloat margen = 24.0;
    CGFloat util = ancho - margen * 2.0;
    CGFloat y = 26.0;

    SCQRKind kind = self.result.kind;
    UIColor *acento = [SCTheme accent];

    // Icono del tipo.
    UIView *teja = [SCTheme tileWithColor:[SCTheme accentSoft] size:48.0 radius:14.0];
    teja.frame = CGRectMake(margen, y, 48.0, 48.0);
    UIImageView *icono = [[UIImageView alloc] initWithFrame:CGRectMake(12.0, 12.0, 24.0, 24.0)];
    icono.image = [SCGlyph image:SCGlyphForKind(kind) size:24.0 color:acento];
    icono.tintColor = acento;
    [teja addSubview:icono];
    [self.contentView addSubview:teja];

    CGFloat textoX = CGRectGetMaxX(teja.frame) + 16.0;
    CGFloat textoAncho = ancho - margen - 34.0 - textoX;

    NSString *tipo = [[SCQRResult displayNameForKind:kind] uppercaseString];
    UILabel *tipoLabel = [[UILabel alloc] initWithFrame:CGRectMake(textoX, y + 1.0,
                                                                   textoAncho, 14.0)];
    tipoLabel.attributedText = [[NSAttributedString alloc]
        initWithString:tipo
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold],
                NSForegroundColorAttributeName: acento,
                NSKernAttributeName: @(0.9)
            }];
    [self.contentView addSubview:tipoLabel];

    UILabel *titulo = [SCTheme labelWithText:self.result.title
                                        font:[UIFont systemFontOfSize:21.0
                                                              weight:UIFontWeightSemibold]
                                       color:[SCTheme textPrimary]];
    titulo.numberOfLines = 3;
    CGSize tituloTam = [titulo sizeThatFits:CGSizeMake(textoAncho, 200.0)];
    titulo.frame = CGRectMake(textoX, y + 17.0, textoAncho, MAX(26.0, tituloTam.height));
    [self.contentView addSubview:titulo];

    y = MAX(CGRectGetMaxY(teja.frame), CGRectGetMaxY(titulo.frame)) + 20.0;

    [self addSeparatorAtY:y width:ancho margin:margen];
    y += 18.0;

    // QR junto a su informacion (en los enlaces, el destino completo).
    y = [self addQRBlockAtY:y width:ancho margin:margen util:util] + 18.0;
    [self addSeparatorAtY:y width:ancho margin:margen];
    y += 18.0;

    // Campos.
    NSUInteger indice = 0;
    for (SCQRField *field in self.result.fields) {
        y = [self addField:field
                     index:indice
                       top:y
                     width:ancho
                    margin:margen
                     util:util];
        indice += 1;
    }

    y += 6.0;

    // Accion principal.
    self.primaryButton = [SCTheme buttonWithTitle:[self primaryTitle]
                                       background:acento
                                       foreground:[UIColor whiteColor]
                                             icon:[SCGlyph image:SCGlyphForKind(kind)
                                                             size:19.0
                                                            color:[UIColor whiteColor]]];
    self.primaryButton.frame = CGRectMake(margen, y, util, 52.0);
    [self.primaryButton addTarget:self
                           action:@selector(primaryAction)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.primaryButton];

    self.spinner = [[UIActivityIndicatorView alloc]
                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.frame = CGRectMake(16.0, 16.0, 20.0, 20.0);
    [self.primaryButton addSubview:self.spinner];

    y = CGRectGetMaxY(self.primaryButton.frame) + 10.0;

    if (kind == SCQRKindWiFi) {
        UILabel *nota = [SCTheme labelWithText:
            @"La conexión directa usa la API privada de iOS 9. Si falla, IScan copia la "
            @"contraseña y abre Ajustes para pegarla."
                                            font:[SCTheme tinyFont]
                                           color:[SCTheme textTertiary]];
        CGSize notaTam = [nota sizeThatFits:CGSizeMake(util, 100.0)];
        nota.frame = CGRectMake(margen, y, util, notaTam.height);
        [self.contentView addSubview:nota];
        y = CGRectGetMaxY(nota.frame) + 14.0;
    } else {
        y += 4.0;
    }

    // Acciones secundarias.
    CGFloat mitad = floorf((util - 10.0) / 2.0);
    self.leftButton = [self secondaryButtonWithTitle:[self leftTitle]
                                              action:@selector(leftAction)];
    self.leftButton.frame = CGRectMake(margen, y, mitad, 46.0);
    [self.contentView addSubview:self.leftButton];

    self.rightButton = [self secondaryButtonWithTitle:[self rightTitle]
                                               action:@selector(rightAction)];
    self.rightButton.frame = CGRectMake(margen + mitad + 10.0, y, util - mitad - 10.0, 46.0);
    [self.contentView addSubview:self.rightButton];

    y = CGRectGetMaxY(self.leftButton.frame) + 10.0;

    self.qrButton = [SCTheme buttonWithTitle:@"Compartir imagen del QR"
                                  background:[SCTheme surfaceAlt]
                                  foreground:[SCTheme textPrimary]
                                        icon:[SCGlyph image:SCGlyphKindShare
                                                        size:17.0
                                                       color:[SCTheme textPrimary]]];
    self.qrButton.titleLabel.font = [UIFont systemFontOfSize:14.5
                                                      weight:UIFontWeightMedium];
    self.qrButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 10.0, 12.0, 10.0);
    self.qrButton.frame = CGRectMake(margen, y, util, 46.0);
    [self.qrButton addTarget:self
                      action:@selector(shareQRCard)
            forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.qrButton];

    y = CGRectGetMaxY(self.qrButton.frame) + 24.0;

    // Contenido original.
    UILabel *rawTitulo = [[UILabel alloc] initWithFrame:CGRectMake(margen, y, util, 14.0)];
    rawTitulo.attributedText = [[NSAttributedString alloc]
        initWithString:@"CONTENIDO ORIGINAL"
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:10.5 weight:UIFontWeightSemibold],
                NSForegroundColorAttributeName: [SCTheme textTertiary],
                NSKernAttributeName: @(0.9)
            }];
    [self.contentView addSubview:rawTitulo];
    y = CGRectGetMaxY(rawTitulo.frame) + 8.0;

    NSString *raw = self.result.raw ?: @"";
    if (raw.length > 2000) {
        raw = [[raw substringToIndex:2000] stringByAppendingString:@"…"];
    }
    UILabel *rawLabel = [SCTheme labelWithText:raw
                                          font:[SCTheme monoFont:12.0]
                                         color:[SCTheme textSecondary]];
    CGSize rawTam = [rawLabel sizeThatFits:CGSizeMake(util - 24.0, CGFLOAT_MAX)];
    UIView *rawCaja = [SCTheme tileWithColor:[SCTheme surfaceAlt] size:0 radius:10.0];
    rawCaja.frame = CGRectMake(margen, y, util, rawTam.height + 24.0);
    rawLabel.frame = CGRectMake(12.0, 12.0, util - 24.0, rawTam.height);
    [rawCaja addSubview:rawLabel];
    [self.contentView addSubview:rawCaja];

    y = CGRectGetMaxY(rawCaja.frame) + 26.0;

    self.contentView.frame = CGRectMake(0, 0, ancho, y);
    self.scrollView.contentSize = CGSizeMake(ancho, y);
}

- (CGFloat)addQRBlockAtY:(CGFloat)top
                   width:(CGFloat)ancho
                  margin:(CGFloat)margen
                    util:(CGFloat)util {
    CGFloat qrLado = 126.0;
    CGFloat alto = qrLado + 28.0;

    UIView *caja = [SCTheme tileWithColor:[SCTheme surfaceAlt] size:0 radius:14.0];
    caja.frame = CGRectMake(margen, top, util, alto);

    UIImageView *qrVista = [[UIImageView alloc] initWithFrame:CGRectMake(14.0, 14.0,
                                                                        qrLado, qrLado)];
    qrVista.backgroundColor = [UIColor whiteColor];
    qrVista.contentMode = UIViewContentModeScaleAspectFit;
    qrVista.layer.cornerRadius = 8.0;
    qrVista.layer.masksToBounds = YES;
    qrVista.image = [SCQRCode imageForString:self.result.raw size:qrLado];
    [caja addSubview:qrVista];

    CGFloat infoX = CGRectGetMaxX(qrVista.frame) + 16.0;
    CGFloat infoAncho = util - infoX - 16.0;

    NSString *etiqueta = @"CÓDIGO QR";
    NSString *principal = self.result.title ?: @"";
    BOOL esEnlace = (self.result.kind == SCQRKindURL);

    if (self.result.kind == SCQRKindWiFi) {
        etiqueta = @"RED WIFI";
        NSString *ssid = self.result.info[@"ssid"];
        principal = ssid.length ? ssid : self.result.title;
    } else if (esEnlace) {
        etiqueta = @"ENLACE";
        principal = self.result.action.length ? self.result.action : self.result.raw;
    }

    UILabel *tag = [[UILabel alloc] initWithFrame:CGRectMake(infoX, 18.0,
                                                             infoAncho, 13.0)];
    tag.attributedText = [[NSAttributedString alloc]
        initWithString:etiqueta
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:10.0
                                                       weight:UIFontWeightSemibold],
                NSForegroundColorAttributeName: [SCTheme accent],
                NSKernAttributeName: @(0.9)
            }];
    [caja addSubview:tag];

    UIFont *fuente = esEnlace ? [SCTheme monoFont:11.5]
                              : [UIFont systemFontOfSize:15.0
                                                  weight:UIFontWeightSemibold];
    UILabel *valor = [SCTheme labelWithText:principal ?: @""
                                       font:fuente
                                      color:[SCTheme textPrimary]];
    valor.numberOfLines = esEnlace ? 4 : 2;
    valor.lineBreakMode = esEnlace ? NSLineBreakByTruncatingMiddle
                                   : NSLineBreakByTruncatingTail;
    CGSize valorTam = [valor sizeThatFits:CGSizeMake(infoAncho,
                                                     esEnlace ? 60.0 : 40.0)];
    CGFloat valorAlto = MIN(valorTam.height, esEnlace ? 56.0 : 38.0);
    valor.frame = CGRectMake(infoX, 38.0, infoAncho, MAX(18.0, valorAlto));
    [caja addSubview:valor];

    NSString *pie = @"Comparte el QR con toda su información.";
    if (esEnlace) {
        pie = @"Comparte el QR con su enlace.";
    } else if (self.result.kind == SCQRKindWiFi) {
        pie = @"El botón principal intenta conectarse a esta red.";
    }

    UILabel *pieLabel = [SCTheme labelWithText:pie
                                         font:[SCTheme tinyFont]
                                        color:[SCTheme textTertiary]];
    pieLabel.numberOfLines = 2;
    CGSize pieTam = [pieLabel sizeThatFits:CGSizeMake(infoAncho, 40.0)];
    CGFloat pieY = MAX(CGRectGetMaxY(valor.frame) + 8.0, 84.0);
    pieLabel.frame = CGRectMake(infoX, pieY, infoAncho, MIN(pieTam.height, 34.0));
    [caja addSubview:pieLabel];

    [self.contentView addSubview:caja];
    return CGRectGetMaxY(caja.frame);
}

- (CGFloat)addField:(SCQRField *)field
              index:(NSUInteger)index
                top:(CGFloat)top
              width:(CGFloat)ancho
             margin:(CGFloat)margen
               util:(CGFloat)util {
    CGFloat y = top;

    UILabel *etiqueta = [[UILabel alloc] initWithFrame:CGRectMake(margen, y, util, 13.0)];
    etiqueta.attributedText = [[NSAttributedString alloc]
        initWithString:[field.label uppercaseString]
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium],
                NSForegroundColorAttributeName: [SCTheme textTertiary],
                NSKernAttributeName: @(0.7)
            }];
    [self.contentView addSubview:etiqueta];
    y = CGRectGetMaxY(etiqueta.frame) + 4.0;

    BOOL secreto = field.secret && field.value.length > 0;
    CGFloat reserva = 34.0;
    if (secreto) { reserva += 36.0; }

    UILabel *valor = [SCTheme labelWithText:(secreto ? [self maskedValue] : field.value)
                                       font:(field.mono ? [SCTheme monoFont:13.0]
                                                        : [UIFont systemFontOfSize:16.0])
                                      color:[SCTheme textPrimary]];
    valor.tag = 2000 + index;
    CGSize valorTam = [valor sizeThatFits:CGSizeMake(util - reserva, CGFLOAT_MAX)];
    valor.frame = CGRectMake(margen, y, util - reserva, MAX(21.0, valorTam.height));
    [self.contentView addSubview:valor];
    [self.valueLabels addObject:valor];

    CGFloat botonY = y - 5.0;

    UIButton *copiar = [self iconButton:SCGlyphKindCopy];
    copiar.frame = CGRectMake(ancho - margen - 30.0, botonY, 30.0, 30.0);
    copiar.tag = 3000 + index;
    [copiar addTarget:self
               action:@selector(copyField:)
     forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:copiar];

    if (secreto) {
        UIButton *ojo = [self iconButton:SCGlyphKindEyeOff];
        ojo.frame = CGRectMake(ancho - margen - 30.0 - 36.0, botonY, 30.0, 30.0);
        ojo.tag = 1000 + index;
        [ojo addTarget:self
                action:@selector(toggleSecret:)
      forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:ojo];
        [self.eyeButtons addObject:ojo];
    }

    y = MAX(CGRectGetMaxY(valor.frame), CGRectGetMaxY(copiar.frame)) + 12.0;
    [self addSeparatorAtY:y width:ancho margin:margen];
    return y + 14.0;
}

- (UIButton *)iconButton:(SCGlyphKind)kind {
    UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
    boton.backgroundColor = [SCTheme surfaceAlt];
    boton.layer.cornerRadius = 8.0;
    boton.tintColor = [SCTheme textSecondary];
    [boton setImage:[SCGlyph image:kind size:15.0 color:[SCTheme textSecondary]]
           forState:UIControlStateNormal];
    return boton;
}

- (UIButton *)secondaryButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *boton = [SCTheme buttonWithTitle:title
                                    background:[SCTheme surfaceAlt]
                                    foreground:[SCTheme textPrimary]
                                          icon:nil];
    boton.titleLabel.font = [UIFont systemFontOfSize:14.5 weight:UIFontWeightMedium];
    boton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 10.0, 12.0, 10.0);
    [boton addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return boton;
}

- (void)addSeparatorAtY:(CGFloat)y width:(CGFloat)ancho margin:(CGFloat)margen {
    UIView *linea = [[UIView alloc] initWithFrame:CGRectMake(margen, y, ancho - margen * 2.0, 1.0)];
    linea.backgroundColor = [SCTheme stroke];
    [self.contentView addSubview:linea];
}

- (NSString *)maskedValue {
    return @"••••••••••";
}

// ---------------------------------------------------------------------------
// Textos de las acciones
// ---------------------------------------------------------------------------

- (NSString *)primaryTitle {
    switch (self.result.kind) {
        case SCQRKindWiFi:
            return [SCWiFiJoiner isSupported] ? @"Conectar a la red" : @"Abrir Ajustes WiFi";
        case SCQRKindURL: return @"Abrir enlace";
        case SCQRKindEmail: return @"Escribir correo";
        case SCQRKindPhone: return @"Llamar";
        case SCQRKindSMS: return @"Enviar mensaje";
        case SCQRKindLocation: return @"Ver en Mapas";
        case SCQRKindContact: return @"Añadir a Contactos";
        case SCQRKindEvent: return @"Añadir a Calendario";
        case SCQRKindOTP: return @"Copiar secreto";
        case SCQRKindText:
        default: return @"Copiar texto";
    }
}

- (NSString *)leftTitle {
    switch (self.result.kind) {
        case SCQRKindWiFi:
            return self.result.info[@"password"] && [self.result.info[@"password"] length]
                ? @"Copiar contraseña" : @"Copiar red";
        case SCQRKindURL: return @"Copiar enlace";
        case SCQRKindOTP: return @"Copiar secreto";
        default: return @"Copiar";
    }
}

- (NSString *)rightTitle {
    if (self.result.kind == SCQRKindWiFi) { return @"Ajustes WiFi"; }
    return @"Compartir";
}

// ---------------------------------------------------------------------------
// Acciones
// ---------------------------------------------------------------------------

- (void)primaryAction {
    switch (self.result.kind) {
        case SCQRKindWiFi:
            if ([SCWiFiJoiner isSupported]) {
                [self joinWiFi];
            } else {
                [SCWiFiJoiner openWiFiSettings];
            }
            break;
        case SCQRKindURL:
        case SCQRKindEmail:
        case SCQRKindPhone:
        case SCQRKindSMS:
        case SCQRKindLocation:
            [self openResultAction];
            break;
        case SCQRKindContact:
            [self addContact];
            break;
        case SCQRKindEvent:
            [self addEvent];
            break;
        case SCQRKindOTP:
            [self copyString:[self secretValue] message:@"Secreto copiado"];
            break;
        case SCQRKindText:
        default:
            [self copyString:self.result.raw message:@"Texto copiado"];
            break;
    }
}

- (void)leftAction {
    if (self.result.kind == SCQRKindWiFi) {
        NSString *password = self.result.info[@"password"];
        if (password.length) {
            [self copyString:password message:@"Contraseña copiada"];
        } else {
            [self copyString:self.result.info[@"ssid"] ?: @"" message:@"Red copiada"];
        }
        return;
    }
    if (self.result.kind == SCQRKindURL) {
        [self copyString:self.result.action ?: self.result.raw message:@"Enlace copiado"];
        return;
    }
    if (self.result.kind == SCQRKindOTP) {
        [self copyString:[self secretValue] message:@"Secreto copiado"];
        return;
    }
    [self copyString:self.result.raw message:@"Copiado"];
}

- (void)rightAction {
    if (self.result.kind == SCQRKindWiFi) {
        [SCWiFiJoiner openWiFiSettings];
        return;
    }
    [self share];
}

- (NSString *)secretValue {
    NSString *secret = self.result.info[@"secret"];
    return secret.length ? secret : self.result.raw;
}

- (void)copyField:(UIButton *)sender {
    NSInteger index = sender.tag - 3000;
    if (index < 0 || (NSUInteger)index >= self.result.fields.count) { return; }
    SCQRField *field = self.result.fields[index];
    [self copyString:field.value message:@"Copiado"];
}

- (void)toggleSecret:(UIButton *)sender {
    NSInteger index = sender.tag - 1000;
    if (index < 0 || (NSUInteger)index >= self.result.fields.count) { return; }
    SCQRField *field = self.result.fields[index];

    BOOL revelado = [self.revealed containsIndex:(NSUInteger)index];
    if (revelado) {
        [self.revealed removeIndex:(NSUInteger)index];
    } else {
        [self.revealed addIndex:(NSUInteger)index];
    }

    UILabel *valor = [self.contentView viewWithTag:2000 + index];
    valor.text = revelado ? [self maskedValue] : field.value;

    SCGlyphKind tipo = revelado ? SCGlyphKindEyeOff : SCGlyphKindEye;
    [sender setImage:[SCGlyph image:tipo size:15.0 color:[SCTheme textSecondary]]
            forState:UIControlStateNormal];
}

- (void)copyString:(NSString *)text message:(NSString *)message {
    if (!text.length) { return; }
    [[UIPasteboard generalPasteboard] setString:text];
    [SCTheme toast:message inView:self.view];
}

- (void)shareQRCard {
    UIImage *imagen = [SCQRCard imageForResult:self.result];
    if (!imagen) {
        [self showAlert:@"No se pudo crear la imagen"
                message:@"Este código no se puede dibujar como QR."];
        return;
    }

    NSMutableArray *elementos = [NSMutableArray arrayWithObject:imagen];
    if (self.result.raw.length) { [elementos addObject:self.result.raw]; }

    UIActivityViewController *actividad =
        [[UIActivityViewController alloc] initWithActivityItems:elementos
                                          applicationActivities:nil];
    if ([actividad respondsToSelector:@selector(popoverPresentationController)]) {
        UIView *origen = self.qrButton ?: self.view;
        actividad.popoverPresentationController.sourceView = origen;
        actividad.popoverPresentationController.sourceRect = self.qrButton
            ? self.qrButton.bounds
            : CGRectMake(CGRectGetMidX(origen.bounds), CGRectGetMidY(origen.bounds), 1.0, 1.0);
    }
    [self presentViewController:actividad animated:YES completion:nil];
}

- (void)share {
    UIActivityViewController *actividad =
        [[UIActivityViewController alloc] initWithActivityItems:@[ self.result.raw ?: @"" ]
                                          applicationActivities:nil];
    if ([actividad respondsToSelector:@selector(popoverPresentationController)]) {
        actividad.popoverPresentationController.sourceView = self.rightButton;
        actividad.popoverPresentationController.sourceRect = self.rightButton.bounds;
    }
    [self presentViewController:actividad animated:YES completion:nil];
}

- (void)openResultAction {
    NSString *texto = self.result.action;
    if (!texto.length) {
        [self showAlert:@"Sin destino" message:@"Este código no incluye una acción que se pueda abrir."];
        return;
    }
    NSURL *url = [NSURL URLWithString:texto];
    UIApplication *app = [UIApplication sharedApplication];
    if (url && [app canOpenURL:url]) {
        [app openURL:url];
        return;
    }

    NSString *motivo = @"Este dispositivo no puede abrir ese tipo de enlace.";
    if (self.result.kind == SCQRKindPhone) {
        motivo = @"El iPad no puede hacer llamadas. El número se ha copiado al portapapeles.";
        [self copyString:self.result.info[@"number"] message:@"Número copiado"];
    }
    [self showAlert:@"No se puede abrir" message:motivo];
}

// --- WiFi ------------------------------------------------------------------

- (void)joinWiFi {
    NSString *ssid = self.result.info[@"ssid"];
    NSString *password = self.result.info[@"password"];
    BOOL oculta = [self.result.info[@"hidden"] boolValue];

    if (!ssid.length) {
        [SCWiFiJoiner openWiFiSettings];
        return;
    }

    self.primaryButton.enabled = NO;
    [self.primaryButton setTitle:@"Conectando…" forState:UIControlStateNormal];
    [self.spinner startAnimating];

    __weak typeof(self) weakSelf = self;
    [SCWiFiJoiner joinSSID:ssid
                   password:password ?: @""
                     hidden:oculta
                 completion:^(SCWiFiJoinStatus status, NSString *detail) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        [strongSelf.spinner stopAnimating];
        strongSelf.primaryButton.enabled = YES;

        if (status == SCWiFiJoinStatusSuccess) {
            [strongSelf.primaryButton setTitle:@"Abrir Ajustes WiFi"
                                      forState:UIControlStateNormal];
            [SCTheme toast:detail inView:strongSelf.view];
        } else {
            [strongSelf.primaryButton setTitle:@"Abrir Ajustes WiFi"
                                      forState:UIControlStateNormal];
            [strongSelf offerManualWiFi:detail];
        }
    }];
}

- (void)offerManualWiFi:(NSString *)detail {
    NSString *password = self.result.info[@"password"];
    if (password.length) {
        // Con la contraseña en el portapapeles, pegarla en Ajustes es inmediato.
        [[UIPasteboard generalPasteboard] setString:password];
    }

    NSString *mensaje = detail.length ? detail : @"No se pudo conectar automáticamente.";
    if (password.length) {
        mensaje = [mensaje stringByAppendingString:
                   @"\n\nLa contraseña está copiada: pégala en Ajustes › Wi-Fi."];
    }

    UIAlertController *alerta =
        [UIAlertController alertControllerWithTitle:@"Conexión manual"
                                            message:mensaje
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Abrir Ajustes"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        [SCWiFiJoiner openWiFiSettings];
    }]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cerrar"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

// --- Contactos -------------------------------------------------------------

- (void)addContact {
    ABAddressBookRef libreta = ABAddressBookCreateWithOptions(NULL, NULL);
    if (!libreta) {
        [self showAlert:@"Contactos no disponible"
                message:@"No se pudo acceder a la libreta de contactos."];
        return;
    }

    __weak typeof(self) weakSelf = self;
    ABAddressBookRequestAccessWithCompletion(libreta, ^(bool granted, CFErrorRef error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!granted) {
                [strongSelf showAlert:@"Sin permiso"
                              message:@"Permite el acceso a Contactos en Ajustes › IScan."];
                return;
            }
            [strongSelf presentNewPerson];
        });
    });
}

- (void)presentNewPerson {
    ABRecordRef persona = ABPersonCreate();

    NSString *nombre = self.result.info[@"fn"];
    if (nombre.length) {
        ABRecordSetValue(persona, kABPersonFirstNameProperty,
                         (__bridge CFStringRef)nombre, NULL);
    }
    NSString *organizacion = self.result.info[@"org"];
    if (organizacion.length) {
        ABRecordSetValue(persona, kABPersonOrganizationProperty,
                         (__bridge CFStringRef)organizacion, NULL);
    }
    NSString *puesto = self.result.info[@"title"];
    if (puesto.length) {
        ABRecordSetValue(persona, kABPersonJobTitleProperty,
                         (__bridge CFStringRef)puesto, NULL);
    }
    NSString *nota = self.result.info[@"note"];
    if (nota.length) {
        ABRecordSetValue(persona, kABPersonNoteProperty,
                         (__bridge CFStringRef)nota, NULL);
    }
    NSString *web = self.result.info[@"url"];
    if (web.length) {
        ABMutableMultiValueRef webs = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(webs, (__bridge CFStringRef)web,
                                     kABPersonHomePageLabel, NULL);
        ABRecordSetValue(persona, kABPersonURLProperty, webs, NULL);
        CFRelease(webs);
    }

    NSArray *telefonos = self.result.info[@"tel"];
    if (telefonos.count) {
        ABMutableMultiValueRef multi = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        for (NSString *telefono in telefonos) {
            ABMultiValueAddValueAndLabel(multi, (__bridge CFStringRef)telefono,
                                         kABPersonPhoneMobileLabel, NULL);
        }
        ABRecordSetValue(persona, kABPersonPhoneProperty, multi, NULL);
        CFRelease(multi);
    }

    NSArray *correos = self.result.info[@"email"];
    if (correos.count) {
        ABMutableMultiValueRef multi = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        for (NSString *correo in correos) {
            ABMultiValueAddValueAndLabel(multi, (__bridge CFStringRef)correo,
                                         kABWorkLabel, NULL);
        }
        ABRecordSetValue(persona, kABPersonEmailProperty, multi, NULL);
        CFRelease(multi);
    }

    ABNewPersonViewController *nuevo = [[ABNewPersonViewController alloc] init];
    nuevo.displayedPerson = persona;
    nuevo.newPersonViewDelegate = self;

    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:nuevo];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];

    CFRelease(persona);
}

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController
       didCompleteWithNewPerson:(ABRecordRef)person {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// --- Calendario ------------------------------------------------------------

- (void)addEvent {
    self.eventStore = [[EKEventStore alloc] init];
    EKEventStore *store = self.eventStore;

    __weak typeof(self) weakSelf = self;
    [store requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            if (!granted) {
                [strongSelf showAlert:@"Sin permiso"
                              message:@"Permite el acceso a Calendario en Ajustes › IScan."];
                return;
            }
            [strongSelf saveEventInStore:store];
        });
    }];
}

- (void)saveEventInStore:(EKEventStore *)store {
    NSDate *inicio = self.result.info[@"start"];
    NSDate *fin = self.result.info[@"end"];

    if (!inicio) {
        [self showAlert:@"Falta la fecha" message:@"Este evento no incluye una fecha de inicio."];
        return;
    }
    if (!fin || [fin timeIntervalSinceDate:inicio] <= 0) {
        fin = [inicio dateByAddingTimeInterval:3600.0];
    }

    EKCalendar *calendario = [store defaultCalendarForNewEvents];
    if (!calendario) {
        [self showAlert:@"Sin calendario"
                message:@"No hay ningún calendario donde guardar el evento."];
        return;
    }

    EKEvent *evento = [EKEvent eventWithEventStore:store];
    evento.title = self.result.info[@"summary"] ?: @"Evento";
    evento.startDate = inicio;
    evento.endDate = fin;
    evento.allDay = [self.result.info[@"allDay"] boolValue];
    evento.location = self.result.info[@"location"];
    evento.notes = self.result.info[@"notes"];
    evento.calendar = calendario;

    NSError *error = nil;
    BOOL guardado = [store saveEvent:evento span:EKSpanThisEvent commit:YES error:&error];
    if (guardado) {
        [SCTheme toast:@"Evento añadido al calendario" inView:self.view];
    } else {
        [self showAlert:@"No se pudo guardar" message:error.localizedDescription ?: @""];
    }
}

// ---------------------------------------------------------------------------

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

- (void)close {
    void (^callback)(void) = self.onClose;
    UIViewController *presentador = self.navigationController ?: self;
    [presentador dismissViewControllerAnimated:YES completion:^{
        if (callback) { callback(); }
    }];
}

@end
