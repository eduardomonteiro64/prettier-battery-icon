#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"

@protocol BatteryMonitorDelegate <NSObject>
- (void)batteryMonitorDidUpdateInfo:(BatteryInfo *)info;
@end

/// Coordinates battery monitoring lifecycle and notifies a delegate on updates.
@protocol BatteryMonitoring <NSObject>
@property (nonatomic, weak) id<BatteryMonitorDelegate> delegate;
@property (nonatomic, readonly) BatteryInfo *currentInfo;
- (void)startMonitoring;
- (void)stopMonitoring;
- (BatteryInfo *)fetchCurrentInfo;
@end

/// Reads instantaneous battery and power-source telemetry from the system.
@protocol BatteryTelemetryProviding <NSObject>
- (BatteryInfo *)readTelemetryWithLowPowerMode:(BOOL)isLowPowerMode
                              healthPercentage:(NSInteger)healthPercentage
                                     condition:(NSString *)condition;
@end

/// Fetches official battery health percentage and condition asynchronously.
@protocol BatteryHealthProviding <NSObject>
- (void)fetchHealthWithCompletion:(void (^)(NSInteger maxCapacityPercent, NSString *condition))completion;
@end

/// Reads and updates macOS Low Power Mode state.
@protocol PowerModeControlling <NSObject>
- (BOOL)isLowPowerModeEnabled;
- (void)setLowPowerModeEnabled:(BOOL)enabled
                    completion:(void (^)(BOOL success, NSString *errorMessage))completion;
@end

/// Persists user display preferences.
@protocol PreferencesStoring <NSObject>
@property (nonatomic, assign) BatteryColorMode colorMode;
@property (nonatomic, assign) BatteryTextDisplay textDisplay;
@end

/// Controls whether the application launches automatically at login.
@protocol LaunchAtLoginControlling <NSObject>
- (BOOL)isLaunchAtLoginEnabled;
- (void)setLaunchAtLoginEnabled:(BOOL)enabled;
@end

/// Provides localized strings and language selection.
@protocol Localizing <NSObject>
@property (nonatomic, copy) NSString *languageCode;
@property (nonatomic, readonly) NSString *effectiveLanguageCode;
- (NSString *)localizedStringForKey:(NSString *)key;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)supportedLanguages;
@end

/// Renders the menu bar battery icon for a given state and color mode.
@protocol BatteryIconRendering <NSObject>
- (NSImage *)renderIconForBatteryInfo:(BatteryInfo *)info
                            colorMode:(BatteryColorMode)colorMode
                   hasTrailingSpacing:(BOOL)hasTrailingSpacing;
@end
