#import "SystemSettingsNavigator.h"

@interface SystemSettingsNavigator ()
@property (nonatomic, strong) id<Localizing> localizer;
@end

@implementation SystemSettingsNavigator

- (instancetype)init {
    return [self initWithLocalizer:nil];
}

- (instancetype)initWithLocalizer:(id<Localizing>)localizer {
    self = [super init];
    if (self) {
        _localizer = localizer;
    }
    return self;
}

- (void)showHideDefaultBatteryGuide {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [self.localizer localizedStringForKey:@"How to hide the default macOS battery icon:"];
    alert.informativeText = [self.localizer localizedStringForKey:@"1. Open 'System Settings' on your Mac.\n2. Go to 'Control Center'.\n3. Scroll down to 'Battery' and select 'Don't Show in Menu Bar'.\n\nNow only the clean Prettier Battery icon will appear in your menu bar!"];
    [alert addButtonWithTitle:[self.localizer localizedStringForKey:@"Got it"]];
    [alert addButtonWithTitle:[self.localizer localizedStringForKey:@"Open Control Center"]];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.ControlCenter-Settings.extension"];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openSystemBatterySettings {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.battery"];
    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Battery.prefPane"]];
    }
}

@end
