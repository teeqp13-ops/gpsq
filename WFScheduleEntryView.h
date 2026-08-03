#import <UIKit/UIKit.h>

@interface WFScheduleEntryViewController : UIViewController

+ (void)showScheduleWithCompletion:(void (^)(BOOL success))completion;

@property (nonatomic, copy) void (^completionHandler)(BOOL success);

@end
