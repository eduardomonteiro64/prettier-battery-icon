#import "BatteryIconRenderer.h"

@implementation BatteryIconRenderer

- (NSImage *)renderIconForBatteryInfo:(BatteryInfo *)info
                            colorMode:(BatteryColorMode)colorMode
                   hasTrailingSpacing:(BOOL)hasTrailingSpacing {
    return [[self class] renderIconForBatteryInfo:info
                                        colorMode:colorMode
                               hasTrailingSpacing:hasTrailingSpacing];
}

+ (NSBezierPath *)lightningBoltInRect:(NSRect)rect {
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat x = rect.origin.x;
    CGFloat y = rect.origin.y;
    
    [path moveToPoint:NSMakePoint(x + w * 0.58, y + h * 1.00)];
    [path lineToPoint:NSMakePoint(x + w * 0.12, y + h * 0.44)];
    [path lineToPoint:NSMakePoint(x + w * 0.52, y + h * 0.44)];
    [path lineToPoint:NSMakePoint(x + w * 0.42, y + h * 0.00)];
    [path lineToPoint:NSMakePoint(x + w * 0.88, y + h * 0.56)];
    [path lineToPoint:NSMakePoint(x + w * 0.50, y + h * 0.56)];
    [path closePath];
    return path;
}

+ (void)drawPowerPlugInRect:(NSRect)rect isWhiteTheme:(BOOL)isWhiteTheme {
    CGFloat cx = NSMidX(rect);
    CGFloat cy = NSMidY(rect);
    
    CGFloat plugW = 7.0;
    CGFloat plugH = 6.0;
    NSRect bodyRect = NSMakeRect(cx - plugW/2.0, cy - plugH/2.0, plugW, plugH);
    
    CGFloat prongW = 1.25;
    CGFloat prongH = 3.0;
    NSRect prong1 = NSMakeRect(cx - 2.2, cy + plugH/2.0, prongW, prongH);
    NSRect prong2 = NSMakeRect(cx + 2.2 - prongW, cy + plugH/2.0, prongW, prongH);
    
    CGFloat cableW = 1.5;
    CGFloat cableH = 3.5;
    NSRect cableRect = NSMakeRect(cx - cableW/2.0, cy - plugH/2.0 - cableH, cableW, cableH);
    
    // Halo knockout
    NSBezierPath *halo = [NSBezierPath bezierPath];
    [halo appendBezierPath:[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bodyRect, -1.0, -1.0) xRadius:2.0 yRadius:2.0]];
    [halo appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(prong1, -0.8, -0.8)]];
    [halo appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(prong2, -0.8, -0.8)]];
    [halo appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(cableRect, -0.8, -0.8)]];
    
    if (isWhiteTheme) {
        [[NSColor colorWithSRGBRed:0.08 green:0.08 blue:0.08 alpha:0.9] setFill];
    } else {
        [[NSColor whiteColor] setFill];
    }
    [halo fill];
    
    // Plug body
    if (isWhiteTheme) {
        [[NSColor whiteColor] setFill];
    } else {
        [[NSColor blackColor] setFill];
    }
    
    [[NSBezierPath bezierPathWithRoundedRect:bodyRect xRadius:1.25 yRadius:1.25] fill];
    [[NSBezierPath bezierPathWithRect:prong1] fill];
    [[NSBezierPath bezierPathWithRect:prong2] fill];
    [[NSBezierPath bezierPathWithRect:cableRect] fill];
}

+ (void)drawWarningTriangleInRect:(NSRect)rect isWhiteTheme:(BOOL)isWhiteTheme {
    CGFloat w = 11.0;
    CGFloat h = 10.0;
    CGFloat x = NSMidX(rect) - w/2.0;
    CGFloat y = NSMidY(rect) - h/2.0;
    
    // Halo
    NSBezierPath *halo = [NSBezierPath bezierPath];
    [halo moveToPoint:NSMakePoint(x + w * 0.5, y + h + 1.0)];
    [halo lineToPoint:NSMakePoint(x - 1.0, y - 1.0)];
    [halo lineToPoint:NSMakePoint(x + w + 1.0, y - 1.0)];
    [halo closePath];
    halo.lineJoinStyle = NSLineJoinStyleRound;
    halo.lineWidth = 2.0;
    
    if (isWhiteTheme) {
        [[NSColor colorWithSRGBRed:0.08 green:0.08 blue:0.08 alpha:0.9] setStroke];
        [[NSColor colorWithSRGBRed:0.08 green:0.08 blue:0.08 alpha:0.9] setFill];
    } else {
        [[NSColor whiteColor] setStroke];
        [[NSColor whiteColor] setFill];
    }
    [halo fill];
    [halo stroke];
    
    // Triangle
    NSBezierPath *tri = [NSBezierPath bezierPath];
    [tri moveToPoint:NSMakePoint(x + w * 0.5, y + h)];
    [tri lineToPoint:NSMakePoint(x, y)];
    [tri lineToPoint:NSMakePoint(x + w, y)];
    [tri closePath];
    tri.lineJoinStyle = NSLineJoinStyleRound;
    tri.lineWidth = 1.0;
    
    if (isWhiteTheme) {
        [[NSColor colorWithSRGBRed:1.00 green:0.80 blue:0.00 alpha:1.0] setFill]; // Golden Warning Triangle
    } else {
        [[NSColor blackColor] setFill];
    }
    [tri fill];
    
    // Exclamation mark
    NSRect bar = NSMakeRect(x + w * 0.5 - 0.6, y + 3.5, 1.2, 3.8);
    NSRect dot = NSMakeRect(x + w * 0.5 - 0.6, y + 1.5, 1.2, 1.2);
    
    if (isWhiteTheme) {
        [[NSColor blackColor] setFill];
    } else {
        [[NSColor whiteColor] setFill];
    }
    [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:0.5 yRadius:0.5] fill];
    [[NSBezierPath bezierPathWithOvalInRect:dot] fill];
}

+ (void)drawMissingXInRect:(NSRect)rect isWhiteTheme:(BOOL)isWhiteTheme {
    CGFloat w = 9.0;
    CGFloat h = 7.0;
    CGFloat x = NSMidX(rect) - w/2.0;
    CGFloat y = NSMidY(rect) - h/2.0;
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(x, y)];
    [path lineToPoint:NSMakePoint(x + w, y + h)];
    [path moveToPoint:NSMakePoint(x, y + h)];
    [path lineToPoint:NSMakePoint(x + w, y)];
    
    path.lineWidth = 1.5;
    path.lineCapStyle = NSLineCapStyleRound;
    
    if (isWhiteTheme) {
        [[NSColor whiteColor] setStroke];
    } else {
        [[NSColor blackColor] setStroke];
    }
    [path stroke];
}

+ (NSImage *)renderIconForBatteryInfo:(BatteryInfo *)info
                            colorMode:(BatteryColorMode)colorMode
                   hasTrailingSpacing:(BOOL)hasTrailingSpacing {
    
    CGFloat iconWidth = hasTrailingSpacing ? 30.0 : 25.0;
    CGFloat iconHeight = 20.0;
    
    BOOL isWhiteOutline = (colorMode == BatteryColorModeDynamic);
    
    NSImage *image = [NSImage imageWithSize:NSMakeSize(iconWidth, iconHeight) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        
        CGFloat startX = 0.5;
        CGFloat iconY = (iconHeight - 11.5) / 2.0;
        
        // 1. Determine Shell & Fill Colors
        BOOL isWhiteOutline = (colorMode == BatteryColorModeDynamic || info.isLowPowerMode);
        NSColor *shellColor = isWhiteOutline ? [NSColor whiteColor] : [NSColor blackColor];
        NSColor *fillColor = nil;
        
        if (info.isLowPowerMode) {
            fillColor = [NSColor colorWithSRGBRed:1.00 green:0.78 blue:0.10 alpha:1.0]; // Vivid Flat Yellow for Low Power Mode
        } else if (colorMode == BatteryColorModeMonochrome) {
            fillColor = [NSColor blackColor];
        } else {
            if (info.isCharging) {
                fillColor = [NSColor colorWithSRGBRed:0.20 green:0.75 blue:0.30 alpha:1.0]; // Vivid Flat Green
            } else if (info.percentage <= 15) {
                fillColor = [NSColor colorWithSRGBRed:0.95 green:0.22 blue:0.22 alpha:1.0]; // Vivid Flat Red
            } else {
                fillColor = [NSColor colorWithSRGBRed:0.20 green:0.75 blue:0.30 alpha:1.0]; // Vivid Flat Green
            }
        }
        
        // 2. Draw Battery Shell (White in Dynamic mode or Low Power Mode)
        CGFloat bodyW = 21.0;
        CGFloat bodyH = 11.5;
        NSRect bodyRect = NSMakeRect(startX, iconY, bodyW, bodyH);
        NSBezierPath *bodyPath = [NSBezierPath bezierPathWithRoundedRect:bodyRect xRadius:3.25 yRadius:3.25];
        bodyPath.lineWidth = 1.35;
        [shellColor setStroke];
        [bodyPath stroke];
        
        // Terminal cap (White in Dynamic mode or Low Power Mode)
        CGFloat capW = 1.5;
        CGFloat capH = 4.5;
        CGFloat capX = startX + bodyW + 1.25;
        CGFloat capY = iconY + (bodyH - capH) / 2.0;
        NSRect capRect = NSMakeRect(capX, capY, capW, capH);
        NSBezierPath *capPath = [NSBezierPath bezierPathWithRoundedRect:capRect xRadius:0.75 yRadius:0.75];
        [shellColor setFill];
        [capPath fill];
        
        // 3. Draw Inner Fill
        if (!info.isMissing && info.state != BatteryStateMissing) {
            CGFloat maxInnerW = bodyW - 3.5;
            CGFloat innerH = bodyH - 3.5;
            CGFloat fillW = (maxInnerW * info.percentage) / 100.0;
            if (fillW < 1.5 && info.percentage > 0) fillW = 1.5;
            
            if (fillW > 0) {
                NSRect fillRect = NSMakeRect(startX + 1.75, iconY + 1.75, fillW, innerH);
                NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:1.75 yRadius:1.75];
                [fillColor setFill];
                [fillPath fill];
            }
        }
        
        // 4. Draw Overlay Symbols
        NSRect symbolBounds = NSMakeRect(startX, iconY, bodyW, bodyH);
        
        if (info.isMissing || info.state == BatteryStateMissing) {
            [self drawMissingXInRect:symbolBounds isWhiteTheme:isWhiteOutline];
        } else if (info.isWarning || info.state == BatteryStateWarning) {
            [self drawWarningTriangleInRect:symbolBounds isWhiteTheme:isWhiteOutline];
        } else if (info.isCharging) {
            // Charging Lightning Bolt
            CGFloat boltW = 7.5;
            CGFloat boltH = 13.0;
            CGFloat boltX = startX + (bodyW - boltW) / 2.0;
            CGFloat boltY = iconY + (bodyH - boltH) / 2.0;
            NSRect boltRect = NSMakeRect(boltX, boltY, boltW, boltH);
            
            NSBezierPath *bolt = [self lightningBoltInRect:boltRect];
            
            // Halo/border knockout
            if (isWhiteOutline) {
                [[NSColor colorWithSRGBRed:0.08 green:0.08 blue:0.08 alpha:0.9] setStroke];
            } else {
                [[NSColor blackColor] setStroke];
            }
            bolt.lineWidth = 2.0;
            bolt.lineJoinStyle = NSLineJoinStyleRound;
            [bolt stroke];
            
            // Bolt fill
            if (isWhiteOutline) {
                [[NSColor colorWithSRGBRed:1.00 green:0.85 blue:0.10 alpha:1.0] setFill]; // Flat Golden Bolt
            } else {
                [[NSColor whiteColor] setFill];
            }
            [bolt fill];
            
            // Inner contour
            [[NSColor colorWithSRGBRed:0.10 green:0.10 blue:0.10 alpha:0.8] setStroke];
            bolt.lineWidth = 0.6;
            [bolt stroke];
        } else if (info.isACConnected) {
            // AC Connected Plug
            [self drawPowerPlugInRect:symbolBounds isWhiteTheme:isWhiteOutline];
        }
        
        return YES;
    }];
    
    image.template = (colorMode == BatteryColorModeMonochrome && !info.isLowPowerMode);
    return image;
}

@end
