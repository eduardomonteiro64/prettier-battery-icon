#import "BatteryInfo.h"
#import "LocalizationManager.h"

@implementation BatteryInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        _percentage = 100;
        _state = BatteryStateUnknown;
        _timeRemainingMinutes = -1;
        _healthPercentage = -1;
        _condition = @"Normal";
        _powerSourceDescription = @"Battery";
        _isLowPowerMode = NO;
        _rawMaxCapacity = 0;
        _designCapacity = 0;
        _temperatureCelsius = 0.0;
        _adapterWatts = 0;
        _serialNumber = @"";
        _manufacturer = @"";
    }
    return self;
}

- (NSString *)formattedTimeRemaining {
    if (self.isFullyCharged) {
        return PBLocalizedString(@"Fully Charged", nil);
    }
    if (self.timeRemainingMinutes < 0) {
        if (self.isCharging) {
            return PBLocalizedString(@"Calculating charge time...", nil);
        } else {
            return PBLocalizedString(@"Calculating time remaining...", nil);
        }
    }
    
    NSInteger hours = self.timeRemainingMinutes / 60;
    NSInteger minutes = self.timeRemainingMinutes % 60;
    
    if (self.isCharging) {
        if (hours > 0) {
            return [NSString stringWithFormat:PBLocalizedString(@"%ldh %02ldm until 100%%", nil), (long)hours, (long)minutes];
        } else {
            return [NSString stringWithFormat:PBLocalizedString(@"%ldm until 100%%", nil), (long)minutes];
        }
    } else {
        if (hours > 0) {
            return [NSString stringWithFormat:PBLocalizedString(@"%ldh %02ldm remaining", nil), (long)hours, (long)minutes];
        } else {
            return [NSString stringWithFormat:PBLocalizedString(@"%ldm remaining", nil), (long)minutes];
        }
    }
}

- (NSString *)formattedStateString {
    NSString *baseState;
    if (self.isFullyCharged) {
        baseState = PBLocalizedString(@"Fully Charged (Power Adapter)", nil);
    } else if (self.isCharging) {
        baseState = PBLocalizedString(@"Charging on AC Power", nil);
    } else if (self.isACConnected) {
        baseState = PBLocalizedString(@"Connected to Power (Not Charging)", nil);
    } else {
        baseState = PBLocalizedString(@"On Battery Power", nil);
    }
    
    if (self.isLowPowerMode) {
        return [NSString stringWithFormat:@"%@ • %@", baseState, PBLocalizedString(@"Low Power Mode", nil)];
    }
    return baseState;
}

@end

