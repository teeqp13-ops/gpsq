#import <UIKit/UIKit.h>

@interface YHTestButton : UIButton
@end
@implementation YHTestButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor redColor];
        self.layer.cornerRadius = frame.size.width / 2;
        [self setTitle:@"TEST" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:10];
        self.layer.zPosition = 9999;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}
@end

static void __attribute__((constructor)) init_test(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
                    break;
                }
            }
        }
        if (!window) window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [UIApplication sharedApplication].windows.firstObject;
        
        if (window) {
            YHTestButton *btn = [[YHTestButton alloc] initWithFrame:CGRectMake(100, 100, 60, 60)];
            [window addSubview:btn];
            [window bringSubviewToFront:btn];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Manus Test" message:@"Injection Success!" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}
