#import <Foundation/Foundation.h>
#import "BatteryInfo.h"
#import "BatteryProtocols.h"

@interface BatteryMonitor : NSObject <BatteryMonitoring>

@property (nonatomic, weak) id<BatteryMonitorDelegate> delegate;
@property (nonatomic, readonly) BatteryInfo *currentInfo;

+ (instancetype)sharedMonitor;

- (instancetype)initWithTelemetryProvider:(id<BatteryTelemetryProviding>)telemetryProvider
                           healthProvider:(id<BatteryHealthProviding>)healthProvider
                      powerModeController:(id<PowerModeControlling>)powerModeController NS_DESIGNATED_INITIALIZER;

- (void)startMonitoring;
- (void)stopMonitoring;
- (BatteryInfo *)fetchCurrentInfo;

@end
