#import "BatteryMonitor.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#ifndef kIOMainPortDefault
#define kIOMainPortDefault ((mach_port_t)0)
#endif

@interface BatteryMonitor () {
    CFRunLoopSourceRef _powerSourceRunLoopSource;
    NSTimer *_pollTimer;
    NSTimer *_healthRefreshTimer;
    NSInteger _cachedHealthPercentage;
    NSString *_cachedCondition;
    BOOL _isFetchingHealth;
}
@property (nonatomic, strong) BatteryInfo *currentInfo;

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
    self = [super init];
    if (self) {
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
    // Initial fetch of system health in background
    [self refreshSystemHealthInBackground];
    [self updateAndNotify];
    
    if (!_powerSourceRunLoopSource) {
        _powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource(PowerSourceCallback, (__bridge void *)self);
        if (_powerSourceRunLoopSource) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), _powerSourceRunLoopSource, kCFRunLoopDefaultMode);
        }
    }
    
    // Register for system Low Power Mode state changes
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
        // Refresh battery health metric every 10 minutes
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

+ (BOOL)isLowPowerModeEnabled {
    if (@available(macOS 12.0, *)) {
        return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    }
    
    // Fallback: check pmset -g
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/pmset";
    task.arguments = @[@"-g"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    @try {
        [task launch];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange range = [outStr rangeOfString:@"lowpowermode"];
        if (range.location != NSNotFound) {
            NSString *sub = [outStr substringFromIndex:range.location];
            NSScanner *scanner = [NSScanner scannerWithString:sub];
            [scanner scanString:@"lowpowermode" intoString:NULL];
            NSInteger val = 0;
            if ([scanner scanInteger:&val]) {
                return val == 1;
            }
        }
    } @catch (NSException *e) {}
    return NO;
}

+ (void)setLowPowerModeEnabled:(BOOL)enabled completion:(void(^)(BOOL success, NSString *errorMessage))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *script = [NSString stringWithFormat:@"do shell script \"pmset -a lowpowermode %d\" with administrator privileges", enabled ? 1 : 0];
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
        NSDictionary *errorInfo = nil;
        NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorInfo];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL success = (result != nil && errorInfo == nil);
            NSString *err = errorInfo ? errorInfo[NSAppleScriptErrorMessage] : nil;
            [[BatteryMonitor sharedMonitor] updateAndNotify];
            if (completion) {
                completion(success, err);
            }
        });
    });
}

- (void)refreshSystemHealthInBackground {
    if (_isFetchingHealth) return;
    _isFetchingHealth = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSInteger maxCapacityPercent = -1;
        NSString *condition = @"Normal";
        
        @try {
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/usr/sbin/system_profiler";
            task.arguments = @[@"SPPowerDataType", @"-json"];
            
            NSPipe *pipe = [NSPipe pipe];
            task.standardOutput = pipe;
            [task launch];
            
            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            [task waitUntilExit];
            
            if (data && data.length > 0) {
                NSError *error = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                NSArray *powerList = json[@"SPPowerDataType"];
                
                for (NSDictionary *item in powerList) {
                    NSDictionary *healthInfo = item[@"sppower_battery_health_info"];
                    if (healthInfo) {
                        NSString *maxCapStr = healthInfo[@"sppower_battery_health_maximum_capacity"];
                        if (maxCapStr) {
                            maxCapacityPercent = [maxCapStr stringByReplacingOccurrencesOfString:@"%" withString:@""].integerValue;
                        }
                        if (healthInfo[@"sppower_battery_health"]) {
                            condition = healthInfo[@"sppower_battery_health"];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            // Fallback handled below
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_isFetchingHealth = NO;
            if (maxCapacityPercent > 0) {
                self->_cachedHealthPercentage = maxCapacityPercent;
                self->_cachedCondition = condition;
                [self updateAndNotify];
            }
        });
    });
}

- (BatteryInfo *)fetchCurrentInfo {
    BatteryInfo *info = [[BatteryInfo alloc] init];
    info.isLowPowerMode = [BatteryMonitor isLowPowerModeEnabled];
    
    CFTypeRef powerInfo = IOPSCopyPowerSourcesInfo();
    if (powerInfo) {
        CFArrayRef powerList = IOPSCopyPowerSourcesList(powerInfo);
        if (powerList) {
            CFIndex count = CFArrayGetCount(powerList);
            for (CFIndex i = 0; i < count; i++) {
                CFTypeRef source = CFArrayGetValueAtIndex(powerList, i);
                CFDictionaryRef desc = IOPSGetPowerSourceDescription(powerInfo, source);
                if (desc) {
                    NSDictionary *dict = (__bridge NSDictionary *)desc;
                    
                    NSNumber *curCap = dict[(__bridge NSString *)CFSTR(kIOPSCurrentCapacityKey)];
                    NSNumber *maxCap = dict[(__bridge NSString *)CFSTR(kIOPSMaxCapacityKey)];
                    NSNumber *isCharging = dict[(__bridge NSString *)CFSTR(kIOPSIsChargingKey)];
                    NSNumber *isCharged = dict[(__bridge NSString *)CFSTR(kIOPSIsChargedKey)];
                    NSString *state = dict[(__bridge NSString *)CFSTR(kIOPSPowerSourceStateKey)];
                    NSNumber *timeToEmpty = dict[(__bridge NSString *)CFSTR(kIOPSTimeToEmptyKey)];
                    NSNumber *timeToFull = dict[(__bridge NSString *)CFSTR(kIOPSTimeToFullChargeKey)];
                    
                    if (curCap && maxCap && [maxCap integerValue] > 0) {
                        info.currentCapacity = [curCap integerValue];
                        info.maxCapacity = [maxCap integerValue];
                        info.percentage = (NSInteger)round(([curCap doubleValue] / [maxCap doubleValue]) * 100.0);
                        if (info.percentage > 100) info.percentage = 100;
                        if (info.percentage < 0) info.percentage = 0;
                    }
                    
                    info.isCharging = [isCharging boolValue];
                    info.isFullyCharged = [isCharged boolValue] || (info.percentage >= 100 && [state isEqualToString:(__bridge NSString *)CFSTR(kIOPSACPowerValue)]);
                    info.isACConnected = [state isEqualToString:(__bridge NSString *)CFSTR(kIOPSACPowerValue)];
                    
                    if (info.isFullyCharged) {
                        info.state = BatteryStateCharged;
                        info.timeRemainingMinutes = 0;
                    } else if (info.isCharging) {
                        info.state = BatteryStateCharging;
                        info.timeRemainingMinutes = timeToFull ? [timeToFull integerValue] : -1;
                    } else if (info.isACConnected) {
                        info.state = BatteryStateACAttachedNotCharging;
                        info.timeRemainingMinutes = -1;
                    } else {
                        info.state = BatteryStateDischarging;
                        info.timeRemainingMinutes = timeToEmpty ? [timeToEmpty integerValue] : -1;
                    }
                    
                    info.powerSourceDescription = info.isACConnected ? @"Power Adapter (AC)" : @"Internal Battery";
                    break;
                }
            }
            CFRelease(powerList);
        }
        CFRelease(powerInfo);
    }
    
    // Fetch hardware specifics from AppleSmartBattery
    CFMutableDictionaryRef matching = IOServiceMatching("AppleSmartBattery");
    mach_port_t mainPort = 0;
    if (@available(macOS 12.0, *)) {
        mainPort = kIOMainPortDefault;
    }
    io_service_t service = IOServiceGetMatchingService(mainPort, matching);
    if (service) {
        CFMutableDictionaryRef props = NULL;
        if (IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
            NSDictionary *d = (__bridge NSDictionary *)props;
            NSDictionary *batteryData = [d[@"BatteryData"] isKindOfClass:[NSDictionary class]] ? d[@"BatteryData"] : nil;
            
            // Cycle count
            if (d[@"CycleCount"]) {
                info.cycleCount = [d[@"CycleCount"] integerValue];
            } else if (batteryData[@"CycleCount"]) {
                info.cycleCount = [batteryData[@"CycleCount"] integerValue];
            }
            
            // Capacity
            NSNumber *designCap = batteryData[@"DesignCapacity"] ?: d[@"DesignCapacity"];
            if (designCap && [designCap integerValue] > 0) {
                info.designCapacity = [designCap integerValue];
            }
            NSNumber *nomCap = batteryData[@"NominalChargeCapacity"] ?: batteryData[@"FullChargeCapacity"] ?: d[@"AppleRawMaxCapacity"] ?: d[@"MaxCapacity"];
            if (nomCap && [nomCap integerValue] > 0) {
                info.rawMaxCapacity = [nomCap integerValue];
            }
            NSNumber *rawCurCap = batteryData[@"AppleRawCurrentCapacity"] ?: batteryData[@"RemainingCapacity"] ?: d[@"CurrentCapacity"];
            if (rawCurCap && [rawCurCap integerValue] > 0) {
                info.currentCapacity = [rawCurCap integerValue];
            }
            
            // Serial Number
            NSString *serial = batteryData[@"Serial"] ?: d[@"Serial"];
            if (serial && [serial isKindOfClass:[NSString class]] && serial.length > 0) {
                info.serialNumber = serial;
            }
            
            // Manufacturer
            NSData *mfgData = d[@"ManufacturerData"] ?: batteryData[@"MfgData"];
            if (mfgData && [mfgData isKindOfClass:[NSData class]]) {
                const char *bytes = [mfgData bytes];
                NSUInteger len = [mfgData length];
                NSMutableString *ascii = [NSMutableString string];
                for (NSUInteger k = 0; k < len; k++) {
                    char c = bytes[k];
                    if (c >= 32 && c <= 126) {
                        [ascii appendFormat:@"%c", c];
                    }
                }
                if ([ascii containsString:@"ATL"]) {
                    info.manufacturer = @"ATL";
                } else if ([ascii containsString:@"SMP"] || [ascii containsString:@"Simplo"]) {
                    info.manufacturer = @"Simplo";
                } else if ([ascii containsString:@"DP"] || [ascii containsString:@"Desay"]) {
                    info.manufacturer = @"Desay";
                } else if ([ascii containsString:@"SWD"] || [ascii containsString:@"Sunwoda"]) {
                    info.manufacturer = @"Sunwoda";
                } else if ([ascii containsString:@"COS"] || [ascii containsString:@"Coslight"]) {
                    info.manufacturer = @"Coslight";
                } else if (d[@"DeviceName"]) {
                    info.manufacturer = d[@"DeviceName"];
                } else {
                    info.manufacturer = @"Apple";
                }
            } else if (d[@"DeviceName"]) {
                info.manufacturer = d[@"DeviceName"];
            }
            
            // Temperature
            NSNumber *tempNum = batteryData[@"Temperature"] ?: d[@"Temperature"];
            if (!tempNum) {
                io_service_t packService = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSmartBatteryPack"));
                if (packService) {
                    CFMutableDictionaryRef packProps = NULL;
                    if (IORegistryEntryCreateCFProperties(packService, &packProps, kCFAllocatorDefault, 0) == KERN_SUCCESS && packProps) {
                        NSDictionary *pd = (__bridge NSDictionary *)packProps;
                        NSDictionary *pbData = pd[@"BatteryData"];
                        tempNum = pbData[@"Temperature"] ?: pd[@"Temperature"];
                        CFRelease(packProps);
                    }
                    IOObjectRelease(packService);
                }
            }
            if (tempNum) {
                double raw = [tempNum doubleValue];
                if (raw > 2000 && raw < 5000) {
                    info.temperatureCelsius = raw / 100.0;
                } else if (raw > 200 && raw < 1000) {
                    info.temperatureCelsius = raw / 10.0;
                } else if (raw > 0 && raw <= 100) {
                    info.temperatureCelsius = raw;
                }
            }
            
            // Adapter Watts
            NSDictionary *adapterDetails = d[@"AdapterDetails"];
            if (adapterDetails && [adapterDetails isKindOfClass:[NSDictionary class]]) {
                NSNumber *watts = adapterDetails[@"Watts"] ?: adapterDetails[@"Wattage"] ?: adapterDetails[@"Power"];
                if (watts && [watts integerValue] > 0) {
                    info.adapterWatts = [watts integerValue];
                }
            }
            if (info.adapterWatts == 0) {
                NSArray *rawAdapter = d[@"AppleRawAdapterDetails"];
                if (rawAdapter && [rawAdapter isKindOfClass:[NSArray class]] && rawAdapter.count > 0) {
                    NSDictionary *ad = rawAdapter.firstObject;
                    if ([ad isKindOfClass:[NSDictionary class]]) {
                        NSNumber *watts = ad[@"Watts"] ?: ad[@"Wattage"];
                        if (watts && [watts integerValue] > 0) {
                            info.adapterWatts = [watts integerValue];
                        }
                    }
                }
            }
            
            // Voltage and Amperage (with signed cast)
            int32_t rawVolt = [d[@"Voltage"] intValue] ?: [d[@"AppleRawBatteryVoltage"] intValue] ?: [batteryData[@"Voltage"] intValue];
            int32_t rawAmp = [d[@"Amperage"] intValue] ?: [d[@"InstantAmperage"] intValue] ?: [batteryData[@"Amperage"] intValue];
            
            if (rawVolt > 0) {
                info.voltageVolts = rawVolt / 1000.0;
            }
            info.amperageAmps = rawAmp / 1000.0;
            
            if (info.voltageVolts > 0) {
                info.powerWatts = fabs(info.voltageVolts * info.amperageAmps);
            }
            
            // Health percentage
            if (_cachedHealthPercentage > 0) {
                info.healthPercentage = _cachedHealthPercentage;
                info.condition = _cachedCondition;
            } else {
                if (info.designCapacity > 0 && info.rawMaxCapacity > 0) {
                    double health = ((double)info.rawMaxCapacity / (double)info.designCapacity) * 100.0;
                    info.healthPercentage = (NSInteger)round(health);
                    if (info.healthPercentage > 100) info.healthPercentage = 100;
                } else {
                    info.healthPercentage = 100;
                }
                info.condition = _cachedCondition;
            }
            
            CFRelease(props);
        }
        IOObjectRelease(service);
    } else {
        if (_cachedHealthPercentage > 0) {
            info.healthPercentage = _cachedHealthPercentage;
            info.condition = _cachedCondition;
        }
    }
    
    return info;
}

- (void)updateAndNotify {
    self.currentInfo = [self fetchCurrentInfo];
    if ([self.delegate respondsToSelector:@selector(batteryMonitorDidUpdateInfo:)]) {
        [self.delegate batteryMonitorDidUpdateInfo:self.currentInfo];
    }
}

@end
