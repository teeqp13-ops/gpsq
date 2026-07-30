#import "WFGPXMovementManager.h"

@interface WFGPXParser : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@end

@implementation WFGPXParser
- (instancetype)init { if ((self = [super init])) _points = [NSMutableArray array]; return self; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    if (![elementName isEqualToString:@"trkpt"] && ![elementName isEqualToString:@"rtept"] && ![elementName isEqualToString:@"wpt"]) return;
    double lat = [attributeDict[@"lat"] doubleValue];
    double lon = [attributeDict[@"lon"] doubleValue];
    CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
    if (CLLocationCoordinate2DIsValid(c)) [self.points addObject:[NSValue value:&c withObjCType:@encode(CLLocationCoordinate2D)]];
}
@end

@interface WFGPXMovementManager ()
@property (nonatomic, strong) NSArray<NSValue *> *points;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) NSUInteger segmentIndex;
@property (nonatomic, assign) CLLocationDistance segmentProgress;
@property (nonatomic, assign) CLLocationSpeed speed;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@end

@implementation WFGPXMovementManager

- (instancetype)init {
    if ((self = [super init])) _loops = NO;
    return self;
}

- (NSUInteger)pointCount { return self.points.count; }

- (BOOL)loadGPXData:(NSData *)data error:(NSError **)error {
    [self stop];
    WFGPXParser *delegate = [WFGPXParser new];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data ?: NSData.data];
    parser.delegate = delegate;
    BOOL parsed = [parser parse];
    if (!parsed || delegate.points.count < 2) {
        if (error) *error = parser.parserError ?: [NSError errorWithDomain:@"WFGPX" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GPX requires at least two valid points"}];
        self.points = @[];
        return NO;
    }
    self.points = delegate.points.copy;
    self.segmentIndex = 0;
    self.segmentProgress = 0;
    return YES;
}

- (CLLocationCoordinate2D)coordinateAtIndex:(NSUInteger)index {
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    if (index < self.points.count) [self.points[index] getValue:&coordinate];
    return coordinate;
}

- (void)startWithSpeedMetersPerSecond:(CLLocationSpeed)speed {
    if (self.points.count < 2) return;
    [self stop];
    self.speed = MAX(0.5, MIN(speed, 120.0));
    self.running = YES;
    self.segmentIndex = MIN(self.segmentIndex, self.points.count - 2);
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stop {
    [self.timer invalidate];
    self.timer = nil;
    self.running = NO;
}

- (void)tick:(NSTimer *)timer {
    if (!self.running || self.points.count < 2) return;
    CLLocationCoordinate2D from = [self coordinateAtIndex:self.segmentIndex];
    CLLocationCoordinate2D to = [self coordinateAtIndex:self.segmentIndex + 1];
    CLLocation *fromLocation = [[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude];
    CLLocation *toLocation = [[CLLocation alloc] initWithLatitude:to.latitude longitude:to.longitude];
    CLLocationDistance distance = MAX([fromLocation distanceFromLocation:toLocation], 0.01);
    self.segmentProgress += self.speed * timer.timeInterval;

    while (self.segmentProgress >= distance) {
        self.segmentProgress -= distance;
        self.segmentIndex += 1;
        if (self.segmentIndex >= self.points.count - 1) {
            if (self.loops) {
                self.segmentIndex = 0;
                self.segmentProgress = 0;
            } else {
                CLLocationCoordinate2D finalCoordinate = [self coordinateAtIndex:self.points.count - 1];
                if (self.coordinateHandler) self.coordinateHandler(finalCoordinate);
                [self stop];
                if (self.completionHandler) self.completionHandler();
                return;
            }
        }
        from = [self coordinateAtIndex:self.segmentIndex];
        to = [self coordinateAtIndex:self.segmentIndex + 1];
        fromLocation = [[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude];
        toLocation = [[CLLocation alloc] initWithLatitude:to.latitude longitude:to.longitude];
        distance = MAX([fromLocation distanceFromLocation:toLocation], 0.01);
    }

    double ratio = MIN(MAX(self.segmentProgress / distance, 0.0), 1.0);
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(from.latitude + (to.latitude - from.latitude) * ratio,
                                                                    from.longitude + (to.longitude - from.longitude) * ratio);
    if (self.coordinateHandler) self.coordinateHandler(coordinate);
}

@end
