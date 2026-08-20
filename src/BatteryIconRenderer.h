#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"

@interface BatteryIconRenderer : NSObject

+ (NSImage *)renderIconForBatteryInfo:(BatteryInfo *)info
                            colorMode:(BatteryColorMode)colorMode
                   hasTrailingSpacing:(BOOL)hasTrailingSpacing;

@end
