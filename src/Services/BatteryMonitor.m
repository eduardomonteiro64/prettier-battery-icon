#import "BatteryMonitor.h"
#import "IOKitBatteryTelemetryProvider.h"
#import "SystemProfilerHealthProvider.h"
#import "LowPowerModeController.h"
#import <IOKit/ps/IOPowerSources.h>

@interface BatteryMonitor () {
    CFRunLoopSourceRef _powerSourceRunLoopSource;
    NSTimer *_pollTimer;
    NSTimer *_healthRefreshTimer;
    NSInteger _cachedHealthPercentage;
    NSString *_cachedCondition;
}
@property (nonatomic, strong) id<BatteryTelemetryProviding> telemetryProvider;
@property (nonatomic, strong) id<BatteryHealthProviding> healthProvider;
@property (nonatomic, strong) id<PowerModeControlling> powerModeController;
@property (nonatomic, strong, readwrite) BatteryInfo *currentInfo;

- (void)updateAndNotify;
- (void)refreshSystemHealthInBackground;
- (void)powerStateChangedNotification:(NSNotification *)note;

@end

static void PowerSourceCallback(void *context) {
    BatteryMonitor *monitor = (__bridge BatteryMonitor *)context;
    dispatch_async(dispatch_get_main_queue(), ^{
        [monitor updateAndNotify];
    });
}

@implementation BatteryMonitor

+ (instancetype)sharedMonitor {
    static BatteryMonitor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    return [self initWithTelemetryProvider:[[IOKitBatteryTelemetryProvider alloc] init]
                            healthProvider:[[SystemProfilerHealthProvider alloc] init]
                       powerModeController:[[LowPowerModeController alloc] init]];
}

- (instancetype)initWithTelemetryProvider:(id<BatteryTelemetryProviding>)telemetryProvider
                           healthProvider:(id<BatteryHealthProviding>)healthProvider
                      powerModeController:(id<PowerModeControlling>)powerModeController {
    self = [super init];
    if (self) {
        _telemetryProvider = telemetryProvider;
        _healthProvider = healthProvider;
        _powerModeController = powerModeController;
        _currentInfo = [[BatteryInfo alloc] init];
        _cachedHealthPercentage = -1;
        _cachedCondition = @"Normal";
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

- (void)startMonitoring {
    [self refreshSystemHealthInBackground];
    [self updateAndNotify];

    if (!_powerSourceRunLoopSource) {
        _powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(PowerSourceCallback, (__bridge void *)self);
        if (_powerSourceRunLoopSource) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), _powerSourceRunLoopSource, kCFRunLoopDefaultMode);
        }
    }

    if (@available(macOS 12.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(powerStateChangedNotification:)
                                                     name:NSProcessInfoPowerStateDidChangeNotification
                                                   object:nil];
    }

    if (!_pollTimer) {
        _pollTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                      target:self
                                                    selector:@selector(updateAndNotify)
                                                    userInfo:nil
                                                     repeats:YES];
    }

    if (!_healthRefreshTimer) {
        _healthRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:600.0
                                                               target:self
                                                             selector:@selector(refreshSystemHealthInBackground)
                                                             userInfo:nil
                                                              repeats:YES];
    }
}

- (void)stopMonitoring {
    if (_powerSourceRunLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _powerSourceRunLoopSource, kCFRunLoopDefaultMode);
        CFRelease(_powerSourceRunLoopSource);
        _powerSourceRunLoopSource = NULL;
    }
    if (@available(macOS 12.0, *)) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSProcessInfoPowerStateDidChangeNotification
                                                      object:nil];
    }
    if (_pollTimer) {
        [_pollTimer invalidate];
        _pollTimer = nil;
    }
    if (_healthRefreshTimer) {
        [_healthRefreshTimer invalidate];
        _healthRefreshTimer = nil;
    }
}

- (void)powerStateChangedNotification:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAndNotify];
    });
}

- (void)refreshSystemHealthInBackground {
    __weak typeof(self) weakSelf = self;
    [self.healthProvider fetchHealthWithCompletion:^(NSInteger maxCapacityPercent, NSString *condition) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (maxCapacityPercent > 0) {
            strongSelf->_cachedHealthPercentage = maxCapacityPercent;
            strongSelf->_cachedCondition = condition ?: @"Normal";
            [strongSelf updateAndNotify];
        }
    }];
}

- (BatteryInfo *)fetchCurrentInfo {
    BOOL isLPM = [self.powerModeController isLowPowerModeEnabled];
    return [self.telemetryProvider readTelemetryWithLowPowerMode:isLPM
                                                healthPercentage:_cachedHealthPercentage
                                                       condition:_cachedCondition];
}

- (void)updateAndNotify {
    self.currentInfo = [self fetchCurrentInfo];
    if ([self.delegate respondsToSelector:@selector(batteryMonitorDidUpdateInfo:)]) {
        [self.delegate batteryMonitorDidUpdateInfo:self.currentInfo];
    }
}

@end
