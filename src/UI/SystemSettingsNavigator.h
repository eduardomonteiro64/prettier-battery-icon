#import <Cocoa/Cocoa.h>
#import "BatteryProtocols.h"

/// Handles macOS System Settings navigation and user guidance dialogs.
@interface SystemSettingsNavigator : NSObject

- (instancetype)initWithLocalizer:(id<Localizing>)localizer NS_DESIGNATED_INITIALIZER;
- (void)showHideDefaultBatteryGuide;
- (void)openSystemBatterySettings;

@end
