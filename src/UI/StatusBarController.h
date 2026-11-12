#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"
#import "BatteryProtocols.h"
#import "StatusMenuBuilder.h"
#import "SystemSettingsNavigator.h"

/// Coordinates the NSStatusItem presentation and user interactions from the status menu.
@interface StatusBarController : NSObject <NSMenuDelegate, StatusMenuActionHandling>

- (instancetype)initWithBatteryMonitor:(id<BatteryMonitoring>)batteryMonitor
                   powerModeController:(id<PowerModeControlling>)powerModeController
                           preferences:(id<PreferencesStoring>)preferences
                  launchAtLoginService:(id<LaunchAtLoginControlling>)launchAtLoginService
                             localizer:(id<Localizing>)localizer
                          iconRenderer:(id<BatteryIconRendering>)iconRenderer
                           menuBuilder:(StatusMenuBuilder *)menuBuilder
                     settingsNavigator:(SystemSettingsNavigator *)settingsNavigator NS_DESIGNATED_INITIALIZER;

- (void)setupStatusItem;
- (void)updateWithBatteryInfo:(BatteryInfo *)info;
- (void)refreshLocalization;

@end
