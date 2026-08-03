//
//  WFManualIDPanel.h
//  WolFox GPS
//

#import <UIKit/UIKit.h>

@interface WFManualIDPanel : UIView

+ (void)presentOverView:(UIView *)hostView;

// القيمة الحالية المستخدمة كمعرّف (يدوي إن كان مفعّل، وإلا معرّف الجهاز التلقائي)
+ (NSString *)currentIdentifier;

@end
