#import <Cocoa/Cocoa.h>
#import "BatteryMonitor.h"
#import "BatteryIconRenderer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, BatteryMonitorDelegate, NSMenuDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, assign) BatteryColorMode colorMode;
@property (nonatomic, assign) BatteryTextDisplay textDisplay;

@end
