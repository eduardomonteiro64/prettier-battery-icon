#import "StatusMenuBuilder.h"

@interface StatusMenuBuilder ()
@property (nonatomic, strong) id<Localizing> localizer;
@property (nonatomic, strong) id<PreferencesStoring> preferences;
@property (nonatomic, strong) id<LaunchAtLoginControlling> launchAtLoginService;
@end

@implementation StatusMenuBuilder

- (instancetype)init {
    return [self initWithLocalizer:nil preferences:nil launchAtLoginService:nil];
}

- (instancetype)initWithLocalizer:(id<Localizing>)localizer
                      preferences:(id<PreferencesStoring>)preferences
             launchAtLoginService:(id<LaunchAtLoginControlling>)launchAtLoginService {
    self = [super init];
    if (self) {
        _localizer = localizer;
        _preferences = preferences;
        _launchAtLoginService = launchAtLoginService;
    }
    return self;
}

- (NSString *)t:(NSString *)key {
    return [self.localizer localizedStringForKey:key];
}

- (void)populateMenu:(NSMenu *)menu
            withInfo:(BatteryInfo *)info
       actionHandler:(id<StatusMenuActionHandling>)actionHandler {
    [menu removeAllItems];

    NSMenuItem *headerItem = [[NSMenuItem alloc] init];
    headerItem.view = [self createHeaderViewForInfo:info];
    [menu addItem:headerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *lpmItem = [[NSMenuItem alloc] initWithTitle:[self t:@"Low Power Mode"]
                                                     action:@selector(toggleLowPowerModeAction:)
                                              keyEquivalent:@""];
    lpmItem.target = actionHandler;
    lpmItem.state = info.isLowPowerMode ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:lpmItem];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:[self buildStatisticsMenuItemForInfo:info]];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:[self buildColorSchemeMenuItemWithTarget:actionHandler]];
    [menu addItem:[self buildDisplayMenuItemWithTarget:actionHandler]];
    [menu addItem:[self buildLanguageMenuItemWithTarget:actionHandler]];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:[self t:@"Launch at Login"]
                                                       action:@selector(toggleLaunchAtLoginAction:)
                                                keyEquivalent:@""];
    loginItem.target = actionHandler;
    loginItem.state = [self.launchAtLoginService isLaunchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];

    NSMenuItem *hideTipItem = [[NSMenuItem alloc] initWithTitle:[self t:@"How to Hide Default macOS Battery..."]
                                                         action:@selector(showHideDefaultBatteryGuideAction:)
                                                  keyEquivalent:@""];
    hideTipItem.target = actionHandler;
    [menu addItem:hideTipItem];

    NSMenuItem *sysSettingsItem = [[NSMenuItem alloc] initWithTitle:[self t:@"System Battery Settings..."]
                                                             action:@selector(openSystemBatterySettingsAction:)
                                                      keyEquivalent:@""];
    sysSettingsItem.target = actionHandler;
    [menu addItem:sysSettingsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[self t:@"Quit Prettier Battery"]
                                                      action:@selector(quitAction:)
                                               keyEquivalent:@"q"];
    quitItem.target = actionHandler;
    [menu addItem:quitItem];
}

#pragma mark - Submenu Builders

- (NSMenuItem *)buildStatisticsMenuItemForInfo:(BatteryInfo *)info {
    NSMenuItem *statsParent = [[NSMenuItem alloc] initWithTitle:[self t:@"Battery Statistics"] action:nil keyEquivalent:@""];
    NSMenu *statsSubmenu = [[NSMenu alloc] initWithTitle:[self t:@"Battery Statistics"]];

    NSString *healthStr;
    if (info.healthPercentage > 0) {
        NSString *condLocalized = [self t:(info.condition ?: @"Normal")];
        healthStr = [NSString stringWithFormat:[self t:@"Battery Health: %ld%% (%@)"], (long)info.healthPercentage, condLocalized];
    } else {
        healthStr = [self t:@"Battery Health: Calculating..."];
    }
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:healthStr action:nil keyEquivalent:@""]];

    if (info.rawMaxCapacity > 0 && info.designCapacity > 0) {
        NSInteger capPct = (NSInteger)round(((double)info.rawMaxCapacity / (double)info.designCapacity) * 100.0);
        NSString *capStr = [NSString stringWithFormat:[self t:@"Capacity: %ld / %ld mAh (%ld%%)"], (long)info.rawMaxCapacity, (long)info.designCapacity, (long)capPct];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:capStr action:nil keyEquivalent:@""]];
    } else if (info.rawMaxCapacity > 0) {
        NSString *capStr = [NSString stringWithFormat:[self t:@"Capacity: %ld mAh"], (long)info.rawMaxCapacity];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:capStr action:nil keyEquivalent:@""]];
    }

    if (info.cycleCount > 0) {
        NSString *cycleStr = [NSString stringWithFormat:[self t:@"Cycle Count: %ld"], (long)info.cycleCount];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:cycleStr action:nil keyEquivalent:@""]];
    }

    if (info.temperatureCelsius > 0.1) {
        NSString *tempStr = [NSString stringWithFormat:[self t:@"Temperature: %.1f °C"], info.temperatureCelsius];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:tempStr action:nil keyEquivalent:@""]];
    }

    [statsSubmenu addItem:[NSMenuItem separatorItem]];

    NSString *powerSourceLocalized = [self t:(info.powerSourceDescription ?: @"Battery")];
    NSString *sourceStr;
    if (info.isACConnected && info.adapterWatts > 0) {
        sourceStr = [NSString stringWithFormat:[self t:@"Power Source: %@ (%ld W)"], powerSourceLocalized, (long)info.adapterWatts];
    } else {
        sourceStr = [NSString stringWithFormat:[self t:@"Power Source: %@"], powerSourceLocalized];
    }
    [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:sourceStr action:nil keyEquivalent:@""]];

    if (info.powerWatts > 0.01) {
        double mA = info.amperageAmps * 1000.0;
        NSString *mAStr = (mA > 0) ? [NSString stringWithFormat:@"+%.0f mA", mA] : [NSString stringWithFormat:@"%.0f mA", mA];
        NSString *formatKey = info.isCharging ? @"Charge Rate: %.1f W (%@)" : @"Power Draw: %.1f W (%@)";
        NSString *powerStr = [NSString stringWithFormat:[self t:formatKey], info.powerWatts, mAStr];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:powerStr action:nil keyEquivalent:@""]];
    }

    if (info.voltageVolts > 0.1) {
        NSString *voltStr = [NSString stringWithFormat:[self t:@"Voltage: %.2f V"], info.voltageVolts];
        [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:voltStr action:nil keyEquivalent:@""]];
    }

    if (info.serialNumber.length > 0 || info.manufacturer.length > 0) {
        [statsSubmenu addItem:[NSMenuItem separatorItem]];
        if (info.manufacturer.length > 0 && info.serialNumber.length > 0) {
            NSString *hwStr = [NSString stringWithFormat:[self t:@"Hardware: %@ (Serial: %@)"], info.manufacturer, info.serialNumber];
            [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:hwStr action:nil keyEquivalent:@""]];
        } else if (info.serialNumber.length > 0) {
            NSString *serialStr = [NSString stringWithFormat:[self t:@"Serial: %@"], info.serialNumber];
            [statsSubmenu addItem:[[NSMenuItem alloc] initWithTitle:serialStr action:nil keyEquivalent:@""]];
        }
    }

    statsParent.submenu = statsSubmenu;
    return statsParent;
}

- (NSMenuItem *)buildColorSchemeMenuItemWithTarget:(id<StatusMenuActionHandling>)target {
    NSMenuItem *colorParent = [[NSMenuItem alloc] initWithTitle:[self t:@"Color Scheme"] action:nil keyEquivalent:@""];
    NSMenu *colorSubmenu = [[NSMenu alloc] initWithTitle:[self t:@"Color Scheme"]];

    NSArray *colorOptions = @[
        @{@"title": [self t:@"Dynamic (Green / Yellow / Red)"], @"mode": @(BatteryColorModeDynamic)},
        @{@"title": [self t:@"Native Monochrome (Auto Light/Dark)"], @"mode": @(BatteryColorModeMonochrome)}
    ];

    BatteryColorMode currentMode = self.preferences.colorMode;
    for (NSDictionary *opt in colorOptions) {
        BatteryColorMode mode = [opt[@"mode"] integerValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:opt[@"title"]
                                                      action:@selector(selectColorModeAction:)
                                               keyEquivalent:@""];
        item.target = target;
        item.tag = mode;
        item.state = (currentMode == mode) ? NSControlStateValueOn : NSControlStateValueOff;
        [colorSubmenu addItem:item];
    }

    colorParent.submenu = colorSubmenu;
    return colorParent;
}

- (NSMenuItem *)buildDisplayMenuItemWithTarget:(id<StatusMenuActionHandling>)target {
    NSMenuItem *textParent = [[NSMenuItem alloc] initWithTitle:[self t:@"Menu Bar Display"] action:nil keyEquivalent:@""];
    NSMenu *textSubmenu = [[NSMenu alloc] initWithTitle:[self t:@"Menu Bar Display"]];

    NSArray *textNames = @[
        [self t:@"Icon Only"],
        [self t:@"Icon + Percentage"],
        [self t:@"Icon + Time Remaining"],
        [self t:@"Percentage Only"]
    ];

    BatteryTextDisplay currentDisplay = self.preferences.textDisplay;
    for (NSInteger i = 0; i < (NSInteger)textNames.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:textNames[i]
                                                      action:@selector(selectTextDisplayAction:)
                                               keyEquivalent:@""];
        item.target = target;
        item.tag = i;
        item.state = (currentDisplay == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [textSubmenu addItem:item];
    }

    textParent.submenu = textSubmenu;
    return textParent;
}

- (NSMenuItem *)buildLanguageMenuItemWithTarget:(id<StatusMenuActionHandling>)target {
    NSMenuItem *langParent = [[NSMenuItem alloc] initWithTitle:[self t:@"Language"] action:nil keyEquivalent:@""];
    NSMenu *langSubmenu = [[NSMenu alloc] initWithTitle:[self t:@"Language"]];

    NSString *currentLang = self.localizer.languageCode;
    for (NSDictionary<NSString *, NSString *> *lang in [self.localizer supportedLanguages]) {
        NSString *code = lang[@"code"];
        NSString *name = lang[@"name"];

        NSMenuItem *langItem = [[NSMenuItem alloc] initWithTitle:name
                                                          action:@selector(selectLanguageAction:)
                                                   keyEquivalent:@""];
        langItem.target = target;
        langItem.representedObject = code;
        langItem.state = [code isEqualToString:currentLang] ? NSControlStateValueOn : NSControlStateValueOff;
        [langSubmenu addItem:langItem];
    }

    langParent.submenu = langSubmenu;
    return langParent;
}

#pragma mark - Custom Header View

- (NSView *)createHeaderViewForInfo:(BatteryInfo *)info {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 72)];

    NSTextField *percentLabel = [self makeReadOnlyLabelWithFrame:NSMakeRect(16, 38, 110, 28)
                                                            font:[NSFont systemFontOfSize:24 weight:NSFontWeightBold]
                                                       textColor:nil];
    percentLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)info.percentage];
    [view addSubview:percentLabel];

    NSTextField *stateLabel = [self makeReadOnlyLabelWithFrame:NSMakeRect(16, 20, 208, 16)
                                                          font:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
                                                     textColor:nil];
    stateLabel.stringValue = [info formattedStateString];
    [view addSubview:stateLabel];

    NSTextField *timeLabel = [self makeReadOnlyLabelWithFrame:NSMakeRect(16, 4, 208, 14)
                                                         font:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular]
                                                    textColor:[NSColor secondaryLabelColor]];
    timeLabel.stringValue = [info formattedTimeRemaining];
    [view addSubview:timeLabel];

    return view;
}

- (NSTextField *)makeReadOnlyLabelWithFrame:(NSRect)frame font:(NSFont *)font textColor:(NSColor *)textColor {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = font;
    if (textColor) {
        label.textColor = textColor;
    }
    return label;
}

@end
