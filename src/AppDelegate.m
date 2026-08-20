#import "AppDelegate.h"
#import "LocalizationManager.h"
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
    self.statusItem.button.toolTip = PBLocalizedString(@"Prettier Battery", nil);
    
    self.statusMenu = [[NSMenu alloc] initWithTitle:@"PrettierBattery"];
    self.statusMenu.delegate = self;
    self.statusItem.menu = self.statusMenu;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localizationDidChange:)
                                                 name:kPBLocalizationDidChangeNotification
                                               object:nil];
    
    [BatteryMonitor sharedMonitor].delegate = self;
    [[BatteryMonitor sharedMonitor] startMonitoring];
    
    [self updateStatusItem];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[BatteryMonitor sharedMonitor] stopMonitoring];
}

- (void)localizationDidChange:(NSNotification *)note {
    self.statusItem.button.toolTip = PBLocalizedString(@"Prettier Battery", nil);
    [self updateStatusItem];
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
    
    // Low Power Mode Toggle
    NSMenuItem *lpmItem = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Low Power Mode", nil) action:@selector(toggleLowPowerModeAction:) keyEquivalent:@""];
    lpmItem.target = self;
    lpmItem.state = info.isLowPowerMode ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:lpmItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 2. Battery Hardware Stats
    NSMenuItem *statsParent = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Battery Statistics", nil) action:nil keyEquivalent:@""];
    NSMenu *statsSubmenu = [[NSMenu alloc] initWithTitle:PBLocalizedString(@"Battery Statistics", nil)];
    
    // Health
    NSString *healthStr;
    if (info.healthPercentage > 0) {
        NSString *condLocalized = PBLocalizedString(info.condition ?: @"Normal", nil);
        healthStr = [NSString stringWithFormat:PBLocalizedString(@"Battery Health: %ld%% (%@)", nil), (long)info.healthPercentage, condLocalized];
    } else {
        healthStr = PBLocalizedString(@"Battery Health: Calculating...", nil);
    }
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:healthStr action:nil keyEquivalent:@""]];
    
    // Capacity (Full Charge / Design Capacity)
    if (info.rawMaxCapacity > 0 && info.designCapacity > 0) {
        NSInteger capPct = (NSInteger)round(((double)info.rawMaxCapacity / (double)info.designCapacity) * 100.0);
        NSString *capStr = [NSString stringWithFormat:PBLocalizedString(@"Capacity: %ld / %ld mAh (%ld%%)", nil), (long)info.rawMaxCapacity, (long)info.designCapacity, (long)capPct];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:capStr action:nil keyEquivalent:@""]];
    } else if (info.rawMaxCapacity > 0) {
        NSString *capStr = [NSString stringWithFormat:PBLocalizedString(@"Capacity: %ld mAh", nil), (long)info.rawMaxCapacity];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:capStr action:nil keyEquivalent:@""]];
    }
    
    // Cycle count (current count only)
    if (info.cycleCount > 0) {
        NSString *cycleStr = [NSString stringWithFormat:PBLocalizedString(@"Cycle Count: %ld", nil), (long)info.cycleCount];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:cycleStr action:nil keyEquivalent:@""]];
    }
    
    // Temperature
    if (info.temperatureCelsius > 0.1) {
        NSString *tempStr = [NSString stringWithFormat:PBLocalizedString(@"Temperature: %.1f °C", nil), info.temperatureCelsius];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:tempStr action:nil keyEquivalent:@""]];
    }
    
    [statsSubmenu addItem:[NSMenuItem separatorItem]];
    
    // Power Source & Adapter Watts
    NSString *powerSourceLocalized = PBLocalizedString(info.powerSourceDescription ?: @"Battery", nil);
    NSString *sourceStr;
    if (info.isACConnected && info.adapterWatts > 0) {
        sourceStr = [NSString stringWithFormat:PBLocalizedString(@"Power Source: %@ (%ld W)", nil), powerSourceLocalized, (long)info.adapterWatts];
    } else {
        sourceStr = [NSString stringWithFormat:PBLocalizedString(@"Power Source: %@", nil), powerSourceLocalized];
    }
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:sourceStr action:nil keyEquivalent:@""]];
    
    // Power Draw / Charge Rate with mA
    if (info.powerWatts > 0.01) {
        double mA = info.amperageAmps * 1000.0;
        NSString *mAStr = (mA > 0) ? [NSString stringWithFormat:@"+%.0f mA", mA] : [NSString stringWithFormat:@"%.0f mA", mA];
        NSString *powerStr;
        if (info.isCharging) {
            powerStr = [NSString stringWithFormat:PBLocalizedString(@"Charge Rate: %.1f W (%@)", nil), info.powerWatts, mAStr];
        } else {
            powerStr = [NSString stringWithFormat:PBLocalizedString(@"Power Draw: %.1f W (%@)", nil), info.powerWatts, mAStr];
        }
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:powerStr action:nil keyEquivalent:@""]];
    }
    
    // Voltage
    if (info.voltageVolts > 0.1) {
        NSString *voltStr = [NSString stringWithFormat:PBLocalizedString(@"Voltage: %.2f V", nil), info.voltageVolts];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:voltStr action:nil keyEquivalent:@""]];
    }
    
    // Hardware info (Manufacturer and Serial)
    if (info.serialNumber.length > 0 || info.manufacturer.length > 0) {
        [statsSubmenu addItem:[NSMenuItem separatorItem]];
        if (info.manufacturer.length > 0 && info.serialNumber.length > 0) {
            NSString *hwStr = [NSString stringWithFormat:PBLocalizedString(@"Hardware: %@ (Serial: %@)", nil), info.manufacturer, info.serialNumber];
            [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:hwStr action:nil keyEquivalent:@""]];
        } else if (info.serialNumber.length > 0) {
            NSString *serialStr = [NSString stringWithFormat:PBLocalizedString(@"Serial: %@", nil), info.serialNumber];
            [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:serialStr action:nil keyEquivalent:@""]];
        }
    }
    
    statsParent.submenu = statsSubmenu;
    [menu addItem:statsParent];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 3. Color Scheme Submenu
    NSMenuItem *colorParent = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Color Scheme", nil) action:nil keyEquivalent:@""];
    NSMenu *colorSubmenu = [[NSMenu alloc] initWithTitle:PBLocalizedString(@"Color Scheme", nil)];
    
    NSArray *colorOptions = @[
        @{@"title": PBLocalizedString(@"Dynamic (Green / Yellow / Red)", nil), @"mode": @(BatteryColorModeDynamic)},
        @{@"title": PBLocalizedString(@"Native Monochrome (Auto Light/Dark)", nil), @"mode": @(BatteryColorModeMonochrome)}
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
    NSMenuItem *textParent = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Menu Bar Display", nil) action:nil keyEquivalent:@""];
    NSMenu *textSubmenu = [[NSMenu alloc] initWithTitle:PBLocalizedString(@"Menu Bar Display", nil)];
    
    NSArray *textNames = @[
        PBLocalizedString(@"Icon Only", nil),
        PBLocalizedString(@"Icon + Percentage", nil),
        PBLocalizedString(@"Icon + Time Remaining", nil),
        PBLocalizedString(@"Percentage Only", nil)
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
    
    // 5. Language Submenu
    NSMenuItem *langParent = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Language", nil) action:nil keyEquivalent:@""];
    NSMenu *langSubmenu = [[NSMenu alloc] initWithTitle:PBLocalizedString(@"Language", nil)];
    
    NSString *currentLang = [LocalizationManager sharedManager].languageCode;
    for (NSDictionary<NSString *, NSString *> *lang in [[LocalizationManager sharedManager] supportedLanguages]) {
        NSString *code = lang[@"code"];
        NSString *name = lang[@"name"];
        
        NSMenuItem *langItem = [[NSMenuItem alloc] initWithTitle:name
                                                          action:@selector(selectLanguageAction:)
                                                   keyEquivalent:@""];
        langItem.target = self;
        langItem.representedObject = code;
        langItem.state = [code isEqualToString:currentLang] ? NSControlStateValueOn : NSControlStateValueOff;
        [langSubmenu addItem:langItem];
    }
    langParent.submenu = langSubmenu;
    [menu addItem:langParent];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 6. Launch at login
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Launch at Login", nil)
                                                       action:@selector(toggleLaunchAtLoginAction:)
                                                keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = [self isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];
    
    // 7. Hide default macOS battery tip
    NSMenuItem *hideTipItem = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"How to Hide Default macOS Battery...", nil)
                                                         action:@selector(showHideDefaultBatteryGuideAction:)
                                                  keyEquivalent:@""];
    hideTipItem.target = self;
    [menu addItem:hideTipItem];
    
    // 8. Open System Battery Settings
    NSMenuItem *sysSettingsItem = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"System Battery Settings...", nil)
                                                             action:@selector(openSystemBatterySettingsAction:)
                                                      keyEquivalent:@""];
    sysSettingsItem.target = self;
    [menu addItem:sysSettingsItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 9. Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:PBLocalizedString(@"Quit Prettier Battery", nil)
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

- (void)selectLanguageAction:(NSMenuItem *)sender {
    NSString *code = sender.representedObject;
    if (code) {
        [LocalizationManager sharedManager].languageCode = code;
    }
}

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

- (void)toggleLowPowerModeAction:(NSMenuItem *)sender {
    BOOL targetState = !(self.latestInfo.isLowPowerMode);
    [BatteryMonitor setLowPowerModeEnabled:targetState completion:^(BOOL success, NSString *errorMessage) {
        if (!success && errorMessage && ![errorMessage containsString:@"User canceled"]) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = PBLocalizedString(@"Could Not Toggle Low Power Mode", nil);
            alert.informativeText = errorMessage;
            [alert runModal];
        }
        [self updateStatusItem];
    }];
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
    alert.messageText = PBLocalizedString(@"How to hide the default macOS battery icon:", nil);
    alert.informativeText = PBLocalizedString(@"1. Open 'System Settings' on your Mac.\n2. Go to 'Control Center'.\n3. Scroll down to 'Battery' and select 'Don't Show in Menu Bar'.\n\nNow only the clean Prettier Battery icon will appear in your menu bar!", nil);
    [alert addButtonWithTitle:PBLocalizedString(@"Got it", nil)];
    [alert addButtonWithTitle:PBLocalizedString(@"Open Control Center", nil)];
    
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
