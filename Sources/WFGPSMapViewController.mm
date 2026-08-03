//
//  WFGPSMapViewController.mm
//  Wolf GPS — منطق الخريطة المطور
//

#import "WFGPSMapViewController.h"

@implementation WFGPSMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0];

    // إنشاء الخريطة
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeSatellite;
    self.mapView.showsUserLocation = NO;
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.mapView];

    // إعداد Location Manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager requestWhenInUseAuthorization];

    // تحديد الموقع الأولي (الرياض كمثال افتراضي)
    self.currentCoordinate = CLLocationCoordinate2DMake(24.7136, 46.6753);
    [self setMapLocation:self.currentCoordinate];

    // إضافة Gesture Recognizers
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.mapView addGestureRecognizer:panGesture];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.mapView addGestureRecognizer:doubleTap];

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.mapView addGestureRecognizer:longPress];
}

#pragma mark - Map Operations

- (void)setMapLocation:(CLLocationCoordinate2D)coordinate {
    self.currentCoordinate = coordinate;

    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
    [self.mapView setRegion:region animated:YES];

    // تحديث الـ Pin
    [self.mapView removeAnnotations:self.mapView.annotations];
    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate = coordinate;
    pin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:pin];
}

- (void)startSimulatingMovement {
    if (self.isSimulating) return;
    self.isSimulating = YES;

    [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (!self.isSimulating) {
            [timer invalidate];
            return;
        }

        // تحريك الموقع بشكل عشوائي بسيط للمحاكاة
        int randomLat = (int)arc4random_uniform(100) - 50;
        int randomLng = (int)arc4random_uniform(100) - 50;
        
        double latOffset = randomLat / 100000.0;
        double lngOffset = randomLng / 100000.0;

        CLLocationCoordinate2D newCoord = CLLocationCoordinate2DMake(
            self.currentCoordinate.latitude + latOffset,
            self.currentCoordinate.longitude + lngOffset
        );

        [self setMapLocation:newCoord];
    }];
}

- (void)stopSimulatingMovement {
    self.isSimulating = NO;
}

- (void)setMapType:(MKMapType)mapType {
    self.mapView.mapType = mapType;
}

#pragma mark - Gesture Handlers

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    // منطق إضافي عند سحب الخريطة إذا لزم الأمر
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    MKCoordinateRegion region = self.mapView.region;
    region.span.latitudeDelta /= 2.0;
    region.span.longitudeDelta /= 2.0;
    [self.mapView setRegion:region animated:YES];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint touchPoint = [gesture locationInView:self.mapView];
        CLLocationCoordinate2D coord = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
        [self setMapLocation:coord];
    }
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;

    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"wolf_pin"];
    if (!pinView) {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"wolf_pin"];
        pinView.pinTintColor = [UIColor colorWithRed:0x42/255.0 green:0x85/255.0 blue:0xf4/255.0 alpha:1.0];
        pinView.animatesDrop = YES;
        pinView.canShowCallout = YES;
    } else {
        pinView.annotation = annotation;
    }
    return pinView;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    // لا نقوم بالتحديث التلقائي هنا لتجنب تداخل الموقع الحقيقي مع المزور إلا بطلب المستخدم
}

@end
