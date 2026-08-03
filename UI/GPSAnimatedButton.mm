#import "GPSAnimatedButton.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *GPSAnimatedColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static NSString *const GPSAnimatedPulseKey = @"gpsq.idlePulse";
static NSString *const GPSAnimatedRotationKey = @"gpsq.idleRotation";
static NSString *const GPSAnimatedTransitionKey = @"gpsq.activationTransition";

@interface GPSAnimatedButton ()
@property(nonatomic,assign) BOOL activatedState;
@property(nonatomic,assign) CGPoint dragStart;
@end

@implementation GPSAnimatedButton

- (instancetype)initWithActivated:(BOOL)activated {
    self = [super initWithFrame:CGRectMake(0, 0, 72, 72)];
    if (!self) return nil;
    self.activatedState = activated;
    self.backgroundColor = activated ? GPSAnimatedColor(34, 197, 94) : UIColor.blackColor;
    self.layer.cornerRadius = 36.0;
    self.layer.masksToBounds = NO;
    self.layer.shadowOffset = CGSizeMake(0, 8);
    self.layer.shadowOpacity = activated ? 0.55f : 0.30f;
    self.layer.shadowRadius = activated ? 18.0f : 12.0f;
    self.layer.shadowColor = (activated ? GPSAnimatedColor(74, 222, 128) : GPSAnimatedColor(148, 163, 184)).CGColor;
    [self setTitle:@"GPS" forState:UIControlStateNormal];
    [self setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.75;
    self.exclusiveTouch = YES;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.cancelsTouchesInView = NO;
    [self addGestureRecognizer:pan];
    [self startIdleAnimations];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2.0;
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self startIdleAnimations];
}

- (void)setActivatedState:(BOOL)activated animated:(BOOL)animated {
    self.activatedState = activated;
    UIColor *targetColor = activated ? GPSAnimatedColor(34, 197, 94) : UIColor.blackColor;
    CGColorRef targetShadowColor = (activated ? GPSAnimatedColor(74, 222, 128) : GPSAnimatedColor(148, 163, 184)).CGColor;
    CGFloat targetShadowOpacity = activated ? 0.55f : 0.30f;
    CGFloat targetShadowRadius = activated ? 20.0f : 12.0f;

    [self.layer removeAnimationForKey:GPSAnimatedPulseKey];
    [self.layer removeAnimationForKey:GPSAnimatedRotationKey];

    if (animated) {
        CAKeyframeAnimation *pulse = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pulse.values = @[@1.0, @1.12, @0.98, @1.0];
        pulse.keyTimes = @[@0.0, @0.35, @0.72, @1.0];

        CAKeyframeAnimation *rotation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotation.values = @[@0.0, @(-0.12), @(0.14), @0.0];
        rotation.keyTimes = @[@0.0, @0.35, @0.7, @1.0];

        CABasicAnimation *glow = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        glow.fromValue = @(self.layer.shadowOpacity);
        glow.toValue = @(targetShadowOpacity);

        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.animations = @[pulse, rotation, glow];
        group.duration = 0.8;
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.layer addAnimation:group forKey:GPSAnimatedTransitionKey];
    }

    [UIView animateWithDuration:(animated ? 0.8 : 0.0)
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.backgroundColor = targetColor;
        self.layer.shadowColor = targetShadowColor;
        self.layer.shadowOpacity = targetShadowOpacity;
        self.layer.shadowRadius = targetShadowRadius;
    } completion:^(__unused BOOL finished) {
        [self startIdleAnimations];
    }];
}

- (void)startIdleAnimations {
    if ([self.layer animationForKey:GPSAnimatedPulseKey] == nil) {
        CAKeyframeAnimation *pulse = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pulse.values = @[@1.0, @1.04, @1.0];
        pulse.keyTimes = @[@0.0, @0.5, @1.0];
        pulse.duration = 2.1;
        pulse.repeatCount = HUGE_VALF;
        pulse.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [self.layer addAnimation:pulse forKey:GPSAnimatedPulseKey];
    }

    if ([self.layer animationForKey:GPSAnimatedRotationKey] == nil) {
        CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotation.fromValue = @(-0.04);
        rotation.toValue = @(0.04);
        rotation.autoreverses = YES;
        rotation.duration = 1.6;
        rotation.repeatCount = HUGE_VALF;
        rotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.layer addAnimation:rotation forKey:GPSAnimatedRotationKey];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint translation = [pan translationInView:container];
    if (pan.state == UIGestureRecognizerStateBegan) self.dragStart = self.center;
    CGPoint center = CGPointMake(self.dragStart.x + translation.x, self.dragStart.y + translation.y);
    CGFloat halfWidth = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(self.bounds) / 2.0;
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) safeInsets = container.safeAreaInsets;
    CGFloat minX = halfWidth + 12.0;
    CGFloat maxX = CGRectGetWidth(container.bounds) - halfWidth - 12.0;
    CGFloat minY = safeInsets.top + halfHeight + 12.0;
    CGFloat maxY = CGRectGetHeight(container.bounds) - safeInsets.bottom - halfHeight - 12.0;
    center.x = MAX(minX, MIN(maxX, center.x));
    center.y = MAX(minY, MIN(maxY, center.y));
    self.center = center;
}

@end
