#import <Foundation/Foundation.h>

void GPSQLog(NSString *message) {
    NSLog(@"[gpsq] %@", message ?: @"");
}
