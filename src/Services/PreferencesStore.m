#import "PreferencesStore.h"

static NSString * const kPrefColorModeKey = @"PrettierBattery_ColorMode";
static NSString * const kPrefTextDisplayKey = @"PrettierBattery_TextDisplay";

@interface PreferencesStore ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation PreferencesStore

- (instancetype)init {
    return [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
    }
    return self;
}

- (BatteryColorMode)colorMode {
    if ([self.defaults objectForKey:kPrefColorModeKey]) {
        return (BatteryColorMode)[self.defaults integerForKey:kPrefColorModeKey];
    }
    return BatteryColorModeDynamic;
}

- (void)setColorMode:(BatteryColorMode)colorMode {
    [self.defaults setInteger:colorMode forKey:kPrefColorModeKey];
    [self.defaults synchronize];
}

- (BatteryTextDisplay)textDisplay {
    if ([self.defaults objectForKey:kPrefTextDisplayKey]) {
        return (BatteryTextDisplay)[self.defaults integerForKey:kPrefTextDisplayKey];
    }
    return BatteryTextDisplayPercentage;
}

- (void)setTextDisplay:(BatteryTextDisplay)textDisplay {
    [self.defaults setInteger:textDisplay forKey:kPrefTextDisplayKey];
    [self.defaults synchronize];
}

@end
