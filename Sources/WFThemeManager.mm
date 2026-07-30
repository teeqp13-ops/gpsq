#import "WFThemeManager.h"

NSString *const WFThemeDidChangeNotification = @"WFThemeDidChangeNotification";
static NSString *const WFThemeModeKey = @"WFThemeMode";

@implementation WFThemeManager

+ (instancetype)shared {
    static WFThemeManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [WFThemeManager new];
        NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:WFThemeModeKey];
        manager->_mode = (saved >= WFThemeModeSystem && saved <= WFThemeModeDark) ? saved : WFThemeModeSystem;
    });
    return manager;
}

- (void)setMode:(WFThemeMode)mode {
    if (_mode == mode) return;
    _mode = mode;
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:WFThemeModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:WFThemeDidChangeNotification object:self];
}

- (BOOL)isDarkForTraitCollection:(UITraitCollection *)traits {
    if (self.mode == WFThemeModeDark) return YES;
    if (self.mode == WFThemeModeLight) return NO;
    if (@available(iOS 13.0, *)) return (traits ?: UIScreen.mainScreen.traitCollection).userInterfaceStyle == UIUserInterfaceStyleDark;
    return YES;
}

- (UIBlurEffect *)glassEffectForTraitCollection:(UITraitCollection *)traits {
    BOOL dark = [self isDarkForTraitCollection:traits];
    if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight];
    }
    return [UIBlurEffect effectWithStyle:dark ? UIBlurEffectStyleDark : UIBlurEffectStyleExtraLight];
}

- (UIColor *)backgroundColorForTraitCollection:(UITraitCollection *)traits {
    return [self isDarkForTraitCollection:traits]
        ? [UIColor colorWithRed:0.025 green:0.040 blue:0.070 alpha:1.0]
        : [UIColor colorWithRed:0.945 green:0.965 blue:0.985 alpha:1.0];
}

- (UIColor *)cardColorForTraitCollection:(UITraitCollection *)traits {
    return [self isDarkForTraitCollection:traits]
        ? [UIColor colorWithWhite:1.0 alpha:0.085]
        : [UIColor colorWithWhite:1.0 alpha:0.68];
}

- (UIColor *)primaryTextColorForTraitCollection:(UITraitCollection *)traits {
    return [self isDarkForTraitCollection:traits] ? UIColor.whiteColor : [UIColor colorWithWhite:0.08 alpha:1.0];
}

- (UIColor *)secondaryTextColorForTraitCollection:(UITraitCollection *)traits {
    return [self isDarkForTraitCollection:traits]
        ? [UIColor colorWithWhite:0.72 alpha:1.0]
        : [UIColor colorWithWhite:0.36 alpha:1.0];
}

- (UIColor *)accentColor {
    return [UIColor colorWithRed:0.10 green:0.67 blue:0.96 alpha:1.0];
}

- (UIColor *)successColor {
    return [UIColor colorWithRed:0.18 green:0.82 blue:0.52 alpha:1.0];
}

- (UIColor *)dangerColor {
    return [UIColor colorWithRed:1.0 green:0.30 blue:0.38 alpha:1.0];
}

@end
