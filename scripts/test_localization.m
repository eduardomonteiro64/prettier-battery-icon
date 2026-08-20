#import <Foundation/Foundation.h>
#import "../src/LocalizationManager.h"
#import "../src/BatteryInfo.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"=== Testing LocalizationManager ===");
        
        LocalizationManager *lm = [LocalizationManager sharedManager];
        
        NSArray *languagesToTest = @[@"en", @"pt-BR", @"es"];
        
        NSArray *testKeys = @[
            @"Low Power Mode",
            @"Battery Statistics",
            @"Battery Health: %ld%% (%@)",
            @"Battery Health: Calculating...",
            @"Capacity: %ld / %ld mAh (%ld%%)",
            @"Capacity: %ld mAh",
            @"Cycle Count: %ld",
            @"Temperature: %.1f °C",
            @"Power Draw: %.1f W (%@)",
            @"Charge Rate: %.1f W (%@)",
            @"Power Draw / Rate: %.1f W",
            @"Voltage: %.2f V",
            @"Voltage: %.2f V (%.0f mA)",
            @"Power Source: %@",
            @"Power Source: %@ (%ld W)",
            @"Hardware: %@ (Serial: %@)",
            @"Serial: %@",
            @"Normal",
            @"Service Recommended",
            @"Fair",
            @"Poor",
            @"Power Adapter (AC)",
            @"Internal Battery",
            @"Battery",
            @"Color Scheme",
            @"Dynamic (Green / Yellow / Red)",
            @"Native Monochrome (Auto Light/Dark)",
            @"Menu Bar Display",
            @"Icon Only",
            @"Icon + Percentage",
            @"Icon + Time Remaining",
            @"Percentage Only",
            @"Language",
            @"System Default (%@)",
            @"Launch at Login",
            @"How to Hide Default macOS Battery...",
            @"System Battery Settings...",
            @"Quit Prettier Battery",
            @"Fully Charged (Power Adapter)",
            @"Charging on AC Power",
            @"Connected to Power (Not Charging)",
            @"On Battery Power",
            @"Fully Charged",
            @"Calculating charge time...",
            @"Calculating time remaining...",
            @"%ldh %02ldm until 100%%",
            @"%ldm until 100%%",
            @"%ldh %02ldm remaining",
            @"%ldm remaining",
            @"Could Not Toggle Low Power Mode",
            @"How to hide the default macOS battery icon:",
            @"Got it",
            @"Open Control Center"
        ];
        
        for (NSString *lang in languagesToTest) {
            lm.languageCode = lang;
            NSLog(@"\n--- Testing Language: %@ (effective: %@) ---", lang, lm.effectiveLanguageCode);
            NSCAssert([lm.effectiveLanguageCode isEqualToString:lang], @"Effective language should match %@", lang);
            
            for (NSString *key in testKeys) {
                NSString *localized = PBLocalizedString(key, nil);
                NSCAssert(localized.length > 0, @"Localized string for '%@' should not be empty", key);
                NSLog(@"[%@] '%@' -> '%@'", lang, key, localized);
            }
            
            // Test BatteryInfo formatted outputs
            BatteryInfo *info = [[BatteryInfo alloc] init];
            info.percentage = 85;
            info.isCharging = YES;
            info.isACConnected = YES;
            info.timeRemainingMinutes = 75;
            info.isLowPowerMode = YES;
            
            NSString *stateStr = [info formattedStateString];
            NSString *timeStr = [info formattedTimeRemaining];
            NSLog(@"[BatteryInfo State - %@] %@", lang, stateStr);
            NSLog(@"[BatteryInfo Time - %@] %@", lang, timeStr);
            
            NSCAssert([stateStr containsString:PBLocalizedString(@"Charging on AC Power", nil)], @"State string must contain localized charging info");
            NSCAssert([stateStr containsString:PBLocalizedString(@"Low Power Mode", nil)], @"State string must contain localized LPM info");
        }
        
        // Test system fallback
        lm.languageCode = @"system";
        NSLog(@"\n--- Testing System Default ---");
        NSLog(@"System language detected: %@", [LocalizationManager detectSystemLanguage]);
        NSLog(@"Supported languages: %@", [lm supportedLanguages]);
        
        NSLog(@"\n✅ ALL LOCALIZATION TESTS PASSED SUCCESSFULLY!");
    }
    return 0;
}
