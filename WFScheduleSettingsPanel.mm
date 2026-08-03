//
//  WFScheduleSettingsPanel.mm
//  WolFox GPS - إعدادات الجدولة
//

#import "WFScheduleSettingsPanel.h"

static inline UIColor *WFNavy(void) { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }

@interface WFScheduleSettingsPanel ()
@property (nonatomic, copy) void (^onSave)(NSSet<NSNumber *> *selectedDays, NSDate *fromTime, NSDate *toTime);
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selectedDays;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIButton *> *dayButtons;
@property (nonatomic, strong) UIDatePicker *fromPicker;
@property (nonatomic, strong) UIDatePicker *toPicker;
@end

@implementation WFScheduleSettingsPanel

+ (void)presentOverView:(UIView *)hostView
                  onSave:(void (^)(NSSet<NSNumber *> *, NSDate *, NSDate *))onSave {
    WFScheduleSettingsPanel *panel = [[WFScheduleSettingsPanel alloc] initWithFrame:hostView.bounds];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panel.onSave = onSave;
    [hostView addSubview:panel];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = WFNavy();
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        self.selectedDays = [NSMutableSet set];
        self.dayButtons = [NSMutableDictionary dictionary];
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"إعدادات الجدولة";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:22];
    [self addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissPanel) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeBtn];

    UILabel *daysLabel = [[UILabel alloc] init];
    daysLabel.translatesAutoresizingMaskIntoConstraints = NO;
    daysLabel.text = @"الأيام:";
    daysLabel.textColor = [UIColor whiteColor];
    daysLabel.font = [UIFont boldSystemFontOfSize:16];
    [self addSubview:daysLabel];

    NSArray *dayNames = @[@"الأحد", @"الاثنين", @"الثلاثاء", @"الأربعاء", @"الخميس", @"الجمعة", @"السبت"];
    UIStackView *grid = [[UIStackView alloc] init];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 10;
    grid.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:grid];

    for (NSInteger i = 0; i < dayNames.count; i += 2) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 10;
        row.distribution = UIStackViewDistributionFillEqually;
        row.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

        UIButton *b1 = [self dayButtonWithTitle:dayNames[i] dayIndex:i + 1];
        [row addArrangedSubview:b1];
        if (i + 1 < dayNames.count) {
            UIButton *b2 = [self dayButtonWithTitle:dayNames[i+1] dayIndex:i + 2];
            [row addArrangedSubview:b2];
        }
        [grid addArrangedSubview:row];
    }

    // الوقت
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.text = @"الوقت:";
    timeLabel.textColor = [UIColor whiteColor];
    timeLabel.font = [UIFont boldSystemFontOfSize:16];
    [self addSubview:timeLabel];

    UILabel *fromLabel = [[UILabel alloc] init];
    fromLabel.translatesAutoresizingMaskIntoConstraints = NO;
    fromLabel.text = @"من:";
    fromLabel.textColor = [UIColor whiteColor];
    [self addSubview:fromLabel];

    self.fromPicker = [[UIDatePicker alloc] init];
    self.fromPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.fromPicker.datePickerMode = UIDatePickerModeTime;
    self.fromPicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    self.fromPicker.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self addSubview:self.fromPicker];

    UILabel *toLabel = [[UILabel alloc] init];
    toLabel.translatesAutoresizingMaskIntoConstraints = NO;
    toLabel.text = @"إلى:";
    toLabel.textColor = [UIColor whiteColor];
    [self addSubview:toLabel];

    self.toPicker = [[UIDatePicker alloc] init];
    self.toPicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.toPicker.datePickerMode = UIDatePickerModeTime;
    self.toPicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    self.toPicker.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self addSubview:self.toPicker];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn setTitle:@"حفظ" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    saveBtn.backgroundColor = [UIColor systemGreenColor];
    saveBtn.layer.cornerRadius = 12;
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:saveBtn];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],

        [closeBtn.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [closeBtn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],

        [daysLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:26],
        [daysLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],

        [grid.topAnchor constraintEqualToAnchor:daysLabel.bottomAnchor constant:14],
        [grid.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [grid.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],

        [timeLabel.topAnchor constraintEqualToAnchor:grid.bottomAnchor constant:30],
        [timeLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],

        [fromLabel.topAnchor constraintEqualToAnchor:timeLabel.bottomAnchor constant:16],
        [fromLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.fromPicker.centerYAnchor constraintEqualToAnchor:fromLabel.centerYAnchor],
        [self.fromPicker.trailingAnchor constraintEqualToAnchor:fromLabel.leadingAnchor constant:-10],

        [toLabel.topAnchor constraintEqualToAnchor:fromLabel.bottomAnchor constant:16],
        [toLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [self.toPicker.centerYAnchor constraintEqualToAnchor:toLabel.centerYAnchor],
        [self.toPicker.trailingAnchor constraintEqualToAnchor:toLabel.leadingAnchor constant:-10],

        [saveBtn.topAnchor constraintEqualToAnchor:toLabel.bottomAnchor constant:30],
        [saveBtn.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [saveBtn.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [saveBtn.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (UIButton *)dayButtonWithTitle:(NSString *)title dayIndex:(NSInteger)dayIndex {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    btn.layer.cornerRadius = 10;
    [btn.heightAnchor constraintEqualToConstant:50].active = YES;
    btn.tag = dayIndex;
    [btn addTarget:self action:@selector(dayTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.dayButtons[@(dayIndex)] = btn;
    return btn;
}

- (void)dayTapped:(UIButton *)sender {
    NSNumber *day = @(sender.tag);
    if ([self.selectedDays containsObject:day]) {
        [self.selectedDays removeObject:day];
        sender.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    } else {
        [self.selectedDays addObject:day];
        sender.backgroundColor = [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0];
    }
}

- (void)saveTapped {
    if (self.selectedDays.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تنبيه"
                                                                         message:@"الرجاء تحديد يوم واحد على الأقل"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        alert.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
        return;
    }

    if (self.onSave) {
        self.onSave([self.selectedDays copy], self.fromPicker.date, self.toPicker.date);
    }
    [self dismissPanel];
}

- (void)dismissPanel {
    [self removeFromSuperview];
}

@end
