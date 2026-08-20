#import "BatteryInfo.h"

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
    }
    return self;
}

- (NSString *)formattedTimeRemaining {
    if (self.isFullyCharged) {
        return @"Fully Charged";
    }
    if (self.timeRemainingMinutes < 0) {
        if (self.isCharging) {
            return @"Calculating charge time...";
        } else {
            return @"Calculating time remaining...";
        }
    }
    
    NSInteger hours = self.timeRemainingMinutes / 60;
    NSInteger minutes = self.timeRemainingMinutes % 60;
    
    if (self.isCharging) {
        if (hours > 0) {
            return [NSString stringWithFormat:@"%ldh %02ldm until 100%%", (long)hours, (long)minutes];
        } else {
            return [NSString stringWithFormat:@"%ldm until 100%%", (long)minutes];
        }
    } else {
        if (hours > 0) {
            return [NSString stringWithFormat:@"%ldh %02ldm remaining", (long)hours, (long)minutes];
        } else {
            return [NSString stringWithFormat:@"%ldm remaining", (long)minutes];
        }
    }
}

- (NSString *)formattedStateString {
    if (self.isFullyCharged) {
        return @"Fully Charged (Power Adapter)";
    }
    if (self.isCharging) {
        return @"Charging on AC Power";
    }
    if (self.isACConnected) {
        return @"Connected to Power (Not Charging)";
    }
    return @"On Battery Power";
}

@end
