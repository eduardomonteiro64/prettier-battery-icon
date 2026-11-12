#import <Foundation/Foundation.h>
#import "BatteryProtocols.h"

/// Manages Launch at Login registration via SMAppService (macOS 13+) with NSUserDefaults fallback.
@interface LaunchAtLoginService : NSObject <LaunchAtLoginControlling>
@end
