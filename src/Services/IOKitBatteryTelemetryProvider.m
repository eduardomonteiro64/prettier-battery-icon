#import "IOKitBatteryTelemetryProvider.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#ifndef kIOMainPortDefault
#define kIOMainPortDefault ((mach_port_t)0)
#endif

@implementation IOKitBatteryTelemetryProvider

- (BatteryInfo *)readTelemetryWithLowPowerMode:(BOOL)isLowPowerMode
                              healthPercentage:(NSInteger)healthPercentage
                                     condition:(NSString *)condition {
    BatteryInfo *info = [[BatteryInfo alloc] init];
    info.isLowPowerMode = isLowPowerMode;

    [self populatePowerSourceInfo:info];
    [self populateSmartBatteryInfo:info
            cachedHealthPercentage:healthPercentage
                   cachedCondition:condition ?: @"Normal"];

    return info;
}

- (void)populatePowerSourceInfo:(BatteryInfo *)info {
    CFTypeRef powerInfo = IOPSCopyPowerSourcesInfo();
    if (!powerInfo) return;

    CFArrayRef powerList = IOPSCopyPowerSourcesList(powerInfo);
    if (powerList) {
        CFIndex count = CFArrayGetCount(powerList);
        for (CFIndex i = 0; i < count; i++) {
            CFTypeRef source = CFArrayGetValueAtIndex(powerList, i);
            CFDictionaryRef desc = IOPSGetPowerSourceDescription(powerInfo, source);
            if (!desc) continue;

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
                NSInteger pct = (NSInteger)round(([curCap doubleValue] / [maxCap doubleValue]) * 100.0);
                info.percentage = MAX(0, MIN(100, pct));
            }

            info.isCharging = [isCharging boolValue];
            info.isACConnected = [state isEqualToString:(__bridge NSString *)CFSTR(kIOPSACPowerValue)];
            info.isFullyCharged = [isCharged boolValue] || (info.percentage >= 100 && info.isACConnected);

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
        CFRelease(powerList);
    }
    CFRelease(powerInfo);
}

- (void)populateSmartBatteryInfo:(BatteryInfo *)info
          cachedHealthPercentage:(NSInteger)cachedHealthPercentage
                 cachedCondition:(NSString *)cachedCondition {
    mach_port_t mainPort = 0;
    if (@available(macOS 12.0, *)) {
        mainPort = kIOMainPortDefault;
    }

    io_service_t service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSmartBattery"));
    if (!service) {
        if (cachedHealthPercentage > 0) {
            info.healthPercentage = cachedHealthPercentage;
            info.condition = cachedCondition;
        }
        return;
    }

    CFMutableDictionaryRef props = NULL;
    if (IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
        NSDictionary *d = (__bridge NSDictionary *)props;
        NSDictionary *batteryData = [d[@"BatteryData"] isKindOfClass:[NSDictionary class]] ? d[@"BatteryData"] : nil;

        info.cycleCount = [d[@"CycleCount"] ?: batteryData[@"CycleCount"] integerValue];

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

        NSString *serial = batteryData[@"Serial"] ?: d[@"Serial"];
        if ([serial isKindOfClass:[NSString class]] && serial.length > 0) {
            info.serialNumber = serial;
        }

        info.manufacturer = [self parseManufacturerFromDictionary:d batteryData:batteryData];
        info.temperatureCelsius = [self parseTemperatureFromDictionary:d batteryData:batteryData mainPort:mainPort];
        info.adapterWatts = [self parseAdapterWattsFromDictionary:d];

        int32_t rawVolt = [d[@"Voltage"] intValue] ?: [d[@"AppleRawBatteryVoltage"] intValue] ?: [batteryData[@"Voltage"] intValue];
        int32_t rawAmp = [d[@"Amperage"] intValue] ?: [d[@"InstantAmperage"] intValue] ?: [batteryData[@"Amperage"] intValue];

        if (rawVolt > 0) {
            info.voltageVolts = rawVolt / 1000.0;
        }
        info.amperageAmps = rawAmp / 1000.0;
        if (info.voltageVolts > 0) {
            info.powerWatts = fabs(info.voltageVolts * info.amperageAmps);
        }

        if (cachedHealthPercentage > 0) {
            info.healthPercentage = cachedHealthPercentage;
        } else if (info.designCapacity > 0 && info.rawMaxCapacity > 0) {
            double health = ((double)info.rawMaxCapacity / (double)info.designCapacity) * 100.0;
            info.healthPercentage = MIN(100, (NSInteger)round(health));
        } else {
            info.healthPercentage = 100;
        }
        info.condition = cachedCondition;

        CFRelease(props);
    }
    IOObjectRelease(service);
}

- (NSString *)parseManufacturerFromDictionary:(NSDictionary *)d batteryData:(NSDictionary *)batteryData {
    NSData *mfgData = d[@"ManufacturerData"] ?: batteryData[@"MfgData"];
    if ([mfgData isKindOfClass:[NSData class]]) {
        const char *bytes = [mfgData bytes];
        NSUInteger len = [mfgData length];
        NSMutableString *ascii = [NSMutableString string];
        for (NSUInteger k = 0; k < len; k++) {
            char c = bytes[k];
            if (c >= 32 && c <= 126) {
                [ascii appendFormat:@"%c", c];
            }
        }

        NSDictionary<NSString *, NSString *> *vendorTokens = @{
            @"ATL": @"ATL",
            @"SMP": @"Simplo",
            @"Simplo": @"Simplo",
            @"DP": @"Desay",
            @"Desay": @"Desay",
            @"SWD": @"Sunwoda",
            @"Sunwoda": @"Sunwoda",
            @"COS": @"Coslight",
            @"Coslight": @"Coslight"
        };
        for (NSString *token in vendorTokens) {
            if ([ascii containsString:token]) {
                return vendorTokens[token];
            }
        }
        return d[@"DeviceName"] ?: @"Apple";
    }
    return d[@"DeviceName"] ?: @"";
}

- (double)parseTemperatureFromDictionary:(NSDictionary *)d
                             batteryData:(NSDictionary *)batteryData
                                mainPort:(mach_port_t)mainPort {
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
    if (!tempNum) return 0.0;

    double raw = [tempNum doubleValue];
    if (raw > 2000 && raw < 5000) return raw / 100.0;
    if (raw > 200 && raw < 1000) return raw / 10.0;
    if (raw > 0 && raw <= 100) return raw;
    return 0.0;
}

- (NSInteger)parseAdapterWattsFromDictionary:(NSDictionary *)d {
    NSDictionary *adapterDetails = d[@"AdapterDetails"];
    if ([adapterDetails isKindOfClass:[NSDictionary class]]) {
        NSNumber *watts = adapterDetails[@"Watts"] ?: adapterDetails[@"Wattage"] ?: adapterDetails[@"Power"];
        if (watts && [watts integerValue] > 0) {
            return [watts integerValue];
        }
    }

    NSArray *rawAdapter = d[@"AppleRawAdapterDetails"];
    if ([rawAdapter isKindOfClass:[NSArray class]] && rawAdapter.count > 0) {
        NSDictionary *ad = rawAdapter.firstObject;
        if ([ad isKindOfClass:[NSDictionary class]]) {
            NSNumber *watts = ad[@"Watts"] ?: ad[@"Wattage"];
            if (watts && [watts integerValue] > 0) {
                return [watts integerValue];
            }
        }
    }
    return 0;
}

@end
