#import "LowPowerModeController.h"

@implementation LowPowerModeController

- (BOOL)isLowPowerModeEnabled {
    if (@available(macOS 12.0, *)) {
        return [[NSProcessInfo processInfo] isLowPowerModeEnabled];
    }

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/pmset";
    task.arguments = @[@"-g"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    @try {
        [task launch];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange range = [outStr rangeOfString:@"lowpowermode"];
        if (range.location != NSNotFound) {
            NSString *sub = [outStr substringFromIndex:range.location];
            NSScanner *scanner = [NSScanner scannerWithString:sub];
            [scanner scanString:@"lowpowermode" intoString:NULL];
            NSInteger val = 0;
            if ([scanner scanInteger:&val]) {
                return val == 1;
            }
        }
    } @catch (NSException *e) {
    }
    return NO;
}

- (void)setLowPowerModeEnabled:(BOOL)enabled
                    completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *script = [NSString stringWithFormat:@"do shell script \"pmset -a lowpowermode %d\" with administrator privileges", enabled ? 1 : 0];
        NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
        NSDictionary *errorInfo = nil;
        NSAppleEventDescriptor *result = [appleScript executeAndReturnError:&errorInfo];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL success = (result != nil && errorInfo == nil);
            NSString *err = errorInfo ? errorInfo[NSAppleScriptErrorMessage] : nil;
            if (completion) {
                completion(success, err);
            }
        });
    });
}

@end
