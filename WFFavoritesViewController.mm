#import "WFFavoritesViewController.h"
#import "ok.h"

static inline UIColor *WFText(void)   { return [UIColor colorWithRed:0.918 green:0.906 blue:0.961 alpha:1.0]; }
static inline UIColor *WFDanger(void) { return [UIColor colorWithRed:0.973 green:0.443 blue:0.443 alpha:1.0]; }

static UIWindow *favoritesWindow = nil;

@implementation WFFavoritesViewController {
    UIView *_cardView;
    UILabel *_titleLabel;
    UIButton *_closeButton;
    UITableView *_favoritesTable;
    
    UIButton *_addLocationButton;
    UIButton *_editButton;
    UIButton *_deleteButton;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self loadFavoritesData];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor clearColor];
    
    // Card View
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = CGRectMake(0, 0, 320, 550);
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
    _titleLabel.text = @"المفضلة";
    _titleLabel.textColor = WFText();
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:_titleLabel];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(280, 20, 20, 20);
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_closeButton setTitleColor:WFText() forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(dismissFavorites) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_closeButton];
    
    // Favorites Table

    
    // Action Buttons
    // Dropdown for favorites
    UIButton *dropdownButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dropdownButton.frame = CGRectMake(20, 70, 280, 50);
    [dropdownButton setTitle:@"المفضلة" forState:UIControlStateNormal];
    [dropdownButton setTitleColor:WFText() forState:UIControlStateNormal];
    dropdownButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    dropdownButton.layer.cornerRadius = 10;
    dropdownButton.layer.borderWidth = 1;
    dropdownButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [dropdownButton addTarget:self action:@selector(showFavoritesDropdown) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:dropdownButton];

    UILabel *dropdownArrow = [[UILabel alloc] initWithFrame:CGRectMake(dropdownButton.frame.size.width - 30, 0, 30, 50)];
    dropdownArrow.text = @"V";
    dropdownArrow.textColor = WFText();
    dropdownArrow.textAlignment = NSTextAlignmentCenter;
    [dropdownButton addSubview:dropdownArrow];

    _addLocationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _addLocationButton.frame = CGRectMake(20, 130, 280, 50);
    [_addLocationButton setTitle:@"+ إضافة الموقع الحالي" forState:UIControlStateNormal];
    [_addLocationButton setTitleColor:WFText() forState:UIControlStateNormal];
    _addLocationButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _addLocationButton.layer.cornerRadius = 10;
    _addLocationButton.layer.borderWidth = 1;
    _addLocationButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_addLocationButton addTarget:self action:@selector(addCurrentLocationToFavorites) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_addLocationButton];
    
    _editButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _editButton.frame = CGRectMake(20, 190, 130, 50);
    [_editButton setTitle:@"تعديل ✏️" forState:UIControlStateNormal];
    [_editButton setTitleColor:WFText() forState:UIControlStateNormal];
    _editButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _editButton.layer.cornerRadius = 10;
    _editButton.layer.borderWidth = 1;
    _editButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_editButton addTarget:self action:@selector(editFavorites) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_editButton];
    
    _deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _deleteButton.frame = CGRectMake(170, 190, 130, 50);
    [_deleteButton setTitle:@"حذف 🗑️" forState:UIControlStateNormal];
    [_deleteButton setTitleColor:WFDanger() forState:UIControlStateNormal];
    _deleteButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    _deleteButton.layer.cornerRadius = 10;
    _deleteButton.layer.borderWidth = 1;
    _deleteButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_deleteButton addTarget:self action:@selector(deleteFavorites) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_deleteButton];

    // Cancel Button at the bottom
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.frame = CGRectMake(20, 250, 280, 50);
    [cancelButton setTitle:@"إلغاء" forState:UIControlStateNormal];
    [cancelButton setTitleColor:WFText() forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    cancelButton.layer.cornerRadius = 10;
    cancelButton.layer.borderWidth = 1;
    cancelButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [cancelButton addTarget:self action:@selector(dismissFavorites) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:cancelButton];
}

- (void)loadFavoritesData {
    [_favoritesTable reloadData];
}

- (void)addCurrentLocationToFavorites {
    // Implement logic to add current location to favorites
    [self dismissFavorites];
}

- (void)editFavorites {
    // Implement logic to edit favorites
}

- (void)deleteFavorites {
    // Implement logic to delete favorites
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return YHManager.shared.savedLocations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FavoriteCell" forIndexPath:indexPath];
    NSDictionary *location = YHManager.shared.savedLocations[indexPath.row];
    cell.textLabel.text = location[@"name"];
    cell.textLabel.textColor = WFText();
    cell.backgroundColor = [UIColor clearColor];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // Implement logic to select a favorite location
    [self dismissFavorites];
}

+ (void)showFavoritesWithCompletion:(void (^)(BOOL success))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (favoritesWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        favoritesWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        favoritesWindow.windowLevel = UIWindowLevelStatusBar + 10.0;
        favoritesWindow.backgroundColor = [UIColor clearColor];
        
        WFFavoritesViewController *vc = [[WFFavoritesViewController alloc] init];
        vc.completionHandler = ^(BOOL success) {
            favoritesWindow.hidden = YES;
            favoritesWindow = nil;
            if (completion) completion(success);
        };
        
        favoritesWindow.rootViewController = vc;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    favoritesWindow.windowScene = scene;
                    break;
                }
            }
        }
        [favoritesWindow makeKeyAndVisible];
    });
}

- (void)dismissFavorites {
    if (favoritesWindow) {
        [UIView animateWithDuration:0.3 animations:^{
            favoritesWindow.alpha = 0;
        } completion:^(BOOL finished) {
            favoritesWindow.hidden = YES;
            favoritesWindow = nil;
        }];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)showToast:(NSString *)message {
    // Placeholder for showToast method
    NSLog(@"Toast: %@", message);
}

- (void)showFavoritesDropdown {
    // Implement logic to show a dropdown with favorite locations
    // For now, just show a toast
    [self showToast:@"عرض قائمة المفضلة"];
}

@end
