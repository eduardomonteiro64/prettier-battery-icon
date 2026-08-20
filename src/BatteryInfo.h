#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BatteryState) {
    BatteryStateDischarging = 0,
    BatteryStateCharging = 1,
    BatteryStateCharged = 2,
    BatteryStateACAttachedNotCharging = 3,
    BatteryStateWarning = 4,
    BatteryStateMissing = 5,
    BatteryStateUnknown = 6
};

typedef NS_ENUM(NSInteger, BatteryColorMode) {
    BatteryColorModeDynamic = 0,    // Dynamic: Green, Yellow, Red
    BatteryColorModeMonochrome = 1  // Adaptive macOS template (dark/light mode)
};

typedef NS_ENUM(NSInteger, BatteryTextDisplay) {
    BatteryTextDisplayNone = 0,         // Icon only
    BatteryTextDisplayPercentage = 1,   // Icon + "81%"
    BatteryTextDisplayTimeRemaining = 2,// Icon + "4h 12m"
    BatteryTextDisplayPercentageOnly = 3// "81%" without icon
};

@interface BatteryInfo : NSObject

@property (nonatomic, assign) NSInteger currentCapacity;
@property (nonatomic, assign) NSInteger maxCapacity;
@property (nonatomic, assign) NSInteger percentage;
@property (nonatomic, assign) BatteryState state;
@property (nonatomic, assign) BOOL isCharging;
@property (nonatomic, assign) BOOL isACConnected;
@property (nonatomic, assign) BOOL isFullyCharged;
@property (nonatomic, assign) BOOL isWarning;
@property (nonatomic, assign) BOOL isMissing;
@property (nonatomic, assign) NSInteger timeRemainingMinutes; // -1 if calculating / not available
@property (nonatomic, assign) NSInteger cycleCount;
@property (nonatomic, assign) double voltageVolts;
@property (nonatomic, assign) double amperageAmps;
@property (nonatomic, assign) double powerWatts; // Instant power draw / charge rate in Watts
@property (nonatomic, assign) NSInteger healthPercentage;
@property (nonatomic, copy) NSString *condition;
@property (nonatomic, copy) NSString *powerSourceDescription;

- (NSString *)formattedTimeRemaining;
- (NSString *)formattedStateString;

@end
