#import "WFFavoritesViewController.h"
#import "WFFavoritesStore.h"
#import "WFLocalization.h"
#import "WFThemeManager.h"

@interface WFFavoritesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<WFFavoriteItem *> *items;
@end

@implementation WFFavoritesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [WFLocalization text:@"favorites"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[WFLocalization text:@"close"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    self.view.backgroundColor = [[WFThemeManager shared] backgroundColorForTraitCollection:self.traitCollection];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.tableView];
    [self reloadItems];
}

- (void)reloadItems {
    self.items = [[WFFavoritesStore shared] allItems];
    [self.tableView reloadData];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX((NSInteger)self.items.count, 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"favorite"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"favorite"];
    if (self.items.count == 0) {
        cell.textLabel.text = [WFLocalization text:@"empty_favorites"];
        cell.detailTextLabel.text = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    WFFavoriteItem *item = self.items[indexPath.row];
    cell.textLabel.text = item.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", item.latitude, item.longitude];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.items.count == 0) return;
    WFFavoriteItem *item = self.items[indexPath.row];
    if (self.selectionHandler) self.selectionHandler(item.coordinate);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if (self.items.count == 0) return nil;
    WFFavoriteItem *item = self.items[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:[WFLocalization text:@"delete"] handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        BOOL deleted = [[WFFavoritesStore shared] deleteItem:item];
        [weakSelf reloadItems];
        completionHandler(deleted);
    }];
    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:[WFLocalization text:@"rename"] handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf promptRename:item completion:completionHandler];
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, renameAction]];
}

- (void)promptRename:(WFFavoriteItem *)item completion:(void (^)(BOOL))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[WFLocalization text:@"edit_favorite"] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = item.name;
        field.placeholder = [WFLocalization text:@"name"];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"cancel"] style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completion(NO);
    }]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"done"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        BOOL updated = [[WFFavoritesStore shared] updateItem:item name:alert.textFields.firstObject.text ?: @""];
        [weakSelf reloadItems];
        completion(updated);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
