#import "WFScheduleEntryView.h"
#import "ok.h"
#import <objc/runtime.h>

static inline UIColor *WFText(void)    { return [UIColor colorWithRed:0.918 green:0.906 blue:0.961 alpha:1.0]; }
static inline UIColor *WFSuccess(void) { return [UIColor colorWithRed:0.204 green:0.827 blue:0.600 alpha:1.0]; }

static UIWindow *scheduleWindow = nil;

@implementation WFScheduleEntryViewController {
    UIView *_cardView;
    UILabel *_titleLabel;
    UIButton *_closeButton;
    
    // Days selection
    NSArray<UIButton *> *_dayButtons;
    NSMutableArray<NSNumber *> *_selectedDays;
    
    // Time selection
    UIButton *_fromTimeButton;
    UIButton *_toTimeButton;
    UIDatePicker *_timePicker;
    
    // Save button
    UIButton *_saveButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadScheduleData];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    
    // Card View
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = CGRectMake(0, 0, 320, 450);
    blur.center = self.view.center;
    blur.layer.cornerRadius = 22;
    blur.clipsToBounds = YES;
    blur.layer.borderWidth = 1;
    blur.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    blur.contentView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.03];
    [self.view addSubview:blur];
    _cardView = blur;
    
    UIView *content = blur.contentView;
    
    // Header
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 280, 30)];
    _titleLabel.text = @"إعدادات الجدولة";
    _titleLabel.textColor = WFText();
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:_titleLabel];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(280, 20, 20, 20);
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_closeButton setTitleColor:WFText() forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(dismissSchedule) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_closeButton];
    
    // Days Selection
    UILabel *daysLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 280, 20)];
    daysLabel.text = @"الأيام:";
    daysLabel.textColor = WFText();
    daysLabel.font = [UIFont systemFontOfSize:15];
    daysLabel.textAlignment = NSTextAlignmentRight;
    [content addSubview:daysLabel];
    
    NSArray *dayNames = @[@"الأحد", @"الاثنين", @"الثلاثاء", @"الأربعاء", @"الخميس", @"الجمعة", @"السبت"];
    _selectedDays = [NSMutableArray new];
    
    CGFloat dayButtonWidth = 130;
    CGFloat dayButtonHeight = 40;
    CGFloat startXLeft = 20;
    CGFloat startXRight = 170;
    CGFloat startY = 100;
    
    NSMutableArray *tempDayButtons = [NSMutableArray new];
    // الأحد والاثنين
    UIButton *sundayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    sundayButton.frame = CGRectMake(startXRight, startY, dayButtonWidth, dayButtonHeight);
    [sundayButton setTitle:@"الأحد" forState:UIControlStateNormal];
    [sundayButton setTitleColor:WFText() forState:UIControlStateNormal];
    sundayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    sundayButton.layer.cornerRadius = 10;
    sundayButton.layer.borderWidth = 1;
    sundayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    sundayButton.tag = 0;
    [sundayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:sundayButton];
    [tempDayButtons addObject:sundayButton];

    UIButton *mondayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    mondayButton.frame = CGRectMake(startXLeft, startY, dayButtonWidth, dayButtonHeight);
    [mondayButton setTitle:@"الاثنين" forState:UIControlStateNormal];
    [mondayButton setTitleColor:WFText() forState:UIControlStateNormal];
    mondayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    mondayButton.layer.cornerRadius = 10;
    mondayButton.layer.borderWidth = 1;
    mondayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    mondayButton.tag = 1;
    [mondayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:mondayButton];
    [tempDayButtons addObject:mondayButton];

    // الثلاثاء والأربعاء
    startY += dayButtonHeight + 10;
    UIButton *tuesdayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    tuesdayButton.frame = CGRectMake(startXRight, startY, dayButtonWidth, dayButtonHeight);
    [tuesdayButton setTitle:@"الثلاثاء" forState:UIControlStateNormal];
    [tuesdayButton setTitleColor:WFText() forState:UIControlStateNormal];
    tuesdayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    tuesdayButton.layer.cornerRadius = 10;
    tuesdayButton.layer.borderWidth = 1;
    tuesdayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    tuesdayButton.tag = 2;
    [tuesdayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:tuesdayButton];
    [tempDayButtons addObject:tuesdayButton];

    UIButton *wednesdayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    wednesdayButton.frame = CGRectMake(startXLeft, startY, dayButtonWidth, dayButtonHeight);
    [wednesdayButton setTitle:@"الأربعاء" forState:UIControlStateNormal];
    [wednesdayButton setTitleColor:WFText() forState:UIControlStateNormal];
    wednesdayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    wednesdayButton.layer.cornerRadius = 10;
    wednesdayButton.layer.borderWidth = 1;
    wednesdayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    wednesdayButton.tag = 3;
    [wednesdayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:wednesdayButton];
    [tempDayButtons addObject:wednesdayButton];

    // الخميس والجمعة
    startY += dayButtonHeight + 10;
    UIButton *thursdayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    thursdayButton.frame = CGRectMake(startXRight, startY, dayButtonWidth, dayButtonHeight);
    [thursdayButton setTitle:@"الخميس" forState:UIControlStateNormal];
    [thursdayButton setTitleColor:WFText() forState:UIControlStateNormal];
    thursdayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    thursdayButton.layer.cornerRadius = 10;
    thursdayButton.layer.borderWidth = 1;
    thursdayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    thursdayButton.tag = 4;
    [thursdayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:thursdayButton];
    [tempDayButtons addObject:thursdayButton];

    UIButton *fridayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    fridayButton.frame = CGRectMake(startXLeft, startY, dayButtonWidth, dayButtonHeight);
    [fridayButton setTitle:@"الجمعة" forState:UIControlStateNormal];
    [fridayButton setTitleColor:WFText() forState:UIControlStateNormal];
    fridayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    fridayButton.layer.cornerRadius = 10;
    fridayButton.layer.borderWidth = 1;
    fridayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    fridayButton.tag = 5;
    [fridayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:fridayButton];
    [tempDayButtons addObject:fridayButton];

    // السبت
    startY += dayButtonHeight + 10;
    UIButton *saturdayButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saturdayButton.frame = CGRectMake(startXLeft, startY, dayButtonWidth, dayButtonHeight);
    [saturdayButton setTitle:@"السبت" forState:UIControlStateNormal];
    [saturdayButton setTitleColor:WFText() forState:UIControlStateNormal];
    saturdayButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    saturdayButton.layer.cornerRadius = 10;
    saturdayButton.layer.borderWidth = 1;
    saturdayButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    saturdayButton.tag = 6;
    [saturdayButton addTarget:self action:@selector(dayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:saturdayButton];
    [tempDayButtons addObject:saturdayButton];

    _dayButtons = [tempDayButtons copy];
    
    // Time Selection
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, startY + dayButtonHeight + 30, 280, 20)];
    timeLabel.text = @"الوقت:";
    timeLabel.textColor = WFText();
    timeLabel.font = [UIFont systemFontOfSize:15];
    timeLabel.textAlignment = NSTextAlignmentRight;
    [content addSubview:timeLabel];
    
    _fromTimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _fromTimeButton.frame = CGRectMake(20, timeLabel.frame.origin.y + 30, 120, 40);
    UILabel *fromLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, _fromTimeButton.frame.origin.y, 40, 40)];
    fromLabel.text = @"من";
    fromLabel.textColor = WFText();
    fromLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:fromLabel];
    [_fromTimeButton setTitle:@"8:00 AM" forState:UIControlStateNormal];
    [_fromTimeButton setTitleColor:WFText() forState:UIControlStateNormal];
    _fromTimeButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _fromTimeButton.layer.cornerRadius = 10;
    _fromTimeButton.layer.borderWidth = 1;
    _fromTimeButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_fromTimeButton addTarget:self action:@selector(showTimePickerForFromTime) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_fromTimeButton];
    

    
    _toTimeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _toTimeButton.frame = CGRectMake(180, timeLabel.frame.origin.y + 30, 120, 40);
    UILabel *toLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, _toTimeButton.frame.origin.y, 40, 40)];
    toLabel.text = @"إلى";
    toLabel.textColor = WFText();
    toLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:toLabel];
    [_toTimeButton setTitle:@"4:00 PM" forState:UIControlStateNormal];
    [_toTimeButton setTitleColor:WFText() forState:UIControlStateNormal];
    _toTimeButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _toTimeButton.layer.cornerRadius = 10;
    _toTimeButton.layer.borderWidth = 1;
    _toTimeButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_toTimeButton addTarget:self action:@selector(showTimePickerForToTime) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_toTimeButton];
    

    
    // Save Button
    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.frame = CGRectMake(20, _toTimeButton.frame.origin.y + 60, 280, 50);
    [_saveButton setTitle:@"حفظ" forState:UIControlStateNormal];
    [_saveButton setTitleColor:WFText() forState:UIControlStateNormal];
    _saveButton.backgroundColor = WFSuccess();
    _saveButton.layer.cornerRadius = 10;
    [_saveButton addTarget:self action:@selector(saveSchedule) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_saveButton];
}

- (void)dayButtonTapped:(UIButton *)sender {
    NSNumber *dayTag = @(sender.tag);
    if ([_selectedDays containsObject:dayTag]) {
        [_selectedDays removeObject:dayTag];
        sender.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
        sender.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    } else {
        [_selectedDays addObject:dayTag];
        sender.backgroundColor = WFSuccess();
        sender.layer.borderColor = WFSuccess().CGColor;
    }
}

- (void)showTimePickerForFromTime {
    [self showTimePickerWithTargetButton:_fromTimeButton];
}

- (void)showTimePickerForToTime {
    [self showTimePickerWithTargetButton:_toTimeButton];
}

- (void)showTimePickerWithTargetButton:(UIButton *)targetButton {
    if (_timePicker) {
        [_timePicker removeFromSuperview];
        _timePicker = nil;
    }
    
    _timePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 200, self.view.frame.size.width, 200)];
    _timePicker.datePickerMode = UIDatePickerModeTime;
    _timePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    _timePicker.backgroundColor = [UIColor whiteColor];
    [_timePicker addTarget:self action:@selector(timePickerValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_timePicker];
    
    // Store target button to update its title later
    objc_setAssociatedObject(self, @selector(timePickerWithTargetButton:), targetButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)timePickerValueChanged:(UIDatePicker *)picker {
    UIButton *targetButton = objc_getAssociatedObject(self, @selector(timePickerWithTargetButton:));
    if (targetButton) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.timeStyle = NSDateFormatterShortStyle;
        [targetButton setTitle:[formatter stringFromDate:picker.date] forState:UIControlStateNormal];
    }
}

- (void)loadScheduleData {
    // Load saved schedule data from NSUserDefaults
    // For now, just set default values
}

- (void)saveSchedule {
    // Save schedule data to NSUserDefaults
    // For now, just dismiss
    [self dismissSchedule];
}

+ (void)showScheduleWithCompletion:(void (^)(BOOL success))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (scheduleWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        scheduleWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        scheduleWindow.windowLevel = UIWindowLevelStatusBar + 10.0;
        scheduleWindow.backgroundColor = [UIColor clearColor];
        
        WFScheduleEntryViewController *vc = [[WFScheduleEntryViewController alloc] init];
        vc.completionHandler = ^(BOOL success) {
            scheduleWindow.hidden = YES;
            scheduleWindow = nil;
            if (completion) completion(success);
        };
        
        scheduleWindow.rootViewController = vc;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    scheduleWindow.windowScene = scene;
                    break;
                }
            }
        }
        [scheduleWindow makeKeyAndVisible];
    });
}

- (void)dismissSchedule {
    if (scheduleWindow) {
        [UIView animateWithDuration:0.3 animations:^{
            scheduleWindow.alpha = 0;
        } completion:^(BOOL finished) {
            scheduleWindow.hidden = YES;
            scheduleWindow = nil;
        }];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
