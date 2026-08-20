#import <Cocoa/Cocoa.h>
#import "BatteryInfo.h"
#import "BatteryIconRenderer.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CGFloat width = 860;
        CGFloat height = 360;
        
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                        pixelsWide:(NSInteger)(width * 2)
                                                                        pixelsHigh:(NSInteger)(height * 2)
                                                                     bitsPerSample:8
                                                                   samplesPerPixel:4
                                                                          hasAlpha:YES
                                                                          isPlanar:NO
                                                                    colorSpaceName:NSDeviceRGBColorSpace
                                                                       bytesPerRow:0
                                                                      bitsPerPixel:0];
        
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [NSGraphicsContext setCurrentContext:context];
        
        CGContextRef ctx = context.CGContext;
        CGContextScaleCTM(ctx, 2.0, 2.0);
        
        // Dark Background (simulating macOS Dark Menu Bar / Desktop)
        NSRect bgRect = NSMakeRect(0, 0, width, height);
        NSGradient *bgGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.11 green:0.13 blue:0.17 alpha:1.0]
                                                           endingColor:[NSColor colorWithSRGBRed:0.06 green:0.07 blue:0.09 alpha:1.0]];
        [bgGrad drawInRect:bgRect angle:-45.0];
        
        // Title
        NSDictionary *titleAttr = @{
            NSFontAttributeName: [NSFont systemFontOfSize:20 weight:NSFontWeightBold],
            NSForegroundColorAttributeName: [NSColor whiteColor]
        };
        [@"Prettier Battery for macOS — Native Typography & Flat Icon Scheme" drawAtPoint:NSMakePoint(40, height - 44) withAttributes:titleAttr];
        
        NSArray *items = @[
            @{@"label": @"Critical Battery (≤15%)", @"pct": @10, @"charging": @NO, @"ac": @NO, @"warn": @NO, @"miss": @NO},
            @{@"label": @"Medium Battery (16–40%)", @"pct": @30, @"charging": @NO, @"ac": @NO, @"warn": @NO, @"miss": @NO},
            @{@"label": @"Full Battery (>40%)", @"pct": @100, @"charging": @NO, @"ac": @NO, @"warn": @NO, @"miss": @NO},
            @{@"label": @"Charging (Bolt)", @"pct": @65, @"charging": @YES, @"ac": @YES, @"warn": @NO, @"miss": @NO},
            @{@"label": @"Warning / Service", @"pct": @50, @"charging": @NO, @"ac": @NO, @"warn": @YES, @"miss": @NO},
            @{@"label": @"Power Connected (Plug)", @"pct": @100, @"charging": @NO, @"ac": @YES, @"warn": @NO, @"miss": @NO},
            @{@"label": @"No Battery / Error", @"pct": @0, @"charging": @NO, @"ac": @NO, @"warn": @NO, @"miss": @YES}
        ];
        
        CGFloat cardW = 180;
        CGFloat cardH = 95;
        CGFloat startX = 40;
        CGFloat startY = height - 155;
        
        for (NSUInteger i = 0; i < items.count; i++) {
            NSDictionary *spec = items[i];
            CGFloat col = i % 4;
            CGFloat row = i / 4;
            
            CGFloat cx = startX + col * (cardW + 20);
            CGFloat cy = startY - row * (cardH + 18);
            
            NSRect cardRect = NSMakeRect(cx, cy, cardW, cardH);
            NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:8 yRadius:8];
            [[NSColor colorWithWhite:1.0 alpha:0.07] setFill];
            [cardPath fill];
            cardPath.lineWidth = 1.0;
            [[NSColor colorWithWhite:1.0 alpha:0.12] setStroke];
            [cardPath stroke];
            
            NSDictionary *lblAttr = @{
                NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: [NSColor colorWithWhite:0.85 alpha:1.0]
            };
            [spec[@"label"] drawAtPoint:NSMakePoint(cx + 12, cy + cardH - 24) withAttributes:lblAttr];
            
            BatteryInfo *mock = [[BatteryInfo alloc] init];
            mock.percentage = [spec[@"pct"] integerValue];
            mock.isCharging = [spec[@"charging"] boolValue];
            mock.isACConnected = [spec[@"ac"] boolValue];
            mock.isWarning = [spec[@"warn"] boolValue];
            mock.isMissing = [spec[@"miss"] boolValue];
            
            NSImage *icon = [BatteryIconRenderer renderIconForBatteryInfo:mock
                                                                colorMode:BatteryColorModeDynamic
                                                       hasTrailingSpacing:YES];
            
            CGFloat drawW = icon.size.width * 1.4;
            CGFloat drawH = icon.size.height * 1.4;
            
            NSString *pctText = [NSString stringWithFormat:@"%ld%%", (long)mock.percentage];
            NSDictionary *pctAttrs = @{
                NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:13.0 weight:NSFontWeightRegular],
                NSForegroundColorAttributeName: [NSColor whiteColor]
            };
            NSSize textSize = [pctText sizeWithAttributes:pctAttrs];
            
            CGFloat totalElemW = drawW + 6.0 + textSize.width;
            CGFloat elemX = cx + (cardW - totalElemW) / 2.0;
            
            NSRect iconDst = NSMakeRect(elemX, cy + 14, drawW, drawH);
            [icon drawInRect:iconDst fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
            
            NSRect textDst = NSMakeRect(elemX + drawW + 6.0, cy + 17, textSize.width, textSize.height);
            [pctText drawInRect:textDst withAttributes:pctAttrs];
        }
        
        [NSGraphicsContext restoreGraphicsState];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:@"docs" withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        [pngData writeToFile:@"docs/preview.png" atomically:YES];
        NSLog(@"Preview generated successfully at docs/preview.png");
    }
    return 0;
}
