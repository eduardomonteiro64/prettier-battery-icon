#import "StatusBarController.h"

@interface StatusBarController ()
@property (nonatomic, strong) id<BatteryMonitoring> batteryMonitor;
@property (nonatomic, strong) id<PowerModeControlling> powerModeController;
@property (nonatomic, strong) id<PreferencesStoring> preferences;
@property (nonatomic, strong) id<LaunchAtLoginControlling> launchAtLoginService;
@property (nonatomic, strong) id<Localizing> localizer;
@property (nonatomic, strong) id<BatteryIconRendering> iconRenderer;
@property (nonatomic, strong) StatusMenuBuilder *menuBuilder;
@property (nonatomic, strong) SystemSettingsNavigator *settingsNavigator;

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) BatteryInfo *latestInfo;

@property (nonatomic, assign) BOOL hasRenderedOnce;
@property (nonatomic, assign) NSInteger lastRenderedPercentage;
@property (nonatomic, assign) BatteryState lastRenderedState;
@property (nonatomic, assign) BOOL lastRenderedLowPowerMode;
@property (nonatomic, assign) NSInteger lastRenderedTimeMinutes;
@property (nonatomic, assign) BatteryColorMode lastRenderedColorMode;
@property (nonatomic, assign) BatteryTextDisplay lastRenderedTextDisplay;
@end

@implementation StatusBarController

- (instancetype)init {
    return [self initWithBatteryMonitor:nil
                    powerModeController:nil
                            preferences:nil
                   launchAtLoginService:nil
                              localizer:nil
                           iconRenderer:nil
                            menuBuilder:nil
                      settingsNavigator:nil];
}

- (instancetype)initWithBatteryMonitor:(id<BatteryMonitoring>)batteryMonitor
                   powerModeController:(id<PowerModeControlling>)powerModeController
                           preferences:(id<PreferencesStoring>)preferences
                  launchAtLoginService:(id<LaunchAtLoginControlling>)launchAtLoginService
                             localizer:(id<Localizing>)localizer
                          iconRenderer:(id<BatteryIconRendering>)iconRenderer
                           menuBuilder:(StatusMenuBuilder *)menuBuilder
                     settingsNavigator:(SystemSettingsNavigator *)settingsNavigator {
    self = [super init];
    if (self) {
        _batteryMonitor = batteryMonitor;
        _powerModeController = powerModeController;
        _preferences = preferences;
        _launchAtLoginService = launchAtLoginService;
        _localizer = localizer;
        _iconRenderer = iconRenderer;
        _menuBuilder = menuBuilder;
        _settingsNavigator = settingsNavigator;
    }
    return self;
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.toolTip = [self.localizer localizedStringForKey:@"Prettier Battery"];

    self.statusMenu = [[NSMenu alloc] initWithTitle:@"PrettierBattery"];
    self.statusMenu.delegate = self;
    self.statusItem.menu = self.statusMenu;

    [self updateWithBatteryInfo:self.latestInfo ?: [self.batteryMonitor fetchCurrentInfo]];
}

- (void)refreshLocalization {
    self.statusItem.button.toolTip = [self.localizer localizedStringForKey:@"Prettier Battery"];
    self.hasRenderedOnce = NO;
    [self updateWithBatteryInfo:self.latestInfo];
}

- (void)updateWithBatteryInfo:(BatteryInfo *)info {
    if (info) {
        self.latestInfo = info;
    }
    if (!self.latestInfo) {
        self.latestInfo = [self.batteryMonitor fetchCurrentInfo];
    }

    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;

    BatteryColorMode colorMode = self.preferences.colorMode;
    BatteryTextDisplay textDisplay = self.preferences.textDisplay;

    // Skip expensive vector icon & attributed string allocation when visible state is unchanged.
    BOOL unchanged = self.hasRenderedOnce &&
        self.lastRenderedPercentage == self.latestInfo.percentage &&
        self.lastRenderedState == self.latestInfo.state &&
        self.lastRenderedLowPowerMode == self.latestInfo.isLowPowerMode &&
        self.lastRenderedTimeMinutes == self.latestInfo.timeRemainingMinutes &&
        self.lastRenderedColorMode == colorMode &&
        self.lastRenderedTextDisplay == textDisplay;
    if (unchanged) {
        return;
    }

    self.hasRenderedOnce = YES;
    self.lastRenderedPercentage = self.latestInfo.percentage;
    self.lastRenderedState = self.latestInfo.state;
    self.lastRenderedLowPowerMode = self.latestInfo.isLowPowerMode;
    self.lastRenderedTimeMinutes = self.latestInfo.timeRemainingMinutes;
    self.lastRenderedColorMode = colorMode;
    self.lastRenderedTextDisplay = textDisplay;

    if (textDisplay == BatteryTextDisplayPercentageOnly) {
        button.image = nil;
        button.imagePosition = NSNoImage;
    } else {
        BOOL hasText = (textDisplay != BatteryTextDisplayNone);
        NSImage *icon = [self.iconRenderer renderIconForBatteryInfo:self.latestInfo
                                                          colorMode:colorMode
                                                 hasTrailingSpacing:hasText];
        button.image = icon;
        button.imagePosition = (textDisplay == BatteryTextDisplayNone) ? NSImageOnly : NSImageLeft;
    }

    NSString *textString = [self formattedButtonTextForInfo:self.latestInfo displayMode:textDisplay];
    if (textString.length > 0) {
        NSFont *font = [NSFont monospacedDigitSystemFontOfSize:13.0 weight:NSFontWeightRegular];
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
        if (colorMode == BatteryColorModeDynamic) {
            attrs[NSForegroundColorAttributeName] = [NSColor whiteColor];
        }
        button.attributedTitle = [[NSAttributedString alloc] initWithString:textString attributes:attrs];
    } else {
        button.title = @"";
        button.attributedTitle = [[NSAttributedString alloc] initWithString:@""];
    }
}

- (NSString *)formattedButtonTextForInfo:(BatteryInfo *)info displayMode:(BatteryTextDisplay)textDisplay {
    switch (textDisplay) {
        case BatteryTextDisplayNone:
            return @"";
        case BatteryTextDisplayPercentage:
        case BatteryTextDisplayPercentageOnly:
            return [NSString stringWithFormat:@"%ld%%", (long)info.percentage];
        case BatteryTextDisplayTimeRemaining:
            if (info.timeRemainingMinutes > 0) {
                NSInteger h = info.timeRemainingMinutes / 60;
                NSInteger m = info.timeRemainingMinutes % 60;
                return [NSString stringWithFormat:@"%ld:%02ld", (long)h, (long)m];
            }
            return [NSString stringWithFormat:@"%ld%%", (long)info.percentage];
    }
}

#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
    BatteryInfo *info = [self.batteryMonitor fetchCurrentInfo] ?: self.latestInfo;
    self.latestInfo = info;
    [self.menuBuilder populateMenu:menu withInfo:info actionHandler:self];
}

#pragma mark - StatusMenuActionHandling

- (void)selectLanguageAction:(NSMenuItem *)sender {
    NSString *code = sender.representedObject;
    if (code) {
        self.localizer.languageCode = code;
    }
}

- (void)selectColorModeAction:(NSMenuItem *)sender {
    self.preferences.colorMode = (BatteryColorMode)sender.tag;
    [self updateWithBatteryInfo:self.latestInfo];
}

- (void)selectTextDisplayAction:(NSMenuItem *)sender {
    self.preferences.textDisplay = (BatteryTextDisplay)sender.tag;
    [self updateWithBatteryInfo:self.latestInfo];
}

- (void)toggleLowPowerModeAction:(NSMenuItem *)sender {
    BOOL targetState = !(self.latestInfo.isLowPowerMode);
    __weak typeof(self) weakSelf = self;
    [self.powerModeController setLowPowerModeEnabled:targetState completion:^(BOOL success, NSString *errorMessage) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (!success && errorMessage && ![errorMessage containsString:@"User canceled"]) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = [strongSelf.localizer localizedStringForKey:@"Could Not Toggle Low Power Mode"];
            alert.informativeText = errorMessage;
            [alert runModal];
        }
        [strongSelf updateWithBatteryInfo:[strongSelf.batteryMonitor fetchCurrentInfo]];
    }];
}

- (void)toggleLaunchAtLoginAction:(NSMenuItem *)sender {
    BOOL nextState = ![self.launchAtLoginService isLaunchAtLoginEnabled];
    [self.launchAtLoginService setLaunchAtLoginEnabled:nextState];
}

- (void)showHideDefaultBatteryGuideAction:(id)sender {
    [self.settingsNavigator showHideDefaultBatteryGuide];
}

- (void)openSystemBatterySettingsAction:(id)sender {
    [self.settingsNavigator openSystemBatterySettings];
}

- (void)quitAction:(id)sender {
    [NSApp terminate:nil];
}

@end
