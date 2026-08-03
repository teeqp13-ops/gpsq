//
//  WFGPSManager.mm
//  Wolf GPS
//

#import "WFGPSManager.h"
#import <AVFoundation/AVFoundation.h>

@implementation WFGPSManager

+ (instancetype)shared {
    static WFGPSManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[WFGPSManager alloc] init];
    });
    return shared;
}

- (void)initializeTweak {
    // مراقبة أزرار الصوت
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(volumeChanged:) 
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification" 
                                               object:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        
        if (keyWindow) {
            WFGPSFloatingButton *btn = [WFGPSFloatingButton sharedButton];
            [btn addTarget:self action:@selector(floatingButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:btn];
        }
    });
}

- (void)volumeChanged:(NSNotification *)notification {
    // إظهار/إخفاء الأداة عند تغيير الصوت
    [WFGPSPanel togglePanel];
}

- (void)floatingButtonTapped {
    [WFGPSPanel togglePanel];
}

@end
