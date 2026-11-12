#import "AppDelegate.h"
#import "BatteryMonitor.h"
#import "BatteryIconRenderer.h"
#import "LocalizationManager.h"
#import "LowPowerModeController.h"
#import "PreferencesStore.h"
#import "LaunchAtLoginService.h"
#import "StatusBarController.h"
#import "StatusMenuBuilder.h"
#import "SystemSettingsNavigator.h"

@interface AppDelegate ()
@property (nonatomic, strong) id<BatteryMonitoring> batteryMonitor;
@property (nonatomic, strong) StatusBarController *statusBarController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    id<Localizing> localizer = [LocalizationManager sharedManager];
    id<PreferencesStoring> preferences = [[PreferencesStore alloc] init];
    id<LaunchAtLoginControlling> launchAtLoginService = [[LaunchAtLoginService alloc] init];
    id<PowerModeControlling> powerModeController = [[LowPowerModeController alloc] init];
    id<BatteryIconRendering> iconRenderer = [[BatteryIconRenderer alloc] init];

    self.batteryMonitor = [BatteryMonitor sharedMonitor];
    self.batteryMonitor.delegate = self;

    StatusMenuBuilder *menuBuilder = [[StatusMenuBuilder alloc] initWithLocalizer:localizer
                                                                      preferences:preferences
                                                             launchAtLoginService:launchAtLoginService];
    SystemSettingsNavigator *settingsNavigator = [[SystemSettingsNavigator alloc] initWithLocalizer:localizer];

    self.statusBarController = [[StatusBarController alloc] initWithBatteryMonitor:self.batteryMonitor
                                                                 powerModeController:powerModeController
                                                                         preferences:preferences
                                                                launchAtLoginService:launchAtLoginService
                                                                           localizer:localizer
                                                                        iconRenderer:iconRenderer
                                                                         menuBuilder:menuBuilder
                                                                   settingsNavigator:settingsNavigator];
    [self.statusBarController setupStatusItem];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localizationDidChange:)
                                                 name:kPBLocalizationDidChangeNotification
                                               object:nil];

    [self.batteryMonitor startMonitoring];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.batteryMonitor stopMonitoring];
}

- (void)localizationDidChange:(NSNotification *)note {
    [self.statusBarController refreshLocalization];
}

#pragma mark - BatteryMonitorDelegate

- (void)batteryMonitorDidUpdateInfo:(BatteryInfo *)info {
    [self.statusBarController updateWithBatteryInfo:info];
}

@end
