#import "LaunchAtLoginService.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString * const kPrefLaunchAtLoginKey = @"PrettierBattery_LaunchAtLogin";

@implementation LaunchAtLoginService

- (BOOL)isLaunchAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        return (service.status == SMAppServiceStatusEnabled);
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefLaunchAtLoginKey];
}

- (void)setLaunchAtLoginEnabled:(BOOL)enabled {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (enabled) {
            [service registerAndReturnError:&error];
        } else {
            [service unregisterAndReturnError:&error];
        }
        [[NSUserDefaults standardUserDefaults] setBool:(service.status == SMAppServiceStatusEnabled)
                                                forKey:kPrefLaunchAtLoginKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kPrefLaunchAtLoginKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
