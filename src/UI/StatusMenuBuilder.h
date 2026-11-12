#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"
#import "BatteryProtocols.h"

/// Actions triggered by menu items in the Prettier Battery status menu.
@protocol StatusMenuActionHandling <NSObject>
- (void)toggleLowPowerModeAction:(NSMenuItem *)sender;
- (void)selectColorModeAction:(NSMenuItem *)sender;
- (void)selectTextDisplayAction:(NSMenuItem *)sender;
- (void)selectLanguageAction:(NSMenuItem *)sender;
- (void)toggleLaunchAtLoginAction:(NSMenuItem *)sender;
- (void)showHideDefaultBatteryGuideAction:(id)sender;
- (void)openSystemBatterySettingsAction:(id)sender;
- (void)quitAction:(id)sender;
@end

/// Constructs the status bar NSMenu and its submenus/custom views.
@interface StatusMenuBuilder : NSObject

- (instancetype)initWithLocalizer:(id<Localizing>)localizer
                      preferences:(id<PreferencesStoring>)preferences
             launchAtLoginService:(id<LaunchAtLoginControlling>)launchAtLoginService NS_DESIGNATED_INITIALIZER;

- (void)populateMenu:(NSMenu *)menu
            withInfo:(BatteryInfo *)info
       actionHandler:(id<StatusMenuActionHandling>)actionHandler;

@end
