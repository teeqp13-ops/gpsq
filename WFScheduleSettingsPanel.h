//
//  WFScheduleSettingsPanel.h
//  WolFox GPS
//

#import <UIKit/UIKit.h>

@interface WFScheduleSettingsPanel : UIView

// onSave يرجع الأيام المختارة (1=الأحد ... 7=السبت) ووقت البداية/النهاية
+ (void)presentOverView:(UIView *)hostView
                  onSave:(void (^)(NSSet<NSNumber *> *selectedDays, NSDate *fromTime, NSDate *toTime))onSave;

@end
