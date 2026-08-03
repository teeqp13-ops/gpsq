#import "WFFavoritesViewController.h"
#import "WFGPSFavoritesManager.h"
#import "WFThemeManager.h"
#import "WFLocalization.h"

@interface WFFavoritesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<NSDictionary *> *favorites;
@end

@implementation WFFavoritesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [[WFLocalization shared] text:@"favorites"];
    self.view.backgroundColor = [[WFThemeManager shared] backgroundColor];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadFavorites]; }
- (void)reloadFavorites { self.favorites = [[WFGPSFavoritesManager shared] getAllFavorites]; [self.tableView reloadData]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.favorites.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"favorite"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"favorite"];
    NSDictionary *item = self.favorites[indexPath.row];
    cell.textLabel.text = item[@"name"] ?: @"Location";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", [item[@"latitude"] doubleValue], [item[@"longitude"] doubleValue]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.favorites[indexPath.row];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([item[@"latitude"] doubleValue], [item[@"longitude"] doubleValue]);
    if (self.selectionHandler) self.selectionHandler(coordinate, item[@"name"] ?: @"Location");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:[[WFLocalization shared] text:@"delete"] handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[WFGPSFavoritesManager shared] removeFavoriteAtIndex:indexPath.row];
        [weakSelf reloadFavorites];
        completionHandler(YES);
    }];
    UIContextualAction *editAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:[[WFLocalization shared] text:@"edit"] handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView, void (^completionHandler)(BOOL)) {
        NSDictionary *item = weakSelf.favorites[indexPath.row];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[[WFLocalization shared] text:@"edit"] message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.text = item[@"name"]; }];
        [alert addAction:[UIAlertAction actionWithTitle:[[WFLocalization shared] text:@"save"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *save) {
            [[WFGPSFavoritesManager shared] updateFavoriteAtIndex:indexPath.row name:alert.textFields.firstObject.text coordinate:CLLocationCoordinate2DMake([item[@"latitude"] doubleValue], [item[@"longitude"] doubleValue])];
            [weakSelf reloadFavorites];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:[[WFLocalization shared] text:@"close"] style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, editAction]];
}

@end
