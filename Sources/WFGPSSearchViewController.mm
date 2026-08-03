//
//  WFGPSSearchViewController.mm
//  Wolf GPS — البحث الجيوغرافي المطور
//

#import "WFGPSSearchViewController.h"

@implementation WFGPSSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0];
    self.title = @"ابحث عن موقع";
    
    // إعداد شريط التنقل
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0xc9/255.0 green:0xa2/255.0 blue:0x27/255.0 alpha:1.0];
    
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"إغلاق" style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    self.navigationItem.rightBarButtonItem = closeItem;

    // SearchBar
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"أدخل اسم المدينة أو العنوان...";
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.searchTextField.textColor = [UIColor whiteColor];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];

    // جدول النتائج
    self.resultsTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.resultsTable.dataSource = self;
    self.resultsTable.delegate = self;
    self.resultsTable.backgroundColor = [UIColor colorWithRed:0x0e/255.0 green:0x14/255.0 blue:0x2b/255.0 alpha:1.0];
    self.resultsTable.separatorColor = [UIColor colorWithRed:0x6b/255.0 green:0x74/255.0 blue:0x88/255.0 alpha:0.2];
    self.resultsTable.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.resultsTable];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [self.resultsTable.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.resultsTable.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.resultsTable.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.resultsTable.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.searchResults = [NSMutableArray array];
    self.geocoder = [[CLGeocoder alloc] init];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length < 3) {
        [self.searchResults removeAllObjects];
        [self.resultsTable reloadData];
        return;
    }

    [self.geocoder cancelGeocode];
    [self.geocoder geocodeAddressString:searchText completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (placemarks.count > 0) {
            self.searchResults = [NSMutableArray arrayWithArray:placemarks];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.resultsTable reloadData];
            });
        }
    }];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor colorWithRed:0x0e/255.0 green:0x14/255.0 blue:0x2b/255.0 alpha:1.0];
        cell.textLabel.textColor = [UIColor colorWithRed:0xe8/255.0 green:0xc4/255.0 blue:0x53/255.0 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0x6b/255.0 green:0x74/255.0 blue:0x88/255.0 alpha:1.0];
        
        UIView *selectedBg = [[UIView alloc] init];
        selectedBg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        cell.selectedBackgroundView = selectedBg;
    }

    CLPlacemark *placemark = self.searchResults[indexPath.row];
    cell.textLabel.text = placemark.name ?: @"موقع غير معروف";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", placemark.locality ?: @"", placemark.country ?: @""];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CLPlacemark *placemark = self.searchResults[indexPath.row];
    CLLocationCoordinate2D coordinate = placemark.location.coordinate;

    if (self.onLocationSelected) {
        self.onLocationSelected(coordinate);
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
