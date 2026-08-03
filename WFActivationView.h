//
//  WFActivationView.h
//  WolFox GPS
//

#import <UIKit/UIKit.h>

@interface WFActivationView : UIView <UITextFieldDelegate>

+ (BOOL)isActivated;
+ (void)setActivated:(BOOL)activated;

+ (void)saveLicenseCode:(NSString *)code expiryDate:(NSDate *)expiryDate;
+ (NSString *)licenseCode;
+ (NSDate *)licenseExpiryDate;

+ (void)presentOnViewController:(UIViewController *)vc
                       onSubmit:(void (^)(NSString *code))onSubmit
                        onLater:(void (^)(void))onLater;

@end
