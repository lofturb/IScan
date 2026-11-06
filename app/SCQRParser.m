#import "SCQRParser.h"

// ---------------------------------------------------------------------------
// Utilidades de texto
// ---------------------------------------------------------------------------

static NSString *SCTrim(NSString *text) {
    return [text stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *SCUnquote(NSString *text) {
    if (text.length >= 2 && [text hasPrefix:@"\""] && [text hasSuffix:@"\""]) {
        return [text substringWithRange:NSMakeRange(1, text.length - 2)];
    }
    return text;
}

// Deshace los escapes del formato WIFI/MECARD: \; \, \: \\ \"
static NSString *SCUnescapeQR(NSString *text) {
    if ([text rangeOfString:@"\\"].location == NSNotFound) { return text; }
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\\' && i + 1 < text.length) {
            unichar next = [text characterAtIndex:i + 1];
            if (next == '\\' || next == ';' || next == ',' || next == ':' || next == '"') {
                [out appendFormat:@"%C", next];
                i++;
                continue;
            }
        }
        [out appendFormat:@"%C", c];
    }
    return out;
}

// Deshace los escapes de vCard: \n \, \; \\
static NSString *SCUnescapeVCard(NSString *text) {
    if ([text rangeOfString:@"\\"].location == NSNotFound) { return text; }
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\\' && i + 1 < text.length) {
            unichar next = [text characterAtIndex:i + 1];
            if (next == 'n' || next == 'N') {
                [out appendString:@"\n"];
                i++;
                continue;
            }
            if (next == '\\' || next == ';' || next == ',' || next == ':') {
                [out appendFormat:@"%C", next];
                i++;
                continue;
            }
        }
        [out appendFormat:@"%C", c];
    }
    return out;
}

static NSUInteger SCIndexOfUnescaped(NSString *text, unichar buscado) {
    BOOL escape = NO;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (escape) { escape = NO; continue; }
        if (c == '\\') { escape = YES; continue; }
        if (c == buscado) { return i; }
    }
    return NSNotFound;
}

// Parte por ';' sin romper los ';' escapados (conserva las barras).
static NSArray *SCSplitEscaped(NSString *body) {
    NSMutableArray *parts = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    BOOL escape = NO;
    for (NSUInteger i = 0; i < body.length; i++) {
        unichar c = [body characterAtIndex:i];
        if (escape) {
            [current appendFormat:@"\\%C", c];
            escape = NO;
        } else if (c == '\\') {
            escape = YES;
        } else if (c == ';') {
            [parts addObject:[current copy]];
            current = [NSMutableString string];
        } else {
            [current appendFormat:@"%C", c];
        }
    }
    if (escape) { [current appendString:@"\\"]; }
    [parts addObject:[current copy]];
    return parts;
}

// "T:WPA;S:Red;P:clave;;" -> { T: WPA, S: Red, P: clave }
static NSDictionary *SCParseKeyValues(NSString *body) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *part in SCSplitEscaped(body)) {
        if (part.length == 0) { continue; }
        NSUInteger index = SCIndexOfUnescaped(part, ':');
        if (index == NSNotFound) { continue; }
        NSString *key = SCTrim([part substringToIndex:index]);
        NSString *value = SCUnescapeQR([part substringFromIndex:index + 1]);
        key = [key uppercaseString];
        if (key.length == 0) { continue; }
        dict[key] = SCUnquote(SCTrim(value));
    }
    return dict;
}

static NSString *SCJoined(NSArray *values, NSString *separator) {
    NSMutableArray *clean = [NSMutableArray array];
    for (NSString *value in values) {
        NSString *text = SCTrim(value);
        if (text.length) { [clean addObject:text]; }
    }
    return [clean componentsJoinedByString:separator ?: @" "];
}

static NSString *SCEscapeQuery(NSString *text) {
    // URLQueryAllowedCharacterSet deja pasar & y =, que romperian los
    // parametros de mailto/sms. Codificamos de verdad los valores.
    static NSMutableCharacterSet *permitidos = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        permitidos = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
        [permitidos addCharactersInString:@"-._~"];
    });
    return [text stringByAddingPercentEncodingWithAllowedCharacters:permitidos] ?: text;
}

// ---------------------------------------------------------------------------
// Fechas de iCalendar
// ---------------------------------------------------------------------------

static NSDate *SCDateFromICS(NSString *value) {
    NSString *text = SCTrim(value);
    if (text.length == 0) { return nil; }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

    if ([text hasSuffix:@"Z"]) {
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        formatter.dateFormat = @"yyyyMMdd'T'HHmmss'Z'";
        NSDate *date = [formatter dateFromString:text];
        if (date) { return date; }
    } else {
        formatter.timeZone = [NSTimeZone localTimeZone];
        for (NSString *format in @[ @"yyyyMMdd'T'HHmmss", @"yyyyMMdd'T'HHmm" ]) {
            formatter.dateFormat = format;
            NSDate *date = [formatter dateFromString:text];
            if (date) { return date; }
        }
    }

    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"yyyyMMdd";
    return [formatter dateFromString:text];
}

static NSString *SCFormatDate(NSDate *date, BOOL allDay) {
    if (!date) { return @""; }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = allDay ? NSDateFormatterNoStyle : NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

@implementation SCQRParser

+ (SCQRResult *)parse:(NSString *)text {
    NSString *raw = text ?: @"";
    NSString *trimmed = SCTrim(raw);
    NSString *upper = [trimmed uppercaseString];

    SCQRResult *result = [[SCQRResult alloc] init];
    result.raw = raw;
    result.date = [NSDate date];
    result.info = [NSMutableDictionary dictionary];

    if (upper.length == 0) {
        result.kind = SCQRKindText;
        result.title = @"Vacío";
        result.fields = @[];
        return result;
    }

    if ([upper hasPrefix:@"WIFI:"]) {
        [self fillWiFi:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"BEGIN:VCARD"]) {
        [self fillContact:result fromVCard:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"MECARD:"]) {
        [self fillContact:result fromMECard:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"BEGIN:VEVENT"] || [upper hasPrefix:@"BEGIN:VCALENDAR"]) {
        [self fillEvent:result fromCalendar:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"MATMSG:"]) {
        [self fillMailMessage:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"OTPAUTH://"]) {
        [self fillOTP:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"MAILTO:"]) {
        [self fillMailURL:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"TEL:"]) {
        [self fillPhone:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"SMSTO:"]) {
        [self fillSMS:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"SMS:"]) {
        [self fillSMS:result payload:trimmed];
        return result;
    }
    if ([upper hasPrefix:@"GEO:"]) {
        [self fillLocation:result payload:trimmed];
        return result;
    }

    // URL con esquema explicito, o dominio escrito a mano.
    NSURL *url = [NSURL URLWithString:trimmed];
    NSString *scheme = [url scheme].lowercaseString;
    NSArray *esquemas = @[ @"http", @"https", @"ftp", @"ftps", @"itms",
                           @"itms-apps", @"maps", @"youtube", @"fb",
                           @"twitter", @"instagram", @"spotify" ];
    BOOL tieneEsquemaConocido = scheme.length > 0 && [esquemas containsObject:scheme];
    if (scheme.length && (tieneEsquemaConocido ||
                          [trimmed rangeOfString:@"://"].location != NSNotFound)) {
        [self fillURL:result url:url];
        return result;
    }
    if ([upper hasPrefix:@"WWW."]) {
        [self fillURL:result url:[NSURL URLWithString:[@"http://" stringByAppendingString:trimmed]]];
        return result;
    }

    [self fillText:result];
    return result;
}

// --- Texto -----------------------------------------------------------------

+ (void)fillText:(SCQRResult *)result {
    result.kind = SCQRKindText;
    NSString *plano = [result.raw stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    NSString *unaLinea = [[plano componentsSeparatedByString:@"\n"] firstObject] ?: plano;
    if (unaLinea.length > 90) {
        unaLinea = [[unaLinea substringToIndex:90] stringByAppendingString:@"…"];
    }
    result.title = SCTrim(unaLinea);
    if (result.title.length == 0) { result.title = @"Texto"; }
    result.subtitle = @"Texto";
    result.fields = @[ [SCQRField monoFieldWithLabel:@"Contenido" value:plano] ];
    result.action = nil;
}

// --- WiFi ------------------------------------------------------------------

+ (NSDictionary *)parseWiFiPayload:(NSString *)payload {
    NSString *body = payload ?: @"";
    NSRange colon = [body rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        body = [body substringFromIndex:colon.location + 1];
    }
    NSDictionary *values = SCParseKeyValues(body);

    NSString *ssid = values[@"S"] ?: @"";
    NSString *password = values[@"P"] ?: @"";
    NSString *security = values[@"T"] ?: @"";
    NSString *hidden = values[@"H"] ?: @"";
    BOOL oculta = [hidden boolValue] || [hidden.lowercaseString isEqualToString:@"true"];

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"ssid"] = ssid;
    info[@"password"] = password;
    info[@"security"] = security;
    info[@"hidden"] = @(oculta);
    if (values[@"I"]) { info[@"identity"] = values[@"I"]; }
    if (values[@"A"]) { info[@"anonymous"] = values[@"A"]; }
    if (values[@"E"]) { info[@"eap"] = values[@"E"]; }
    return info;
}

+ (void)fillWiFi:(SCQRResult *)result payload:(NSString *)payload {
    NSDictionary *info = [self parseWiFiPayload:payload];
    NSString *ssid = info[@"ssid"] ?: @"";
    NSString *password = info[@"password"] ?: @"";
    NSString *security = info[@"security"] ?: @"";
    BOOL oculta = [info[@"hidden"] boolValue];

    NSString *seguridad = @"WPA/WPA2";
    if (security.length == 0) {
        seguridad = password.length ? @"WPA/WPA2" : @"Abierta";
    } else if ([security.lowercaseString isEqualToString:@"nopass"]) {
        seguridad = @"Abierta (sin contraseña)";
    } else if ([security.lowercaseString isEqualToString:@"wep"]) {
        seguridad = @"WEP";
    } else if ([security.lowercaseString rangeOfString:@"eap"].location != NSNotFound) {
        seguridad = @"WPA2-Enterprise";
    } else if ([security.lowercaseString isEqualToString:@"sae"]) {
        seguridad = @"WPA3 (SAE)";
    } else {
        seguridad = security.uppercaseString;
    }

    result.kind = SCQRKindWiFi;
    result.title = ssid.length ? ssid : @"Red sin nombre";
    result.subtitle = @"Red WiFi";

    NSMutableArray *fields = [NSMutableArray array];
    [fields addObject:[SCQRField fieldWithLabel:@"Red" value:result.title]];
    [fields addObject:[SCQRField fieldWithLabel:@"Seguridad" value:seguridad]];
    if (password.length) {
        [fields addObject:[SCQRField secretFieldWithLabel:@"Contraseña" value:password]];
    }
    if (oculta) {
        [fields addObject:[SCQRField fieldWithLabel:@"Visibilidad" value:@"Red oculta"]];
    }
    if (info[@"identity"]) {
        [fields addObject:[SCQRField fieldWithLabel:@"Identidad" value:info[@"identity"]]];
    }
    result.fields = fields;

    result.info[@"ssid"] = ssid;
    result.info[@"password"] = password;
    result.info[@"security"] = security;
    result.info[@"hidden"] = @(oculta);
    result.action = nil;
}

// --- vCard y MECARD --------------------------------------------------------

+ (void)fillContact:(SCQRResult *)result fromVCard:(NSString *)raw {
    NSArray *lineas = [raw componentsSeparatedByCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]];
    NSMutableArray *unidas = [NSMutableArray array];
    for (NSString *linea in lineas) {
        NSString *limpia = [linea stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        if (( [limpia hasPrefix:@" "] || [limpia hasPrefix:@"\t"] ) && unidas.count > 0) {
            NSString *anterior = [unidas lastObject];
            unidas[unidas.count - 1] = [anterior stringByAppendingString:
                                        [limpia substringFromIndex:1]];
        } else {
            [unidas addObject:limpia];
        }
    }

    NSString *fn = nil, *org = nil, *puesto = nil, *web = nil, *nota = nil, *direccion = nil;
    NSMutableArray *tels = [NSMutableArray array];
    NSMutableArray *mails = [NSMutableArray array];

    for (NSString *linea in unidas) {
        if (linea.length == 0) { continue; }
        NSString *upper = linea.uppercaseString;
        if ([upper hasPrefix:@"BEGIN:"] || [upper hasPrefix:@"END:"] ||
            [upper hasPrefix:@"VERSION"]) {
            continue;
        }
        NSUInteger corte = [linea rangeOfString:@":"].location;
        if (corte == NSNotFound) { continue; }

        NSString *cabecera = [linea substringToIndex:corte];
        NSString *valor = SCUnescapeVCard([linea substringFromIndex:corte + 1]);
        NSString *clave = [cabecera componentsSeparatedByString:@";"].firstObject ?: @"";
        if ([clave rangeOfString:@"."].location != NSNotFound) {
            clave = [clave componentsSeparatedByString:@"."].lastObject;
        }
        clave = clave.uppercaseString;

        if ([clave isEqualToString:@"FN"]) {
            fn = SCTrim(valor);
        } else if ([clave isEqualToString:@"N"] && fn.length == 0) {
            NSArray *partes = [valor componentsSeparatedByString:@";"];
            NSMutableArray *nombre = [NSMutableArray array];
            for (NSString *parte in partes) {
                if (SCTrim(parte).length) { [nombre addObject:SCTrim(parte)]; }
            }
            if (nombre.count >= 2) {
                fn = [NSString stringWithFormat:@"%@ %@", nombre[1], nombre[0]];
            } else if (nombre.count == 1) {
                fn = nombre[0];
            }
        } else if ([clave isEqualToString:@"ORG"]) {
            org = SCJoined([valor componentsSeparatedByString:@";"], @" · ");
        } else if ([clave isEqualToString:@"TITLE"]) {
            puesto = SCTrim(valor);
        } else if ([clave isEqualToString:@"TEL"]) {
            if (SCTrim(valor).length) { [tels addObject:SCTrim(valor)]; }
        } else if ([clave isEqualToString:@"EMAIL"]) {
            if (SCTrim(valor).length) { [mails addObject:SCTrim(valor)]; }
        } else if ([clave isEqualToString:@"URL"]) {
            web = SCTrim(valor);
        } else if ([clave isEqualToString:@"NOTE"]) {
            nota = SCTrim(valor);
        } else if ([clave isEqualToString:@"ADR"]) {
            direccion = SCJoined([valor componentsSeparatedByString:@";"], @", ");
        }
    }

    result.kind = SCQRKindContact;
    result.title = fn.length ? fn : (org.length ? org : @"Contacto");
    result.subtitle = @"Contacto";

    NSMutableArray *fields = [NSMutableArray array];
    if (org.length) { [fields addObject:[SCQRField fieldWithLabel:@"Organización" value:org]]; }
    if (puesto.length) { [fields addObject:[SCQRField fieldWithLabel:@"Puesto" value:puesto]]; }
    for (NSString *tel in tels) {
        [fields addObject:[SCQRField fieldWithLabel:@"Teléfono" value:tel]];
    }
    for (NSString *mail in mails) {
        [fields addObject:[SCQRField fieldWithLabel:@"Correo" value:mail]];
    }
    if (direccion.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Dirección" value:direccion]];
    }
    if (web.length) { [fields addObject:[SCQRField fieldWithLabel:@"Web" value:web]]; }
    if (nota.length) { [fields addObject:[SCQRField fieldWithLabel:@"Nota" value:nota]]; }
    result.fields = fields;

    result.info[@"fn"] = result.title;
    result.info[@"org"] = org ?: @"";
    result.info[@"title"] = puesto ?: @"";
    result.info[@"tel"] = tels;
    result.info[@"email"] = mails;
    result.info[@"adr"] = direccion ?: @"";
    result.info[@"url"] = web ?: @"";
    result.info[@"note"] = nota ?: @"";
}

+ (void)fillContact:(SCQRResult *)result fromMECard:(NSString *)raw {
    NSString *body = raw;
    NSRange colon = [body rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        body = [body substringFromIndex:colon.location + 1];
    }

    NSMutableArray *tels = [NSMutableArray array];
    NSMutableArray *mails = [NSMutableArray array];
    NSString *nombre = nil, *org = nil, *web = nil, *nota = nil, *direccion = nil;

    for (NSString *part in SCSplitEscaped(body)) {
        if (part.length == 0) { continue; }
        NSUInteger index = SCIndexOfUnescaped(part, ':');
        if (index == NSNotFound) { continue; }
        NSString *clave = [[part substringToIndex:index] uppercaseString];
        NSString *valor = SCUnquote(SCUnescapeQR([part substringFromIndex:index + 1]));
        if ([clave isEqualToString:@"N"]) {
            NSArray *partes = [valor componentsSeparatedByString:@","];
            if (partes.count >= 2) {
                nombre = [NSString stringWithFormat:@"%@ %@",
                          SCTrim(partes[1]), SCTrim(partes[0])];
            } else {
                nombre = SCTrim(valor);
            }
        } else if ([clave isEqualToString:@"TEL"]) {
            if (SCTrim(valor).length) { [tels addObject:SCTrim(valor)]; }
        } else if ([clave isEqualToString:@"EMAIL"]) {
            if (SCTrim(valor).length) { [mails addObject:SCTrim(valor)]; }
        } else if ([clave isEqualToString:@"ORG"]) {
            org = SCTrim(valor);
        } else if ([clave isEqualToString:@"ADR"]) {
            direccion = SCTrim(valor);
        } else if ([clave isEqualToString:@"URL"]) {
            web = SCTrim(valor);
        } else if ([clave isEqualToString:@"NOTE"]) {
            nota = SCTrim(valor);
        }
    }

    result.kind = SCQRKindContact;
    result.title = nombre.length ? nombre : (org.length ? org : @"Contacto");
    result.subtitle = @"Contacto";

    NSMutableArray *fields = [NSMutableArray array];
    if (org.length) { [fields addObject:[SCQRField fieldWithLabel:@"Organización" value:org]]; }
    for (NSString *tel in tels) {
        [fields addObject:[SCQRField fieldWithLabel:@"Teléfono" value:tel]];
    }
    for (NSString *mail in mails) {
        [fields addObject:[SCQRField fieldWithLabel:@"Correo" value:mail]];
    }
    if (direccion.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Dirección" value:direccion]];
    }
    if (web.length) { [fields addObject:[SCQRField fieldWithLabel:@"Web" value:web]]; }
    if (nota.length) { [fields addObject:[SCQRField fieldWithLabel:@"Nota" value:nota]]; }
    result.fields = fields;

    result.info[@"fn"] = result.title;
    result.info[@"org"] = org ?: @"";
    result.info[@"title"] = @"";
    result.info[@"tel"] = tels;
    result.info[@"email"] = mails;
    result.info[@"adr"] = direccion ?: @"";
    result.info[@"url"] = web ?: @"";
    result.info[@"note"] = nota ?: @"";
}

// --- iCalendar -------------------------------------------------------------

+ (void)fillEvent:(SCQRResult *)result fromCalendar:(NSString *)raw {
    NSArray *lineas = [raw componentsSeparatedByCharactersInSet:
                       [NSCharacterSet newlineCharacterSet]];

    NSString *summary = nil, *location = nil, *notes = nil, *web = nil;
    NSString *startText = nil, *endText = nil;
    BOOL allDay = NO;

    for (NSString *linea in lineas) {
        NSString *limpia = [linea stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        NSUInteger corte = [limpia rangeOfString:@":"].location;
        if (corte == NSNotFound) { continue; }
        NSString *cabecera = [limpia substringToIndex:corte];
        NSString *valor = [limpia substringFromIndex:corte + 1];
        NSString *clave = [[cabecera componentsSeparatedByString:@";"].firstObject
                           uppercaseString];

        if ([clave isEqualToString:@"DTSTART"]) {
            startText = SCTrim(valor);
            if ([cabecera.uppercaseString rangeOfString:@"VALUE=DATE"].location != NSNotFound) {
                allDay = YES;
            }
        } else if ([clave isEqualToString:@"DTEND"]) {
            endText = SCTrim(valor);
        } else if ([clave isEqualToString:@"SUMMARY"]) {
            summary = SCUnescapeVCard(valor);
        } else if ([clave isEqualToString:@"LOCATION"]) {
            location = SCUnescapeVCard(valor);
        } else if ([clave isEqualToString:@"DESCRIPTION"]) {
            notes = SCUnescapeVCard(valor);
        } else if ([clave isEqualToString:@"URL"]) {
            web = SCTrim(valor);
        }
    }

    NSDate *start = SCDateFromICS(startText);
    NSDate *end = SCDateFromICS(endText);

    result.kind = SCQRKindEvent;
    result.title = summary.length ? summary : @"Evento";
    result.subtitle = @"Evento";

    NSMutableArray *fields = [NSMutableArray array];
    if (start) {
        [fields addObject:[SCQRField fieldWithLabel:@"Inicio"
                                              value:SCFormatDate(start, allDay)]];
    }
    if (end) {
        [fields addObject:[SCQRField fieldWithLabel:@"Fin"
                                              value:SCFormatDate(end, allDay)]];
    }
    if (location.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Lugar" value:location]];
    }
    if (notes.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Descripción" value:notes]];
    }
    if (web.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Web" value:web]];
    }
    result.fields = fields;

    result.info[@"summary"] = result.title;
    result.info[@"location"] = location ?: @"";
    result.info[@"notes"] = notes ?: @"";
    result.info[@"allDay"] = @(allDay);
    if (start) { result.info[@"start"] = start; }
    if (end) { result.info[@"end"] = end; } else if (start) { result.info[@"end"] = start; }
    result.action = nil;
}

// --- Correo ----------------------------------------------------------------

+ (void)fillMailMessage:(SCQRResult *)result payload:(NSString *)payload {
    NSString *body = payload;
    NSRange colon = [body rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        body = [body substringFromIndex:colon.location + 1];
    }
    NSDictionary *values = SCParseKeyValues(body);
    NSString *to = values[@"TO"] ?: @"";
    NSString *subject = values[@"SUB"] ?: @"";
    NSString *message = values[@"BODY"] ?: @"";
    [self fillMailWithAddress:to subject:subject body:message result:result];
}

+ (void)fillMailURL:(SCQRResult *)result payload:(NSString *)payload {
    NSURL *url = [NSURL URLWithString:payload];
    NSString *address = [[payload substringFromIndex:7] componentsSeparatedByString:@"?"].firstObject ?: @"";
    address = [address stringByRemovingPercentEncoding] ?: address;

    NSString *subject = @"";
    NSString *body = @"";
    NSString *query = url.query;
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count < 2) { continue; }
        NSString *value = [[kv subarrayWithRange:NSMakeRange(1, kv.count - 1)]
                           componentsJoinedByString:@"="];
        value = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        value = [value stringByRemovingPercentEncoding] ?: value;
        if ([kv[0] isEqualToString:@"subject"]) { subject = value; }
        if ([kv[0] isEqualToString:@"body"]) { body = value; }
    }
    [self fillMailWithAddress:address subject:subject body:body result:result];
}

+ (void)fillMailWithAddress:(NSString *)address
                    subject:(NSString *)subject
                       body:(NSString *)body
                     result:(SCQRResult *)result {
    result.kind = SCQRKindEmail;
    result.title = address.length ? address : @"Correo";
    result.subtitle = @"Correo";

    NSMutableArray *fields = [NSMutableArray array];
    if (address.length) { [fields addObject:[SCQRField fieldWithLabel:@"Para" value:address]]; }
    if (subject.length) { [fields addObject:[SCQRField fieldWithLabel:@"Asunto" value:subject]]; }
    if (body.length) { [fields addObject:[SCQRField fieldWithLabel:@"Mensaje" value:body]]; }
    result.fields = fields;

    result.info[@"address"] = address ?: @"";
    result.info[@"subject"] = subject ?: @"";
    result.info[@"body"] = body ?: @"";

    NSString *action = [NSString stringWithFormat:@"mailto:%@", SCEscapeQuery(address ?: @"")];
    NSMutableArray *params = [NSMutableArray array];
    if (subject.length) {
        [params addObject:[@"subject=" stringByAppendingString:SCEscapeQuery(subject)]];
    }
    if (body.length) {
        [params addObject:[@"body=" stringByAppendingString:SCEscapeQuery(body)]];
    }
    if (params.count) {
        action = [action stringByAppendingFormat:@"?%@", [params componentsJoinedByString:@"&"]];
    }
    result.action = action;
}

// --- Teléfono y SMS --------------------------------------------------------

+ (void)fillPhone:(SCQRResult *)result payload:(NSString *)payload {
    NSString *number = [payload substringFromIndex:4];
    number = [number stringByRemovingPercentEncoding] ?: number;
    number = SCTrim(number);

    result.kind = SCQRKindPhone;
    result.title = number.length ? number : @"Teléfono";
    result.subtitle = @"Teléfono";
    result.fields = @[ [SCQRField fieldWithLabel:@"Número" value:number] ];
    result.info[@"number"] = number;
    result.action = [@"tel:" stringByAppendingString:
                     [number stringByAddingPercentEncodingWithAllowedCharacters:
                      [NSCharacterSet characterSetWithCharactersInString:@"+0123456789*#"]] ?: number];
}

+ (void)fillSMS:(SCQRResult *)result payload:(NSString *)payload {
    NSString *body = payload;
    NSUInteger start = 0;
    NSString *upper = payload.uppercaseString;
    if ([upper hasPrefix:@"SMSTO:"]) {
        start = 6;
    } else if ([upper hasPrefix:@"SMS:"]) {
        start = 4;
    }
    body = [payload substringFromIndex:MIN(start, payload.length)];

    NSString *number = body;
    NSString *message = @"";
    NSRange colon = [body rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        number = [body substringToIndex:colon.location];
        message = [body substringFromIndex:colon.location + 1];
    }
    number = SCTrim([number stringByRemovingPercentEncoding] ?: number);
    message = [message stringByRemovingPercentEncoding] ?: message;

    result.kind = SCQRKindSMS;
    result.title = number.length ? number : @"Mensaje";
    result.subtitle = @"Mensaje";

    NSMutableArray *fields = [NSMutableArray array];
    if (number.length) { [fields addObject:[SCQRField fieldWithLabel:@"Número" value:number]]; }
    if (message.length) { [fields addObject:[SCQRField fieldWithLabel:@"Texto" value:message]]; }
    result.fields = fields;
    result.info[@"number"] = number;
    result.info[@"body"] = message;

    NSString *action = [NSString stringWithFormat:@"sms:%@", number];
    if (message.length) {
        action = [action stringByAppendingFormat:@"?&body=%@", SCEscapeQuery(message)];
    }
    result.action = action;
}

// --- Ubicación -------------------------------------------------------------

+ (void)fillLocation:(SCQRResult *)result payload:(NSString *)payload {
    NSString *body = [payload substringFromIndex:4];
    NSString *coordinates = body;
    NSString *query = nil;

    NSRange question = [body rangeOfString:@"?"];
    if (question.location != NSNotFound) {
        coordinates = [body substringToIndex:question.location];
        NSString *params = [body substringFromIndex:question.location + 1];
        for (NSString *pair in [params componentsSeparatedByString:@"&"]) {
            if ([pair hasPrefix:@"q="]) {
                query = [[pair substringFromIndex:2] stringByRemovingPercentEncoding];
            }
        }
    }
    coordinates = [[coordinates componentsSeparatedByString:@";"].firstObject
                   stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    coordinates = [coordinates stringByRemovingPercentEncoding] ?: coordinates;

    result.kind = SCQRKindLocation;
    result.title = query.length ? query : coordinates;
    if (result.title.length == 0) { result.title = @"Ubicación"; }
    result.subtitle = @"Ubicación";

    NSMutableArray *fields = [NSMutableArray array];
    if (query.length) { [fields addObject:[SCQRField fieldWithLabel:@"Lugar" value:query]]; }
    if (coordinates.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Coordenadas" value:coordinates]];
    }
    result.fields = fields;
    result.info[@"coordinates"] = coordinates ?: @"";
    result.info[@"query"] = query ?: @"";

    NSString *action = nil;
    if (query.length) {
        action = [NSString stringWithFormat:@"http://maps.apple.com/?q=%@",
                  SCEscapeQuery(query)];
    } else if ([coordinates rangeOfString:@","].location != NSNotFound) {
        action = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%@",
                  SCEscapeQuery(coordinates)];
    }
    result.action = action;
}

// --- otpauth ---------------------------------------------------------------

+ (void)fillOTP:(SCQRResult *)result payload:(NSString *)payload {
    NSURLComponents *components = [NSURLComponents componentsWithString:payload];
    NSString *type = components.host ?: @"totp";
    NSString *label = [components.path stringByRemovingPercentEncoding] ?: components.path;
    if ([label hasPrefix:@"/"]) { label = [label substringFromIndex:1]; }

    NSString *issuer = nil, *account = label, *secret = nil;
    NSString *digits = @"6", *period = @"30", *algorithm = @"SHA1";

    for (NSURLQueryItem *item in components.queryItems) {
        NSString *name = item.name.lowercaseString;
        if ([name isEqualToString:@"secret"]) { secret = item.value; }
        else if ([name isEqualToString:@"issuer"]) { issuer = item.value; }
        else if ([name isEqualToString:@"digits"]) { digits = item.value; }
        else if ([name isEqualToString:@"period"]) { period = item.value; }
        else if ([name isEqualToString:@"algorithm"]) { algorithm = item.value; }
    }

    NSRange colon = [label rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        NSString *prefix = [label substringToIndex:colon.location];
        if (issuer.length == 0) { issuer = prefix; }
        account = [label substringFromIndex:colon.location + 1];
    }

    result.kind = SCQRKindOTP;
    result.title = issuer.length ? issuer : (account.length ? account : @"Código 2FA");
    result.subtitle = @"Código 2FA";

    NSMutableArray *fields = [NSMutableArray array];
    if (account.length) { [fields addObject:[SCQRField fieldWithLabel:@"Cuenta" value:account]]; }
    if (issuer.length) { [fields addObject:[SCQRField fieldWithLabel:@"Emisor" value:issuer]]; }
    [fields addObject:[SCQRField fieldWithLabel:@"Tipo" value:type.uppercaseString]];
    [fields addObject:[SCQRField fieldWithLabel:@"Dígitos" value:digits]];
    [fields addObject:[SCQRField fieldWithLabel:@"Periodo"
                                          value:[NSString stringWithFormat:@"%@ s", period]]];
    [fields addObject:[SCQRField fieldWithLabel:@"Algoritmo" value:algorithm.uppercaseString]];
    if (secret.length) {
        [fields addObject:[SCQRField secretFieldWithLabel:@"Secreto" value:secret]];
    }
    result.fields = fields;

    result.info[@"type"] = type ?: @"";
    result.info[@"issuer"] = issuer ?: @"";
    result.info[@"account"] = account ?: @"";
    result.info[@"secret"] = secret ?: @"";
    result.action = nil;
}

// --- URL -------------------------------------------------------------------

+ (void)fillURL:(SCQRResult *)result url:(NSURL *)url {
    result.kind = SCQRKindURL;
    NSString *host = url.host;
    result.title = host.length ? host : (url.absoluteString ?: @"Enlace");
    result.subtitle = @"Enlace web";

    NSMutableArray *fields = [NSMutableArray array];
    if (url.scheme.length) {
        [fields addObject:[SCQRField fieldWithLabel:@"Esquema"
                                              value:url.scheme.lowercaseString]];
    }
    [fields addObject:[SCQRField monoFieldWithLabel:@"Enlace"
                                              value:url.absoluteString ?: @""]];
    result.fields = fields;
    result.info[@"url"] = url.absoluteString ?: @"";
    result.action = url.absoluteString;
}

@end
