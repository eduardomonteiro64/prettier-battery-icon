#import <Foundation/Foundation.h>
#import "BatteryProtocols.h"

/// Reads instantaneous battery and power-source telemetry via IOKit (IOPowerSources + AppleSmartBattery).
@interface IOKitBatteryTelemetryProvider : NSObject <BatteryTelemetryProviding>
@end
