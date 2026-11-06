#import "SCQRResult.h"
#import "SCQRParser.h"

@implementation SCQRField

+ (instancetype)fieldWithLabel:(NSString *)label value:(NSString *)value {
    SCQRField *field = [[SCQRField alloc] init];
    field.label = label ?: @"";
    field.value = value ?: @"";
    return field;
}

+ (instancetype)secretFieldWithLabel:(NSString *)label value:(NSString *)value {
    SCQRField *field = [self fieldWithLabel:label value:value];
    field.secret = YES;
    return field;
}

+ (instancetype)monoFieldWithLabel:(NSString *)label value:(NSString *)value {
    SCQRField *field = [self fieldWithLabel:label value:value];
    field.mono = YES;
    return field;
}

@end

@implementation SCQRResult

+ (NSString *)displayNameForKind:(SCQRKind)kind {
    switch (kind) {
        case SCQRKindURL: return @"Enlace web";
        case SCQRKindWiFi: return @"Red WiFi";
        case SCQRKindContact: return @"Contacto";
        case SCQRKindEvent: return @"Evento";
        case SCQRKindEmail: return @"Correo";
        case SCQRKindPhone: return @"Teléfono";
        case SCQRKindSMS: return @"Mensaje";
        case SCQRKindLocation: return @"Ubicación";
        case SCQRKindOTP: return @"Código 2FA";
        case SCQRKindText:
        default: return @"Texto";
    }
}

+ (NSString *)identifierForKind:(SCQRKind)kind {
    switch (kind) {
        case SCQRKindURL: return @"url";
        case SCQRKindWiFi: return @"wifi";
        case SCQRKindContact: return @"contact";
        case SCQRKindEvent: return @"event";
        case SCQRKindEmail: return @"email";
        case SCQRKindPhone: return @"phone";
        case SCQRKindSMS: return @"sms";
        case SCQRKindLocation: return @"location";
        case SCQRKindOTP: return @"otp";
        case SCQRKindText:
        default: return @"text";
    }
}

+ (SCQRKind)kindForIdentifier:(NSString *)identifier {
    static NSDictionary *mapa = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mapa = @{
            @"url": @(SCQRKindURL),
            @"wifi": @(SCQRKindWiFi),
            @"contact": @(SCQRKindContact),
            @"event": @(SCQRKindEvent),
            @"email": @(SCQRKindEmail),
            @"phone": @(SCQRKindPhone),
            @"sms": @(SCQRKindSMS),
            @"location": @(SCQRKindLocation),
            @"otp": @(SCQRKindOTP),
            @"text": @(SCQRKindText)
        };
    });
    NSNumber *numero = mapa[identifier ?: @""];
    return numero ? (SCQRKind)numero.integerValue : SCQRKindText;
}

- (instancetype)copyWithDate:(NSDate *)date {
    SCQRResult *copia = [SCQRParser parse:self.raw];
    copia.date = date ?: self.date;
    return copia;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"kind": [[self class] identifierForKind:self.kind],
        @"raw": self.raw ?: @"",
        @"date": @([self.date timeIntervalSince1970])
    };
}

+ (instancetype)resultWithDictionary:(NSDictionary *)dictionary {
    NSString *raw = dictionary[@"raw"];
    if (![raw isKindOfClass:[NSString class]] || raw.length == 0) { return nil; }

    SCQRResult *result = [SCQRParser parse:raw];
    NSNumber *stamp = dictionary[@"date"];
    if ([stamp isKindOfClass:[NSNumber class]]) {
        result.date = [NSDate dateWithTimeIntervalSince1970:stamp.doubleValue];
    }
    return result;
}

@end
