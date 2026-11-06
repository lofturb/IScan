#import "SCRecordStore.h"
#import "SCQRResult.h"

static const NSUInteger SCMaxRecords = 150;

@interface SCRecordStore ()
@property (nonatomic, strong) NSMutableArray *items;
@end

@implementation SCRecordStore

+ (instancetype)sharedStore {
    static SCRecordStore *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[SCRecordStore alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        [self load];
    }
    return self;
}

- (NSString *)path {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                        NSUserDomainMask, YES);
    NSString *base = dirs.firstObject ?: NSTemporaryDirectory();
    return [base stringByAppendingPathComponent:@"historial-iscan.json"];
}

- (void)load {
    NSData *data = [NSData dataWithContentsOfFile:[self path]];
    if (!data) { return; }

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:[NSArray class]]) { return; }

    for (NSDictionary *dict in (NSArray *)json) {
        if (![dict isKindOfClass:[NSDictionary class]]) { continue; }
        SCQRResult *result = [SCQRResult resultWithDictionary:dict];
        if (result) { [self.items addObject:result]; }
    }
}

- (void)save {
    NSMutableArray *serializados = [NSMutableArray array];
    for (SCQRResult *result in self.items) {
        [serializados addObject:[result dictionaryRepresentation]];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:serializados
                                                   options:0
                                                     error:NULL];
    if (data) {
        [data writeToFile:[self path] atomically:YES];
    }
}

- (NSArray *)records {
    return [self.items copy];
}

- (void)add:(SCQRResult *)result {
    if (!result.raw.length) { return; }

    // Si se vuelve a escanear lo mismo, se sube al principio en vez de duplicar.
    NSUInteger repetido = NSNotFound;
    for (NSUInteger i = 0; i < self.items.count; i++) {
        SCQRResult *existente = self.items[i];
        if ([existente.raw isEqualToString:result.raw]) {
            repetido = i;
            break;
        }
    }

    if (repetido != NSNotFound) {
        [self.items removeObjectAtIndex:repetido];
    }

    if (!result.date) { result.date = [NSDate date]; }
    [self.items insertObject:result atIndex:0];

    while (self.items.count > SCMaxRecords) {
        [self.items removeLastObject];
    }
    [self save];
}

- (void)clear {
    [self.items removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:[self path] error:NULL];
}

@end
