#import "WFThemeManager.h"

static NSString * const WFDarkModeKey = @"wolfox_gps_dark_mode";

@implementation WFThemeManager

+ (instancetype)shared {
    static WFThemeManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WFThemeManager new]; });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        _darkMode = [defaults objectForKey:WFDarkModeKey] ? [defaults boolForKey:WFDarkModeKey] : YES;
    }
    return self;
}

- (void)setDarkMode:(BOOL)darkMode {
    _darkMode = darkMode;
    [NSUserDefaults.standardUserDefaults setBool:darkMode forKey:WFDarkModeKey];
}

- (UIColor *)backgroundColor { return self.darkMode ? [UIColor colorWithRed:0.02 green:0.04 blue:0.08 alpha:1] : [UIColor systemGroupedBackgroundColor]; }
- (UIColor *)cardColor { return self.darkMode ? [UIColor colorWithWhite:1 alpha:0.10] : [UIColor colorWithWhite:1 alpha:0.70]; }
- (UIColor *)primaryTextColor { return self.darkMode ? UIColor.whiteColor : UIColor.labelColor; }
- (UIColor *)secondaryTextColor { return self.darkMode ? [UIColor colorWithWhite:0.72 alpha:1] : UIColor.secondaryLabelColor; }
- (UIColor *)accentColor { return [UIColor colorWithRed:0.10 green:0.67 blue:0.96 alpha:1]; }
- (UIBlurEffect *)blurEffect { return [UIBlurEffect effectWithStyle:self.darkMode ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight]; }

- (void)applyGlassStyleToView:(UIView *)view cornerRadius:(CGFloat)cornerRadius {
    view.backgroundColor = [self cardColor];
    view.layer.cornerRadius = cornerRadius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 1;
    view.layer.borderColor = [UIColor colorWithWhite:self.darkMode ? 1 : 0 alpha:0.12].CGColor;
    view.layer.shadowColor = UIColor.blackColor.CGColor;
    view.layer.shadowOpacity = self.darkMode ? 0.28 : 0.10;
    view.layer.shadowRadius = 18;
    view.layer.shadowOffset = CGSizeMake(0, 8);
}

@end
