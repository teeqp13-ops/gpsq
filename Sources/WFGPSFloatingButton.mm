//
//  WFGPSFloatingButton.mm
//  Wolf GPS
//

#import "WFGPSFloatingButton.h"

@implementation WFGPSFloatingButton

static NSString * const WFFloatingXKey = @"wolfox_floating_x";
static NSString * const WFFloatingYKey = @"wolfox_floating_y";

+ (instancetype)sharedButton {
    static WFGPSFloatingButton *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [WFGPSFloatingButton buttonWithType:UIButtonTypeCustom];
        [shared setupUI];
    });
    return shared;
}

- (void)setupUI {
    CGFloat x = [NSUserDefaults.standardUserDefaults doubleForKey:WFFloatingXKey] ?: 20;
    CGFloat y = [NSUserDefaults.standardUserDefaults doubleForKey:WFFloatingYKey] ?: 100;
    self.frame = CGRectMake(x, y, 56, 56);
    self.layer.cornerRadius = 28;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowOpacity = 0.4;
    self.layer.shadowRadius = 3;
    
    [self setTitle:@"GPS" forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    
    [self updateState:NO];
    
    // إضافة إمكانية السحب (Dragging)
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)updateState:(BOOL)active {
    self.isActive = active;
    // اللون الأخضر الفاتح المميز في الصور
    self.backgroundColor = active ? [UIColor colorWithRed:0.20 green:0.78 blue:0.35 alpha:1.0] : [UIColor colorWithWhite:0.4 alpha:1.0];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:self.superview];
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGRect bounds = self.superview.bounds;
        CGFloat half = CGRectGetMidX(bounds);
        CGFloat targetX = self.center.x < half ? 12 + CGRectGetWidth(self.bounds)/2.0 : CGRectGetWidth(bounds) - 12 - CGRectGetWidth(self.bounds)/2.0;
        CGFloat minY = self.safeAreaInsets.top + CGRectGetHeight(self.bounds)/2.0 + 8;
        CGFloat maxY = CGRectGetHeight(bounds) - self.safeAreaInsets.bottom - CGRectGetHeight(self.bounds)/2.0 - 8;
        CGFloat targetY = MIN(MAX(self.center.y, minY), maxY);
        [UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{ self.center = CGPointMake(targetX, targetY); } completion:^(BOOL finished) {
            [NSUserDefaults.standardUserDefaults setDouble:self.frame.origin.x forKey:WFFloatingXKey];
            [NSUserDefaults.standardUserDefaults setDouble:self.frame.origin.y forKey:WFFloatingYKey];
        }];
    }
}

@end
