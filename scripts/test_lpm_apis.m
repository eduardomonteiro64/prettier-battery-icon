#import <Foundation/Foundation.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

// Declare IOPMCopyCustomPowerPreferences if not in headers
extern CFDictionaryRef IOPMCopyCustomPowerPreferences(void);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CFDictionaryRef dict = IOPMCopyCustomPowerPreferences();
        if (dict) {
            NSLog(@"IOPMCopyCustomPowerPreferences: %@", (__bridge id)dict);
            CFRelease(dict);
        } else {
            NSLog(@"IOPMCopyCustomPowerPreferences returned NULL");
        }
        
        // Also check pmset -g output via NSTask
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/pmset";
        task.arguments = @[@"-g", @"custom"];
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        [task launch];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"pmset -g custom:\n%@", outStr);
    }
    return 0;
}
