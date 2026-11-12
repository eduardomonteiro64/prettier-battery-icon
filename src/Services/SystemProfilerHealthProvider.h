#import <Foundation/Foundation.h>
#import "BatteryProtocols.h"

/// Fetches official battery health percentage and condition via system_profiler.
@interface SystemProfilerHealthProvider : NSObject <BatteryHealthProviding>
@end
