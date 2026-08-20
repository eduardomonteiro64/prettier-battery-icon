#import "AppDelegate.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString * const kPrefColorModeKey = @"PrettierBattery_ColorMode";
static NSString * const kPrefTextDisplayKey = @"PrettierBattery_TextDisplay";
static NSString * const kPrefLaunchAtLoginKey = @"PrettierBattery_LaunchAtLogin";

@interface AppDelegate ()
@property (nonatomic, strong) BatteryInfo *latestInfo;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self loadPreferences];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.toolTip = @"Prettier Battery";
    
    self.statusMenu = [[NSMenu alloc] initWithTitle:@"PrettierBattery"];
    self.statusMenu.delegate = self;
    self.statusItem.menu = self.statusMenu;
    
    [BatteryMonitor sharedMonitor].delegate = self;
    [[BatteryMonitor sharedMonitor] startMonitoring];
    
    [self updateStatusItem];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[BatteryMonitor sharedMonitor] stopMonitoring];
}

#pragma mark - Preferences

- (void)loadPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:kPrefColorModeKey]) {
        self.colorMode = (BatteryColorMode)[defaults integerForKey:kPrefColorModeKey];
    } else {
        self.colorMode = BatteryColorModeDynamic;
    }
    
    if ([defaults objectForKey:kPrefTextDisplayKey]) {
        self.textDisplay = (BatteryTextDisplay)[defaults integerForKey:kPrefTextDisplayKey];
    } else {
        self.textDisplay = BatteryTextDisplayPercentage;
    }
}

- (void)savePreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.colorMode forKey:kPrefColorModeKey];
    [defaults setInteger:self.textDisplay forKey:kPrefTextDisplayKey];
    [defaults synchronize];
}

#pragma mark - Battery Monitor Delegate

- (void)batteryMonitorDidUpdateInfo:(BatteryInfo *)info {
    self.latestInfo = info;
    [self updateStatusItem];
}

#pragma mark - UI Update

- (void)updateStatusItem {
    if (!self.latestInfo) {
        self.latestInfo = [[BatteryMonitor sharedMonitor] fetchCurrentInfo];
    }
    
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;
    
    // 1. Icon configuration
    if (self.textDisplay == BatteryTextDisplayPercentageOnly) {
        button.image = nil;
        button.imagePosition = NSNoImage;
    } else {
        BOOL hasText = (self.textDisplay != BatteryTextDisplayNone);
        NSImage *icon = [BatteryIconRenderer renderIconForBatteryInfo:self.latestInfo
                                                           colorMode:self.colorMode
                                                  hasTrailingSpacing:hasText];
        button.image = icon;
        button.imagePosition = (self.textDisplay == BatteryTextDisplayNone) ? NSImageOnly : NSImageLeft;
    }
    
    // 2. Text configuration with exact system menu bar font
    if (self.textDisplay == BatteryTextDisplayNone) {
        button.title = @"";
        button.attributedTitle = [[NSAttributedString alloc] initWithString:@""];
    } else {
        NSString *textString = nil;
        if (self.textDisplay == BatteryTextDisplayPercentage || self.textDisplay == BatteryTextDisplayPercentageOnly) {
            textString = [NSString stringWithFormat:@"%ld%%", (long)self.latestInfo.percentage];
        } else if (self.textDisplay == BatteryTextDisplayTimeRemaining) {
            if (self.latestInfo.timeRemainingMinutes > 0) {
                NSInteger h = self.latestInfo.timeRemainingMinutes / 60;
                NSInteger m = self.latestInfo.timeRemainingMinutes % 60;
                textString = [NSString stringWithFormat:@"%ld:%02ld", (long)h, (long)m];
            } else {
                textString = [NSString stringWithFormat:@"%ld%%", (long)self.latestInfo.percentage];
            }
        }
        
        if (textString && textString.length > 0) {
            // System menu bar font (13pt with monospaced digits, identical to system date/time)
            NSFont *font = [NSFont monospacedDigitSystemFontOfSize:13.0 weight:NSFontWeightRegular];
            NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
            
            if (self.colorMode == BatteryColorModeDynamic) {
                attrs[NSForegroundColorAttributeName] = [NSColor whiteColor];
            }
            
            button.attributedTitle = [[NSAttributedString alloc] initWithString:textString attributes:attrs];
        } else {
            button.title = @"";
            button.attributedTitle = [[NSAttributedString alloc] initWithString:@""];
        }
    }
}

#pragma mark - Menu Delegate & Construction

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    
    BatteryInfo *info = self.latestInfo ?: [[BatteryMonitor sharedMonitor] fetchCurrentInfo];
    
    // 1. Custom Header View
    NSMenuItem *headerItem = [[NSMenuItem alloc] init];
    NSView *headerView = [self createHeaderViewForInfo:info];
    headerItem.view = headerView;
    [menu addItem:headerItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 2. Battery Hardware Stats
    NSMenuItem *statsParent = [[NSMenuItem alloc] initWithTitle:@"Battery Statistics" action:nil keyEquivalent:@""];
    NSMenu *statsSubmenu = [[NSMenu alloc] initWithTitle:@"Battery Statistics"];
    
    NSString *healthStr;
    if (info.healthPercentage > 0) {
        healthStr = [NSString stringWithFormat:@"Battery Health: %ld%% (%@)", (long)info.healthPercentage, info.condition ?: @"Normal"];
    } else {
        healthStr = @"Battery Health: Calculating...";
    }
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:healthStr action:nil keyEquivalent:@""]];
    
    if (info.cycleCount > 0) {
        NSString *cycleStr = [NSString stringWithFormat:@"Cycle Count: %ld", (long)info.cycleCount];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:cycleStr action:nil keyEquivalent:@""]];
    }
    
    if (info.powerWatts > 0.01) {
        NSString *powerStr = [NSString stringWithFormat:@"Power Draw / Rate: %.1f W", info.powerWatts];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:powerStr action:nil keyEquivalent:@""]];
    }
    
    if (info.voltageVolts > 0.1) {
        NSString *voltStr = [NSString stringWithFormat:@"Voltage: %.2f V (%.0f mA)", info.voltageVolts, fabs(info.amperageAmps * 1000.0)];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:voltStr action:nil keyEquivalent:@""]];
    }
    
    NSString *sourceStr = [NSString stringWithFormat:@"Power Source: %@", info.powerSourceDescription];
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:sourceStr action:nil keyEquivalent:@""]];
    
    statsParent.submenu = statsSubmenu;
    [menu addItem:statsParent];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 3. Color Scheme Submenu
    NSMenuItem *colorParent = [[NSMenuItem alloc] initWithTitle:@"Color Scheme" action:nil keyEquivalent:@""];
    NSMenu *colorSubmenu = [[NSMenu alloc] initWithTitle:@"Color Scheme"];
    
    NSArray *colorOptions = @[
        @{@"title": @"Dynamic (Green / Yellow / Red)", @"mode": @(BatteryColorModeDynamic)},
        @{@"title": @"Native Monochrome (Auto Light/Dark)", @"mode": @(BatteryColorModeMonochrome)}
    ];
    
    for (NSDictionary *opt in colorOptions) {
        BatteryColorMode mode = [opt[@"mode"] integerValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:opt[@"title"]
                                                      action:@selector(selectColorModeAction:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = mode;
        item.state = (self.colorMode == mode) ? NSControlStateValueOn : NSControlStateValueOff;
        [colorSubmenu addItem:item];
    }
    colorParent.submenu = colorSubmenu;
    [menu addItem:colorParent];
    
    // 4. Menu Bar Display Submenu
    NSMenuItem *textParent = [[NSMenuItem alloc] initWithTitle:@"Menu Bar Display" action:nil keyEquivalent:@""];
    NSMenu *textSubmenu = [[NSMenu alloc] initWithTitle:@"Menu Bar Display"];
    
    NSArray *textNames = @[
        @"Icon Only",
        @"Icon + Percentage",
        @"Icon + Time Remaining",
        @"Percentage Only"
    ];
    
    for (NSInteger i = 0; i < textNames.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:textNames[i]
                                                      action:@selector(selectTextDisplayAction:)
                                               keyEquivalent:@""];
        item.target = self;
        item.tag = i;
        item.state = (self.textDisplay == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [textSubmenu addItem:item];
    }
    textParent.submenu = textSubmenu;
    [menu addItem:textParent];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 5. Launch at login
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
                                                       action:@selector(toggleLaunchAtLoginAction:)
                                                keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];
    
    // 6. Hide default macOS battery tip
    NSMenuItem *hideTipItem = [[NSMenuItem alloc] initWithTitle:@"How to Hide Default macOS Battery..."
                                                         action:@selector(showHideDefaultBatteryGuideAction:)
                                                  keyEquivalent:@""];
    hideTipItem.target = self;
    [menu addItem:hideTipItem];
    
    // 7. Open System Battery Settings
    NSMenuItem *sysSettingsItem = [[NSMenuItem alloc] initWithTitle:@"System Battery Settings..."
                                                             action:@selector(openSystemBatterySettingsAction:)
                                                      keyEquivalent:@""];
    sysSettingsItem.target = self;
    [menu addItem:sysSettingsItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 8. Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Prettier Battery"
                                                      action:@selector(quitAction:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
}

#pragma mark - Custom Header View

- (NSView *)createHeaderViewForInfo:(BatteryInfo *)info {
    NSRect frame = NSMakeRect(0, 0, 240, 72);
    NSView *view = [[NSView alloc] initWithFrame:frame];
    
    // Percentage Label
    NSTextField *percentLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 38, 110, 28)];
    percentLabel.editable = NO;
    percentLabel.bordered = NO;
    percentLabel.backgroundColor = [NSColor clearColor];
    percentLabel.font = [NSFont systemFontOfSize:24 weight:NSFontWeightBold];
    percentLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)info.percentage];
    [view addSubview:percentLabel];
    
    // State Badge
    NSTextField *stateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 20, 208, 16)];
    stateLabel.editable = NO;
    stateLabel.bordered = NO;
    stateLabel.backgroundColor = [NSColor clearColor];
    stateLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    stateLabel.stringValue = [info formattedStateString];
    [view addSubview:stateLabel];
    
    // Time remaining label
    NSTextField *timeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 4, 208, 14)];
    timeLabel.editable = NO;
    timeLabel.bordered = NO;
    timeLabel.backgroundColor = [NSColor clearColor];
    timeLabel.textColor = [NSColor secondaryLabelColor];
    timeLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    timeLabel.stringValue = [info formattedTimeRemaining];
    [view addSubview:timeLabel];
    
    return view;
}

#pragma mark - Actions

- (void)selectColorModeAction:(NSMenuItem *)sender {
    self.colorMode = (BatteryColorMode)sender.tag;
    [self savePreferences];
    [self updateStatusItem];
}

- (void)selectTextDisplayAction:(NSMenuItem *)sender {
    self.textDisplay = (BatteryTextDisplay)sender.tag;
    [self savePreferences];
    [self updateStatusItem];
}

- (BOOL)isLaunchAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        return (service.status == SMAppServiceStatusEnabled);
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPrefLaunchAtLoginKey];
}

- (void)toggleLaunchAtLoginAction:(NSMenuItem *)sender {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (service.status == SMAppServiceStatusEnabled) {
            [service unregisterAndReturnError:&error];
        } else {
            [service registerAndReturnError:&error];
        }
        [[NSUserDefaults standardUserDefaults] setBool:(service.status == SMAppServiceStatusEnabled) forKey:kPrefLaunchAtLoginKey];
    } else {
        BOOL current = [[NSUserDefaults standardUserDefaults] boolForKey:kPrefLaunchAtLoginKey];
        [[NSUserDefaults standardUserDefaults] setBool:!current forKey:kPrefLaunchAtLoginKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)showHideDefaultBatteryGuideAction:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"How to hide the default macOS battery icon:";
    alert.informativeText = @"1. Open 'System Settings' on your Mac.\n2. Go to 'Control Center'.\n3. Scroll down to 'Battery' and select 'Don't Show in Menu Bar'.\n\nNow only the clean Prettier Battery icon will appear in your menu bar!";
    [alert addButtonWithTitle:@"Got it"];
    [alert addButtonWithTitle:@"Open Control Center"];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.ControlCenter-Settings.extension"];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openSystemBatterySettingsAction:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.battery"];
    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/Battery.prefPane"]];
    }
}

- (void)quitAction:(id)sender {
    [NSApp terminate:nil];
}

@end
