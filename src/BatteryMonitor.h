#import <Foundation/Foundation.h>
#import "BatteryInfo.h"

@protocol BatteryMonitorDelegate <NSObject>
- (void)batteryMonitorDidUpdateInfo:(BatteryInfo *)info;
@end

@interface BatteryMonitor : NSObject

@property (nonatomic, weak) id<BatteryMonitorDelegate> delegate;
@property (nonatomic, readonly) BatteryInfo *currentInfo;

+ (instancetype)sharedMonitor;
- (void)startMonitoring;
- (void)stopMonitoring;
- (BatteryInfo *)fetchCurrentInfo;

@end
