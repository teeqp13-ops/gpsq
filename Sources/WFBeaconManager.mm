//
//  WFBeaconManager.mm
//  Wolf GPS — إدارة البلوتوث والـ Beacons
//

#import "WFBeaconManager.h"

@implementation WFBeaconManager {
    CBCentralManager *centralManager;
    NSMutableArray *discoveredBeacons;
    BOOL isScanning;
}

+ (instancetype)shared {
    static WFBeaconManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[self alloc] init];
        [inst setup];
    });
    return inst;
}

- (void)setup {
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    discoveredBeacons = [NSMutableArray array];
    isScanning = NO;
}

- (void)startScanning {
    if (centralManager.state != CBManagerStatePoweredOn) return;
    isScanning = YES;
    [discoveredBeacons removeAllObjects];
    [centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
}

- (void)stopScanning {
    isScanning = NO;
    [centralManager stopScan];
}

- (NSArray *)getDiscoveredBeacons {
    return [discoveredBeacons copy];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn && isScanning) {
        [self startScanning];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *beaconID = peripheral.identifier.UUIDString;
    NSDictionary *beaconInfo = @{
        @"id": beaconID,
        @"rssi": RSSI,
        @"name": peripheral.name ?: @"جهاز غير معروف",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };

    BOOL found = NO;
    for (NSInteger i = 0; i < discoveredBeacons.count; i++) {
        if ([discoveredBeacons[i][@"id"] isEqualToString:beaconID]) {
            [discoveredBeacons replaceObjectAtIndex:i withObject:beaconInfo];
            found = YES;
            break;
        }
    }

    if (!found) {
        [discoveredBeacons addObject:beaconInfo];
    }
}

@end
