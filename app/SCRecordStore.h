#import <Foundation/Foundation.h>

@class SCQRResult;

// Historial de lecturas, guardado como JSON dentro de la caja de la app.
@interface SCRecordStore : NSObject

+ (instancetype)sharedStore;

@property (nonatomic, strong, readonly) NSArray *records;   // SCQRResult, reciente primero

- (void)add:(SCQRResult *)result;
- (void)clear;

@end
