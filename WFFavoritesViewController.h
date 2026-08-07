#import <UIKit/UIKit.h>

@interface WFFavoritesViewController : UIViewController

+ (void)showFavoritesWithCompletion:(void (^)(BOOL success))completion;

@property (nonatomic, copy) void (^completionHandler)(BOOL success);

@end
