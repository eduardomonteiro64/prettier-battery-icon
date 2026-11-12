#import <Foundation/Foundation.h>
#import "BatteryProtocols.h"

/// Reads and toggles macOS Low Power Mode via NSProcessInfo / pmset.
@interface LowPowerModeController : NSObject <PowerModeControlling>
@end
