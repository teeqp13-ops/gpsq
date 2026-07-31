#import "GPOverlayController.h"
#import "GPSettings.h"
#import "GPLocationEngine.h"
#import <MapKit/MapKit.h>

@interface GPOverlayController () <MKMapViewDelegate, UISearchBarDelegate>
@property(nonatomic,strong) MKMapView *map;
@property(nonatomic,strong) UISwitch *enableSwitch;
@property(nonatomic,strong) UISwitch *driftSwitch;
@end

@implementation GPOverlayController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"GPSPlus MM";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"إغلاق" style:UIBarButtonItemStyleDone target:self action:@selector(close)];

    UISearchBar *search = [UISearchBar new]; search.delegate=self; search.placeholder=@"ابحث عن موقع";
    self.map=[MKMapView new]; self.map.delegate=self;
    [self.map addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];

    UIStackView *controls=[[UIStackView alloc] init]; controls.axis=UILayoutConstraintAxisHorizontal; controls.distribution=UIStackViewDistributionFillEqually;
    self.enableSwitch=[UISwitch new]; self.enableSwitch.on=[GPSettings shared].simulationEnabled;
    self.driftSwitch=[UISwitch new]; self.driftSwitch.on=[GPSettings shared].driftEnabled;
    [self.enableSwitch addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    [self.driftSwitch addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    [controls addArrangedSubview:[self item:@"تشغيل" sw:self.enableSwitch]];
    [controls addArrangedSubview:[self item:@"انحراف" sw:self.driftSwitch]];

    UIStackView *root=[[UIStackView alloc] initWithArrangedSubviews:@[search,self.map,controls]];
    root.axis=UILayoutConstraintAxisVertical; root.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:root];
    [NSLayoutConstraint activateConstraints:@[[root.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[root.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[root.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[root.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[controls.heightAnchor constraintEqualToConstant:74]]];
    CLLocationCoordinate2D c=[GPSettings shared].selectedCoordinate;
    [self.map setRegion:MKCoordinateRegionMakeWithDistance(c,2500,2500) animated:NO];
    [self pin:c];
}
- (UIView *)item:(NSString *)title sw:(UISwitch *)sw { UIStackView *s=[[UIStackView alloc] initWithArrangedSubviews:@[[self label:title],sw]]; s.axis=UILayoutConstraintAxisVertical; s.alignment=UIStackViewAlignmentCenter; return s; }
- (UILabel *)label:(NSString *)t { UILabel *l=[UILabel new]; l.text=t; return l; }
- (void)changed { GPSettings *s=[GPSettings shared]; s.simulationEnabled=self.enableSwitch.on; s.driftEnabled=self.driftSwitch.on; [s save]; s.simulationEnabled ? [[GPLocationEngine shared] start] : [[GPLocationEngine shared] stop]; }
- (void)longPress:(UILongPressGestureRecognizer *)g { if(g.state!=UIGestureRecognizerStateBegan)return; CLLocationCoordinate2D c=[self.map convertPoint:[g locationInView:self.map] toCoordinateFromView:self.map]; [GPSettings shared].selectedCoordinate=c; [[GPSettings shared] save]; [self pin:c]; [[GPLocationEngine shared] applyCoordinate:c]; }
- (void)pin:(CLLocationCoordinate2D)c { [self.map removeAnnotations:self.map.annotations]; MKPointAnnotation *p=[MKPointAnnotation new]; p.coordinate=c; p.title=@"الموقع المختار"; [self.map addAnnotation:p]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; MKLocalSearchRequest *r=[MKLocalSearchRequest new]; r.naturalLanguageQuery=bar.text; MKLocalSearch *s=[[MKLocalSearch alloc] initWithRequest:r]; [s startWithCompletionHandler:^(MKLocalSearchResponse *resp,NSError *err){ MKMapItem *m=resp.mapItems.firstObject; if(!m)return; dispatch_async(dispatch_get_main_queue(), ^{ [self.map setRegion:MKCoordinateRegionMakeWithDistance(m.placemark.coordinate,2500,2500) animated:YES]; }); }]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end
