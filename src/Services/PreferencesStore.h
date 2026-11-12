#import <Foundation/Foundation.h>
#import "BatteryProtocols.h"

/// Persists display preferences in NSUserDefaults.
@interface PreferencesStore : NSObject <PreferencesStoring>

@property (nonatomic, assign) BatteryColorMode colorMode;
@property (nonatomic, assign) BatteryTextDisplay textDisplay;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;

@end
