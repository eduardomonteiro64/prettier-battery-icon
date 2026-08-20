#import <Cocoa/Cocoa.h>

void drawAppIcon(CGContextRef ctx, CGFloat size) {
    NSRect bounds = NSMakeRect(0, 0, size, size);
    
    // Background Squircle
    CGFloat cornerRadius = size * 0.2237; // Standard macOS app icon continuous corner radius
    NSRect iconRect = NSInsetRect(bounds, size * 0.05, size * 0.05);
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:iconRect xRadius:cornerRadius yRadius:cornerRadius];
    
    // Gradient Background (Deep Slate to Midnight Graphite)
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.12 green:0.14 blue:0.18 alpha:1.0]
                                                          endingColor:[NSColor colorWithSRGBRed:0.04 green:0.05 blue:0.07 alpha:1.0]];
    [gradient drawInBezierPath:bgPath angle:-45.0];
    
    // Subtle inner border
    [NSGraphicsContext saveGraphicsState];
    bgPath.lineWidth = size * 0.015;
    [[NSColor colorWithWhite:1.0 alpha:0.12] setStroke];
    [bgPath stroke];
    [NSGraphicsContext restoreGraphicsState];
    
    // Glowing Battery Body
    CGFloat batW = size * 0.52;
    CGFloat batH = size * 0.28;
    CGFloat batX = (size - batW) / 2.0 - size * 0.02;
    CGFloat batY = (size - batH) / 2.0;
    
    NSRect batRect = NSMakeRect(batX, batY, batW, batH);
    NSBezierPath *batOutline = [NSBezierPath bezierPathWithRoundedRect:batRect xRadius:size * 0.055 yRadius:size * 0.055];
    batOutline.lineWidth = size * 0.025;
    
    [[NSColor colorWithSRGBRed:0.20 green:0.85 blue:0.55 alpha:1.0] setStroke];
    [batOutline stroke];
    
    // Terminal cap
    CGFloat capW = size * 0.035;
    CGFloat capH = size * 0.12;
    CGFloat capX = batX + batW + size * 0.025;
    CGFloat capY = batY + (batH - capH) / 2.0;
    NSRect capRect = NSMakeRect(capX, capY, capW, capH);
    NSBezierPath *capPath = [NSBezierPath bezierPathWithRoundedRect:capRect xRadius:size * 0.015 yRadius:size * 0.015];
    [[NSColor colorWithSRGBRed:0.20 green:0.85 blue:0.55 alpha:1.0] setFill];
    [capPath fill];
    
    // Fill inside battery (75% full with emerald green gradient)
    CGFloat fillPadding = size * 0.04;
    CGFloat fillMaxW = batW - (fillPadding * 2);
    CGFloat fillH = batH - (fillPadding * 2);
    CGFloat fillW = fillMaxW * 0.75;
    
    NSRect fillRect = NSMakeRect(batX + fillPadding, batY + fillPadding, fillW, fillH);
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:size * 0.03 yRadius:size * 0.03];
    
    NSGradient *fillGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithSRGBRed:0.18 green:0.85 blue:0.45 alpha:1.0]
                                                          endingColor:[NSColor colorWithSRGBRed:0.00 green:0.70 blue:0.90 alpha:1.0]];
    [fillGrad drawInBezierPath:fillPath angle:0.0];
    
    // Sharp Flat Lightning Bolt in the center
    CGFloat boltW = size * 0.14;
    CGFloat boltH = size * 0.22;
    CGFloat boltX = batX + (batW - boltW) / 2.0;
    CGFloat boltY = batY + (batH - boltH) / 2.0;
    
    NSBezierPath *bolt = [NSBezierPath bezierPath];
    [bolt moveToPoint:NSMakePoint(boltX + boltW * 0.58, boltY + boltH * 1.0)];
    [bolt lineToPoint:NSMakePoint(boltX + boltW * 0.15, boltY + boltH * 0.46)];
    [bolt lineToPoint:NSMakePoint(boltX + boltW * 0.52, boltY + boltH * 0.46)];
    [bolt lineToPoint:NSMakePoint(boltX + boltW * 0.42, boltY + boltH * 0.0)];
    [bolt lineToPoint:NSMakePoint(boltX + boltW * 0.88, boltY + boltH * 0.56)];
    [bolt lineToPoint:NSMakePoint(boltX + boltW * 0.50, boltY + boltH * 0.56)];
    [bolt closePath];
    
    [[NSColor whiteColor] setFill];
    [bolt fill];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *iconsetDir = @"AppIcon.iconset";
        [[NSFileManager defaultManager] createDirectoryAtPath:iconsetDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSArray *sizes = @[
            @{@"name": @"icon_16x16.png", @"size": @16, @"scale": @1},
            @{@"name": @"icon_16x16@2x.png", @"size": @16, @"scale": @2},
            @{@"name": @"icon_32x32.png", @"size": @32, @"scale": @1},
            @{@"name": @"icon_32x32@2x.png", @"size": @32, @"scale": @2},
            @{@"name": @"icon_128x128.png", @"size": @128, @"scale": @1},
            @{@"name": @"icon_128x128@2x.png", @"size": @128, @"scale": @2},
            @{@"name": @"icon_256x256.png", @"size": @256, @"scale": @1},
            @{@"name": @"icon_256x256@2x.png", @"size": @256, @"scale": @2},
            @{@"name": @"icon_512x512.png", @"size": @512, @"scale": @1},
            @{@"name": @"icon_512x512@2x.png", @"size": @512, @"scale": @2}
        ];
        
        for (NSDictionary *spec in sizes) {
            CGFloat size = [spec[@"size"] doubleValue];
            CGFloat scale = [spec[@"scale"] doubleValue];
            CGFloat pixelSize = size * scale;
            
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                            pixelsWide:(NSInteger)pixelSize
                                                                            pixelsHigh:(NSInteger)pixelSize
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
            
            CGContextRef cgCtx = context.CGContext;
            drawAppIcon(cgCtx, pixelSize);
            
            [NSGraphicsContext restoreGraphicsState];
            
            NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSString *filePath = [iconsetDir stringByAppendingPathComponent:spec[@"name"]];
            [pngData writeToFile:filePath atomically:YES];
        }
        
        NSLog(@"Icons generated successfully in %@", iconsetDir);
    }
    return 0;
}
