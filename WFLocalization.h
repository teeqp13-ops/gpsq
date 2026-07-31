#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const WFLanguageDidChangeNotification;

@interface WFLocalization : NSObject

+ (BOOL)isArabic;
+ (NSString *)languageCode;
+ (void)setLanguageCode:(NSString *)languageCode;
+ (void)toggleLanguage;
+ (NSString *)text:(NSString *)key;
+ (void)applyDirectionToView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
