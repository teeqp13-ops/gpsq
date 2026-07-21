#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static CFStringRef const FGSharedDomain = CFSTR("fun.p3nd.fakegps");

static void FGSharedSet(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             FGSharedDomain);
    CFPreferencesAppSynchronize(FGSharedDomain);
}

static void FGStoreCoordinateText(NSString *text) {
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@","];
    if (parts.count != 2) return;
    double lat = [parts[0] doubleValue];
    double lon = [parts[1] doubleValue];
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return;
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
        FGStoreCoordinateText(weakSelf.coordinateLabel.text ?: @"");
    });
}
%end

%ctor {
    if (!CFPreferencesCopyAppValue(CFSTR("latitude"), FGSharedDomain)) {
        FGSharedSet(@"latitude", @(24.7136));
        FGSharedSet(@"longitude", @(46.6753));
        FGSharedSet(@"enabled", @NO);
    }
}
