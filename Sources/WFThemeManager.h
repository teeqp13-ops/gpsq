#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const WFThemeDidChangeNotification;

typedef NS_ENUM(NSInteger, WFThemeMode) {
    WFThemeModeSystem = 0,
    WFThemeModeLight = 1,
    WFThemeModeDark = 2,
};

@interface WFThemeManager : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) WFThemeMode mode;

- (BOOL)isDarkForTraitCollection:(nullable UITraitCollection *)traits;
- (UIBlurEffect *)glassEffectForTraitCollection:(nullable UITraitCollection *)traits;
- (UIColor *)backgroundColorForTraitCollection:(nullable UITraitCollection *)traits;
- (UIColor *)cardColorForTraitCollection:(nullable UITraitCollection *)traits;
- (UIColor *)primaryTextColorForTraitCollection:(nullable UITraitCollection *)traits;
- (UIColor *)secondaryTextColorForTraitCollection:(nullable UITraitCollection *)traits;
- (UIColor *)accentColor;
- (UIColor *)successColor;
- (UIColor *)dangerColor;

@end

NS_ASSUME_NONNULL_END
