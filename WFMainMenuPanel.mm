//
//  WFMainMenuPanel.mm
//  WolFox GPS - القائمة الرئيسية (تظهر بالشاشة كاملة عند الضغط على الأيقونة العائمة)
//
//  المحتوى:
//  - رأس: اسم التطبيق + زر إغلاق (يرجع للأيقونة العائمة)
//  - زر بحث
//  - زر تشغيل/إيقاف (Toggle)
//  - زر رفع الصور تشغيل/إيقاف (Toggle)
//  - شبكة أزرار "قريباً" بـ 4 ألوان (أصفر - برتقالي - أزرق - أخضر)، زرين بكل سطر
//  - الأيقونات عن طريق خط FontAwesome (لازم تضيف FontAwesome.ttf لملفات المشروع + Info.plist)
//

#import <UIKit/UIKit.h>
#import "WFMainMenuPanel.h"

// ===== ألوان البراند =====
static inline UIColor *WFNavy(void)  { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static inline UIColor *WFBlue(void)  { return [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0]; } // أزرق بحري سماوي

// ألوان أزرار "قريباً"
static inline UIColor *WFYellow(void){ return [UIColor colorWithRed:0xe8/255.0 green:0xc0/255.0 blue:0x2e/255.0 alpha:1.0]; }
static inline UIColor *WFOrange(void){ return [UIColor colorWithRed:0xe0/255.0 green:0x7a/255.0 blue:0x2e/255.0 alpha:1.0]; }
static inline UIColor *WFCyan(void)  { return [UIColor colorWithRed:0x2e/255.0 green:0x9b/255.0 blue:0xe0/255.0 alpha:1.0]; }
static inline UIColor *WFGreen(void) { return [UIColor colorWithRed:0x2e/255.0 green:0xb5/255.0 blue:0x6a/255.0 alpha:1.0]; }

// ===== أيقونات FontAwesome (Unicode) =====
// تأكد إن اسم الخط بالمشروع صحيح (مثلاً "FontAwesome5Free-Solid" حسب النسخة عندك)
static NSString * const kWFIconFontName = @"FontAwesome5Free-Solid";
static NSString * const kWFIconClose    = @"\uf00d"; // fa-times
static NSString * const kWFIconSearch   = @"\uf002"; // fa-search
static NSString * const kWFIconPlay     = @"\uf04b"; // fa-play
static NSString * const kWFIconStop     = @"\uf04d"; // fa-stop
static NSString * const kWFIconUpload   = @"\uf093"; // fa-upload
static NSString * const kWFIconLock     = @"\uf023"; // fa-lock (لأزرار قريباً)
static NSString * const kWFIconMap      = @"\uf279"; // fa-map
static NSString * const kWFIconID       = @"\uf2c2"; // fa-id-card

@interface WFMainMenuPanel ()
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, strong) UIButton *runButton;
@property (nonatomic, strong) UIButton *uploadButton;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIStackView *actionsStack;

@property (nonatomic, copy) void (^onClose)(void);
@property (nonatomic, copy) void (^onSearch)(void);
@property (nonatomic, copy) void (^onToggleRun)(BOOL isRunning);
@property (nonatomic, copy) void (^onToggleUpload)(BOOL isUploading);
@property (nonatomic, copy) void (^onMap)(void);
@property (nonatomic, copy) void (^onID)(void);
@end

@implementation WFMainMenuPanel

#pragma mark - العرض

+ (void)presentOverView:(UIView *)hostView
                 onClose:(void (^)(void))onClose
                onSearch:(void (^)(void))onSearch
             onToggleRun:(void (^)(BOOL isRunning))onToggleRun
          onToggleUpload:(void (^)(BOOL isUploading))onToggleUpload
                   onMap:(void (^)(void))onMap
                    onID:(void (^)(void))onID {

    WFMainMenuPanel *panel = [[WFMainMenuPanel alloc] initWithFrame:hostView.bounds];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panel.onClose = onClose;
    panel.onSearch = onSearch;
    panel.onToggleRun = onToggleRun;
    panel.onToggleUpload = onToggleUpload;
    panel.onMap = onMap;
    panel.onID = onID;
    panel.alpha = 0;
    [hostView addSubview:panel];

    [UIView animateWithDuration:0.25 animations:^{
        panel.alpha = 1;
    }];
}

#pragma mark - البناء

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = WFNavy();
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [self buildHeader];
        [self buildActionRows];
        [self buildComingSoonGrid];
    }
    return self;
}

// ---------- الرأس: الاسم + زر إغلاق ----------
- (void)buildHeader {
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:header];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"WolFox GPS";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentRight;
    [header addSubview:title];

    UIButton *closeBtn = [self iconButtonWithGlyph:kWFIconClose size:18 color:[UIColor whiteColor]];
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:12],
        [header.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [header.heightAnchor constraintEqualToConstant:40],

        [closeBtn.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [closeBtn.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:36],
        [closeBtn.heightAnchor constraintEqualToConstant:36],

        [title.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:closeBtn.trailingAnchor constant:8],
    ]];

    self.headerView = header; // خزّن مرجع لو تحتاجه لاحقًا (اختياري - أضف property لو تبيه)
}

// ---------- صف الأزرار: بحث / تشغيل-إيقاف / رفع الصور ----------
- (void)buildActionRows {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:stack];

    // زر البحث
    UIButton *searchBtn = [self actionRowButtonWithIcon:kWFIconSearch
                                                   title:@"بحث"
                                                subtitle:nil
                                                   color:WFBlue()];
    [searchBtn addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:searchBtn];

    // زر تشغيل/إيقاف
    UIButton *runBtn = [self actionRowButtonWithIcon:kWFIconPlay
                                                title:@"تشغيل"
                                             subtitle:nil
                                                color:WFGreen()];
    [runBtn addTarget:self action:@selector(runTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:runBtn];
    self.runButton = runBtn;

    // زر رفع الصور تشغيل/إيقاف
    UIButton *uploadBtn = [self actionRowButtonWithIcon:kWFIconUpload
                                                   title:@"رفع الصور"
                                                subtitle:@"إيقاف"
                                                   color:WFOrange()];
    [uploadBtn addTarget:self action:@selector(uploadTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:uploadBtn];
    self.uploadButton = uploadBtn;

    // زر الخريطة
    UIButton *mapBtn = [self actionRowButtonWithIcon:kWFIconMap
                                                title:@"الخريطة"
                                             subtitle:nil
                                                color:WFCyan()];
    [mapBtn addTarget:self action:@selector(mapTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:mapBtn];

    // زر المعرّف اليدوي
    UIButton *idBtn = [self actionRowButtonWithIcon:kWFIconID
                                               title:@"المعرّف"
                                            subtitle:nil
                                               color:WFYellow()];
    [idBtn addTarget:self action:@selector(idTapped) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:idBtn];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:70],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
    ]];

    self.actionsStack = stack; // نحتاجه لتثبيت الشبكة تحته
}

// ---------- شبكة "قريباً" - 4 ألوان، زرين بكل سطر ----------
- (void)buildComingSoonGrid {
    NSArray *items = @[
        @{@"title": @"ميزة قريبة", @"color": WFYellow()},
        @{@"title": @"ميزة قريبة", @"color": WFOrange()},
        @{@"title": @"ميزة قريبة", @"color": WFCyan()},
        @{@"title": @"ميزة قريبة", @"color": WFGreen()},
    ];

    UIStackView *outer = [[UIStackView alloc] init];
    outer.translatesAutoresizingMaskIntoConstraints = NO;
    outer.axis = UILayoutConstraintAxisVertical;
    outer.spacing = 12;
    outer.distribution = UIStackViewDistributionFillEqually;
    [self addSubview:outer];

    for (NSInteger i = 0; i < items.count; i += 2) {
        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.distribution = UIStackViewDistributionFillEqually;
        row.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

        [row addArrangedSubview:[self comingSoonCardWithTitle:items[i][@"title"] color:items[i][@"color"]]];
        if (i + 1 < items.count) {
            [row addArrangedSubview:[self comingSoonCardWithTitle:items[i+1][@"title"] color:items[i+1][@"color"]]];
        }
        [outer addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [outer.topAnchor constraintEqualToAnchor:self.actionsStack.bottomAnchor constant:26],
        [outer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [outer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
    ]];
}

- (UIView *)comingSoonCardWithTitle:(NSString *)title color:(UIColor *)color {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [color colorWithAlphaComponent:0.18];
    card.layer.cornerRadius = 14;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [color colorWithAlphaComponent:0.5].CGColor;
    [card.heightAnchor constraintEqualToConstant:88].active = YES;

    UILabel *icon = [[UILabel alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.text = kWFIconLock;
    icon.font = [UIFont fontWithName:kWFIconFontName size:22] ?: [UIFont systemFontOfSize:22];
    icon.textColor = color;
    icon.textAlignment = NSTextAlignmentCenter;
    [card addSubview:icon];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"قريباً";
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:14];
    label.textAlignment = NSTextAlignmentCenter;
    [card addSubview:label];

    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = title;
    sub.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    sub.font = [UIFont systemFontOfSize:11];
    sub.textAlignment = NSTextAlignmentCenter;
    [card addSubview:sub];

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [icon.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],

        [label.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:6],
        [label.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],

        [sub.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:2],
        [sub.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [sub.leadingAnchor constraintGreaterThanOrEqualToAnchor:card.leadingAnchor constant:6],
        [sub.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-6],
    ]];

    return card;
}

#pragma mark - عناصر مساعدة لبناء الأزرار

- (UIButton *)iconButtonWithGlyph:(NSString *)glyph size:(CGFloat)size color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:glyph forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont fontWithName:kWFIconFontName size:size] ?: [UIFont systemFontOfSize:size];
    [btn setTitleColor:color forState:UIControlStateNormal];
    return btn;
}

- (UIButton *)actionRowButtonWithIcon:(NSString *)glyph
                                 title:(NSString *)title
                              subtitle:(NSString *)subtitle
                                 color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    btn.layer.cornerRadius = 12;
    [btn.heightAnchor constraintEqualToConstant:56].active = YES;
    btn.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    UILabel *icon = [[UILabel alloc] init];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.text = glyph;
    icon.font = [UIFont fontWithName:kWFIconFontName size:18] ?: [UIFont systemFontOfSize:18];
    icon.textColor = color;
    icon.userInteractionEnabled = NO;
    icon.tag = 501; // للوصول لاحقًا عند تغيير حالة التوغل
    [btn addSubview:icon];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = title;
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    titleLbl.textAlignment = NSTextAlignmentRight;
    titleLbl.userInteractionEnabled = NO;
    titleLbl.tag = 502;
    [btn addSubview:titleLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text = subtitle ?: @"";
    subLbl.textColor = [UIColor colorWithWhite:1 alpha:0.5];
    subLbl.font = [UIFont systemFontOfSize:12];
    subLbl.textAlignment = NSTextAlignmentLeft;
    subLbl.userInteractionEnabled = NO;
    subLbl.tag = 503;
    [btn addSubview:subLbl];

    [NSLayoutConstraint activateConstraints:@[
        [icon.trailingAnchor constraintEqualToAnchor:btn.trailingAnchor constant:-16],
        [icon.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],

        [titleLbl.trailingAnchor constraintEqualToAnchor:icon.leadingAnchor constant:-12],
        [titleLbl.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],

        [subLbl.leadingAnchor constraintEqualToAnchor:btn.leadingAnchor constant:16],
        [subLbl.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [subLbl.trailingAnchor constraintLessThanOrEqualToAnchor:titleLbl.leadingAnchor constant:-8],
    ]];

    return btn;
}

#pragma mark - الأحداث

- (void)closeTapped {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (self.onClose) self.onClose(); // يرجع على الأيقونة العائمة
    }];
}

- (void)searchTapped {
    if (self.onSearch) self.onSearch();
}

- (void)mapTapped {
    if (self.onMap) self.onMap();
}

- (void)idTapped {
    if (self.onID) self.onID();
}

- (void)runTapped {
    self.isRunning = !self.isRunning;

    UILabel *icon  = [self.runButton viewWithTag:501];
    UILabel *title = [self.runButton viewWithTag:502];
    icon.text  = self.isRunning ? kWFIconStop : kWFIconPlay;
    title.text = self.isRunning ? @"إيقاف" : @"تشغيل";

    if (self.onToggleRun) self.onToggleRun(self.isRunning);
}

- (void)uploadTapped {
    self.isUploading = !self.isUploading;

    UILabel *title = [self.uploadButton viewWithTag:502];
    UILabel *sub   = [self.uploadButton viewWithTag:503];
    title.text = @"رفع الصور";
    sub.text   = self.isUploading ? @"تشغيل" : @"إيقاف";

    if (self.onToggleUpload) self.onToggleUpload(self.isUploading);
}

@end

/*
 طريقة الاستخدام من الأيقونة العائمة (WFGPSPanel مثلاً):

 - (void)floatingIconTapped {
     [WFMainMenuPanel presentOverView:self.view
         onClose:^{
             self.floatingButton.hidden = NO;
         }
         onSearch:^{
             [self openSearchScreen];
         }
         onToggleRun:^(BOOL isRunning) {
             // شغّل/أوقف خدمة الـ GPS الوهمي عندك
         }
         onToggleUpload:^(BOOL isUploading) {
             // شغّل/أوقف رفع الصور
         }
         onMap:^{
             [self openMapScreen];
         }
         onID:^{
             [self openIDScreen];
         }];

     self.floatingButton.hidden = YES; // اخفِ الأيقونة وقت ظهور المنيو الكامل
 }

 ملاحظة FontAwesome:
 - أضف ملف FontAwesome (مثلاً "Font Awesome 5 Free-Solid-900.otf") لمشروعك
 - سجّله بـ Info.plist تحت "Fonts provided by application"
 - عدّل kWFIconFontName بالأعلى ليطابق الاسم الداخلي للخط بالضبط
   (تقدر تطبع كل أسماء الخطوط المتوفرة بـ: for (NSString *f in [UIFont fontNamesForFamilyName:@"Font Awesome 5 Free"]) NSLog(@"%@", f);)
*/
