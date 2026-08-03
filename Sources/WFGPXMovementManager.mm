#import "WFGPXMovementManager.h"

@interface WFGPXMovementManager () <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray<NSValue *> *mutableCoordinates;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) WFGPXCoordinateHandler handler;
@property (nonatomic, assign) NSUInteger currentIndex;
@property (nonatomic, assign, readwrite, getter=isRunning) BOOL running;
@end

@implementation WFGPXMovementManager

+ (instancetype)shared {
    static WFGPXMovementManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WFGPXMovementManager new]; });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableCoordinates = [NSMutableArray array];
        _speedMetersPerSecond = 5.0;
    }
    return self;
}

- (BOOL)loadGPXData:(NSData *)data error:(NSError **)error {
    [self stop];
    [self.mutableCoordinates removeAllObjects];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    BOOL ok = [parser parse];
    if (!ok && error) *error = parser.parserError;
    return ok && self.mutableCoordinates.count > 1;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    if (![elementName isEqualToString:@"trkpt"] && ![elementName isEqualToString:@"rtept"] && ![elementName isEqualToString:@"wpt"]) return;
    double latitude = [attributeDict[@"lat"] doubleValue];
    double longitude = [attributeDict[@"lon"] doubleValue];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    if (CLLocationCoordinate2DIsValid(coordinate)) [self.mutableCoordinates addObject:[NSValue valueWithMKCoordinate:coordinate]];
}

- (void)startWithHandler:(WFGPXCoordinateHandler)handler {
    if (self.mutableCoordinates.count < 2 || !handler) return;
    self.handler = handler;
    self.running = YES;
    NSTimeInterval interval = MAX(0.20, MIN(2.0, 5.0 / MAX(self.speedMetersPerSecond, 0.5)));
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self tick];
}

- (void)tick {
    if (!self.running || self.mutableCoordinates.count == 0) return;
    CLLocationCoordinate2D coordinate = self.mutableCoordinates[self.currentIndex].MKCoordinateValue;
    if (self.handler) self.handler(coordinate);
    self.currentIndex = (self.currentIndex + 1) % self.mutableCoordinates.count;
}

- (void)pause { self.running = NO; [self.timer invalidate]; self.timer = nil; }
- (void)stop { [self pause]; self.currentIndex = 0; self.handler = nil; }

@end
