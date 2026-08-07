#import <UIKit/UIKit.h>

@interface WFCodeEntryViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, copy) void (^completionHandler)(BOOL success);
+ (void)showActivationWithCompletion:(void (^)(BOOL success))completion;
@end
