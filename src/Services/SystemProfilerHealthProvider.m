#import "SystemProfilerHealthProvider.h"

@interface SystemProfilerHealthProvider ()
@property (nonatomic, assign) BOOL isFetching;
@end

@implementation SystemProfilerHealthProvider

- (void)fetchHealthWithCompletion:(void (^)(NSInteger maxCapacityPercent, NSString *condition))completion {
    if (self.isFetching) return;
    self.isFetching = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSInteger maxCapacityPercent = -1;
        NSString *condition = @"Normal";

        @try {
            NSTask *task = [[NSTask alloc] init];
            task.launchPath = @"/usr/sbin/system_profiler";
            task.arguments = @[@"SPPowerDataType", @"-json"];

            NSPipe *pipe = [NSPipe pipe];
            task.standardOutput = pipe;
            [task launch];

            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            [task waitUntilExit];

            if (data && data.length > 0) {
                NSError *error = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                NSArray *powerList = json[@"SPPowerDataType"];

                for (NSDictionary *item in powerList) {
                    NSDictionary *healthInfo = item[@"sppower_battery_health_info"];
                    if (healthInfo) {
                        NSString *maxCapStr = healthInfo[@"sppower_battery_health_maximum_capacity"];
                        if (maxCapStr) {
                            maxCapacityPercent = [maxCapStr stringByReplacingOccurrencesOfString:@"%" withString:@""].integerValue;
                        }
                        if (healthInfo[@"sppower_battery_health"]) {
                            condition = healthInfo[@"sppower_battery_health"];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            // Fallback handled by caller
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.isFetching = NO;
            if (completion) {
                completion(maxCapacityPercent, condition);
            }
        });
    });
}

@end
