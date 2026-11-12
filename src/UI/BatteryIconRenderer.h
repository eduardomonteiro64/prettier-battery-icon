#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"
#import "BatteryProtocols.h"

@interface BatteryIconRenderer : NSObject <BatteryIconRendering>

+ (NSImage *)renderIconForBatteryInfo:(BatteryInfo *)info
                            colorMode:(BatteryColorMode)colorMode
                   hasTrailingSpacing:(BOOL)hasTrailingSpacing;

@end
