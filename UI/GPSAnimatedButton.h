#import <UIKit/UIKit.h>

@interface GPSAnimatedButton : UIButton

- (instancetype)initWithActivated:(BOOL)activated;
- (void)setActivatedState:(BOOL)activated animated:(BOOL)animated;

@end
