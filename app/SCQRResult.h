#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCQRKind) {
    SCQRKindText = 0,
    SCQRKindURL,
    SCQRKindWiFi,
    SCQRKindContact,
    SCQRKindEvent,
    SCQRKindEmail,
    SCQRKindPhone,
    SCQRKindSMS,
    SCQRKindLocation,
    SCQRKindOTP
};

// Un campo de la ficha: etiqueta + valor (+ opciones de presentacion).
@interface SCQRField : NSObject

@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, assign) BOOL secret;
@property (nonatomic, assign) BOOL mono;

+ (instancetype)fieldWithLabel:(NSString *)label value:(NSString *)value;
+ (instancetype)secretFieldWithLabel:(NSString *)label value:(NSString *)value;
+ (instancetype)monoFieldWithLabel:(NSString *)label value:(NSString *)value;

@end

// Resultado ya interpretado de un codigo QR.
@interface SCQRResult : NSObject

@property (nonatomic, assign) SCQRKind kind;
@property (nonatomic, copy) NSString *raw;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) NSArray *fields;          // SCQRField
@property (nonatomic, strong) NSMutableDictionary *info;
@property (nonatomic, copy) NSString *action;           // URL lista para abrir
@property (nonatomic, strong) NSDate *date;

+ (NSString *)displayNameForKind:(SCQRKind)kind;
+ (NSString *)identifierForKind:(SCQRKind)kind;
+ (SCQRKind)kindForIdentifier:(NSString *)identifier;

// Persistencia: solo se guarda lo imprescindible y se vuelve a interpretar.
- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)resultWithDictionary:(NSDictionary *)dictionary;
- (instancetype)copyWithDate:(NSDate *)date;

@end
