#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <math.h>

static CFStringRef const FGSharedDomain = CFSTR("fun.p3nd.fakegps");

static void FGSharedSet(NSString *key, id value) {
    if (key.length == 0) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             FGSharedDomain);
    CFPreferencesAppSynchronize(FGSharedDomain);
}

static id FGSharedCopy(NSString *key) {
    if (key.length == 0) return nil;
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, FGSharedDomain));
}

static void FGStoreCoordinateText(NSString *text) {
    if (![text isKindOfClass:NSString.class]) return;
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@","];
    if (parts.count != 2) return;

    NSString *latText = [parts[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *lonText = [parts[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    double lat = latText.doubleValue;
    double lon = lonText.doubleValue;
    if (!isfinite(lat) || !isfinite(lon)) return;
    if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) return;

    FGSharedSet(@"latitude", @(lat));
    FGSharedSet(@"longitude", @(lon));
}

@interface FGManager : NSObject
@property(nonatomic,strong) UILabel *coordinateLabel;
- (void)toggleGPS:(UIButton *)sender;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
@end

%hook FGManager

- (void)toggleGPS:(UIButton *)sender {
    %orig;
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"FGEnabled"];
    FGSharedSet(@"enabled", @(enabled));
    FGStoreCoordinateText(self.coordinateLabel.text ?: @"");
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    %orig;
    __weak FGManager *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FGManager *strongSelf = weakSelf;
        if (!strongSelf) return;
        FGStoreCoordinateText(strongSelf.coordinateLabel.text ?: @"");
    });
}

%end

%ctor {
    @autoreleasepool {
        id latitude = FGSharedCopy(@"latitude");
        id longitude = FGSharedCopy(@"longitude");
        id enabled = FGSharedCopy(@"enabled");

        if (![latitude respondsToSelector:@selector(doubleValue)]) FGSharedSet(@"latitude", @(24.7136));
        if (![longitude respondsToSelector:@selector(doubleValue)]) FGSharedSet(@"longitude", @(46.6753));
        if (![enabled respondsToSelector:@selector(boolValue)]) FGSharedSet(@"enabled", @NO);
    }
}
