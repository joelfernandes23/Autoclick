//
//  AutoclickAppDelegate.m
//  Autoclick
//

#import "AutoclickAppDelegate.h"
#import "Autoclick-Swift.h"
@import IOKit;

@implementation NSApplication (AppDelegate)

- (AutoclickAppDelegate *)appDelegate {
    return (AutoclickAppDelegate *)[NSApp delegate];
}

@end

@implementation AutoclickAppDelegate {
    NSUserDefaultsController *_defaults;
}

@synthesize window;
@synthesize modeButton;
@synthesize statusLabel;
@synthesize startStopButton;

- (void)encodeRestorableState:(NSCoder *)state {
    [state encodeInteger:[buttonSelector indexOfSelectedItem] forKey:@"buttonSelector"];
    [state encodeInteger:[rateSelector integerValue] forKey:@"rateSelector"];
    [state encodeInteger:[rateUnitSelector indexOfSelectedItem] forKey:@"rateUnitSelector"];
    
    [state encodeInteger:[startAfterSelector integerValue] forKey:@"startAfterSelector"];
    [state encodeInteger:[startAfterUnitSelector indexOfSelectedItem] forKey:@"startAfterUnitSelector"];
    [state encodeBool:[startAfterCheckbox state] forKey:@"startAfterCheckbox"];
    
    [state encodeInteger:[stopAfterSelector integerValue] forKey:@"stopAfterSelector"];
    [state encodeInteger:[stopAfterUnitSelector indexOfSelectedItem] forKey:@"stopAfterUnitSelector"];
    [state encodeBool:[stopAfterCheckbox state] forKey:@"stopAfterCheckbox"];
    
    [state encodeBool:[ifStationaryCheckbox state] forKey:@"ifStationaryCheckbox"];
    [state encodeBool:[ifStationaryForCheckbox state] forKey:@"ifStationaryForCheckbox"];
    [state encodeInteger:[ifStationaryForSelector integerValue] forKey:@"ifStationaryForSelector"];
}

- (void)decodeRestorableState:(NSCoder *)state {
    [buttonSelector selectItemAtIndex:[state decodeIntegerForKey:@"buttonSelector"]];
    [rateSelector setIntegerValue:[state decodeIntegerForKey:@"rateSelector"]];
    [rateUnitSelector selectItemAtIndex:[state decodeIntegerForKey:@"rateUnitSelector"]];
    
    [startAfterSelector setIntegerValue:[state decodeIntegerForKey:@"startAfterSelector"]];
    [startAfterUnitSelector selectItemAtIndex:[state decodeIntegerForKey:@"startAfterUnitSelector"]];
    [startAfterCheckbox setState:[state decodeBoolForKey:@"startAfterCheckbox"]];
    
    [stopAfterSelector setIntegerValue:[state decodeIntegerForKey:@"stopAfterSelector"]];
    [stopAfterUnitSelector selectItemAtIndex:[state decodeIntegerForKey:@"stopAfterUnitSelector"]];
    [stopAfterCheckbox setState:[state decodeBoolForKey:@"stopAfterCheckbox"]];
    
    [ifStationaryCheckbox setState:[state decodeBoolForKey:@"ifStationaryCheckbox"]];
    [ifStationaryForCheckbox setState:[state decodeBoolForKey:@"ifStationaryForCheckbox"]];
    [ifStationaryForSelector setIntegerValue:[state decodeIntegerForKey:@"ifStationaryForSelector"]];
    
    [rateSelector syncWithStepper];
    [startAfterSelector syncWithStepper];
    [stopAfterSelector syncWithStepper];
    [ifStationaryForSelector syncWithStepper];
    
    [self changedState:ifStationaryCheckbox];
}

- (void)awakeFromNib {
    clicker = [[Clicker alloc] initWithHost:self];
    [window setDelegate:(id<NSWindowDelegate>)self];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self configureMenuBarUtilityWindow];
    [rateSelector syncWithStepper];
    [startAfterSelector syncWithStepper];
    [stopAfterSelector syncWithStepper];
    [ifStationaryForSelector syncWithStepper];

    [shortcutRecorder setAllowedModifierFlags:SRCocoaModifierFlagsMask requiredModifierFlags:0 allowsEmptyModifierFlags:YES];

    _defaults = NSUserDefaultsController.sharedUserDefaultsController;
    NSString *keyPath = @"values.shortcut";
    NSDictionary *options = @{NSValueTransformerNameBindingOption: NSSecureUnarchiveFromDataTransformerName};

    SRShortcutAction *shortcutAction = [SRShortcutAction shortcutActionWithKeyPath:keyPath
                                                                          ofObject:_defaults
                                                                     actionHandler:^BOOL(SRShortcutAction *anAction) {
        [[NSApp appDelegate] startStop:nil];
        return YES;
    }];
    [[SRGlobalShortcutMonitor sharedMonitor] addAction:shortcutAction forKeyEvent:SRKeyEventTypeDown];

    [shortcutRecorder bind:NSValueBinding toObject:_defaults withKeyPath:keyPath options:options];

    [self installMenuBarStatusItem];
    
    // Position the mode button in the titlebar
    NSView *frameView = [[window contentView] superview];
    [frameView addSubview:modeButton];
    [modeButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [modeButton.trailingAnchor constraintEqualToAnchor:frameView.trailingAnchor constant:-6],
        [modeButton.topAnchor constraintEqualToAnchor:frameView.topAnchor constant:6]
    ]];
    
    if (![userDefaults boolForKey:@"Advanced"])
        [self setMode:NO];
    else
        [self setMode:YES];

    NSData* data = [userDefaults objectForKey:@"State"];
    if (data)
    {
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        [self decodeRestorableState:unarchiver];
    }
    
    [window setDelegate:(id<NSWindowDelegate>)self];
}

- (void)configureMenuBarUtilityWindow {
    [window setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [window setShowsResizeIndicator:NO];
    [window setStyleMask:([window styleMask] & ~NSWindowStyleMaskMiniaturizable)];
    [[window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
}

- (void)windowWillClose:(NSNotification*)note {
    @try {
        NSMenuItem* windowMenuItem = [[NSApp mainMenu] itemAtIndex:[[[NSApp mainMenu] itemArray] count]-2];
        
        NSMenuItem* separator = [NSMenuItem separatorItem];
        NSMenuItem* showAutoclick = [[NSMenuItem alloc] initWithTitle:@"Show Autoclick" action:@selector(applicationShouldHandleReopen:hasVisibleWindows:) keyEquivalent:@""];
        
        [[windowMenuItem submenu] insertItem:separator atIndex:0];
        [[windowMenuItem submenu] insertItem:showAutoclick atIndex:0];
    }
    @catch (NSException *exception) {
        
    }
}

- (void)windowDidBecomeKey:(NSNotification*)note {
    @try {
        NSMenuItem* windowMenuItem = [[NSApp mainMenu] itemAtIndex:[[[NSApp mainMenu] itemArray] count]-2];
        
        NSMenu* submenu = [windowMenuItem submenu];
        if ([[[submenu itemAtIndex:0] title] isEqualToString:@"Show Autoclick"])
        {
            [submenu removeItemAtIndex:0];
            [submenu removeItemAtIndex:0];
        }
    }
    @catch (NSException *exception) {
        
    }
}

- (IBAction)changeMode:(id)sender {
    [self setMode:!mode];
}

/* val: YES = Advanced / NO = Basic */
- (void)setMode:(BOOL)val {
    if (!val)
    {
        [modeButton setTitle:@"Basic"];
                
        [[advancedBox subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            [obj setHidden:YES];
        }];
                
        NSRect frame = [window frame];
        if (frame.size.height >= 400)
        {
            frame.size.height = 217;
            frame.origin.y += 415 - 217;

            [window setFrame:frame display:YES animate:YES];
        }
    }
    else
    {
        [modeButton setTitle:@"Advanced"];
                
        [[advancedBox subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
            [obj setHidden:NO];
        }];
        
        NSRect frame = [window frame];
        if (frame.size.height <= 300)
        {
            frame.size.height = 415;
            frame.origin.y -= 415 - 217;

            [window setFrame:frame display:YES animate:YES];    
        }
    }
    
    mode = val;
    [userDefaults setBool:val forKey:@"Advanced"];
}

- (IBAction)startStop:(id)sender {
    if ([clicker isClicking])
    {
        [clicker stopClicking];
    }
    else
    {
        if (![self ensureAccessibilityPermission]) {
            return;
        }

        if (![self ensureInputMonitoringPermission]) {
            return;
        }

        // Button
        int selectedButton;
        switch ([buttonSelector indexOfSelectedItem]) {
            case 0: selectedButton = LEFT; break;
            case 1: selectedButton = RIGHT; break;
            case 2: selectedButton = MIDDLE; break;
            default: selectedButton = LEFT; break;
        }
        
        // Rate
        NSInteger selectedRate = [rateSelector intValue];
        NSInteger selectedRateUnit = ([rateUnitSelector indexOfSelectedItem]==0)?1000:60000;

        double rate = selectedRateUnit / selectedRate; // a click every 'rate' (in ms)
        
        // Start Clicking or add the advanced preferences ?
        if (!mode)
            [clicker startClicking:selectedButton rate:rate startAfter:0 stopAfter:0 ifStationaryFor:0];
        else
        {
            NSInteger startAfter = ([startAfterCheckbox state])?([startAfterSelector intValue]*(([startAfterUnitSelector indexOfSelectedItem]==0)?1:60)):0;
                        
            NSInteger stopAfter = ([stopAfterCheckbox state])?([stopAfterSelector intValue]*(([stopAfterUnitSelector indexOfSelectedItem]==0)?1:60)):0;
                        
            NSInteger stationaryFor = ([ifStationaryCheckbox state])?([ifStationaryForCheckbox state]?[ifStationaryForSelector intValue]:1):0;
            
            [clicker startClicking:selectedButton rate:rate startAfter:startAfter stopAfter:stopAfter ifStationaryFor:stationaryFor];
        }
        
        [self startedClicking];
    }
}

- (BOOL)ensureAccessibilityPermission {
    if (AXIsProcessTrusted()) {
        return YES;
    }

    [statusLabel setStringValue:@"Accessibility permission required."];
    [self showPermissionAlertWithTitle:@"Allow Accessibility Access"
                               message:@"Enable Autoclick in System Settings > Privacy & Security > Accessibility, then quit and reopen Autoclick before starting."
                            settingsURL:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            promptOnce:YES];
    return NO;
}

- (BOOL)ensureInputMonitoringPermission {
    if (@available(macOS 10.15, *)) {
        if (IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted) {
            return YES;
        }

        [statusLabel setStringValue:@"Input Monitoring permission required."];
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);
        [self showPermissionAlertWithTitle:@"Allow Input Monitoring"
                                   message:@"Enable Autoclick in System Settings > Privacy & Security > Input Monitoring, then quit and reopen Autoclick before starting."
                               settingsURL:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                                promptOnce:NO];
        return NO;
    }

    return YES;
}

- (void)showPermissionAlertWithTitle:(NSString *)title message:(NSString *)message settingsURL:(NSString *)settingsURL promptOnce:(BOOL)promptOnce {
    if (promptOnce) {
        NSDictionary *options = @{(__bridge id) kAXTrustedCheckOptionPrompt : @YES};
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef) options);
    }

    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert addButtonWithTitle:@"Open Settings"];
    [alert addButtonWithTitle:@"Quit Autoclick"];
    [alert addButtonWithTitle:@"Not Now"];

    NSModalResponse response = [alert runModal];

    if (response == NSAlertFirstButtonReturn) {
        NSURL *url = [NSURL URLWithString:settingsURL];
        [[NSWorkspace sharedWorkspace] openURL:url];
        [NSApp terminate:self];
    } else if (response == NSAlertSecondButtonReturn) {
        [NSApp terminate:self];
    }
}

- (void)startedClicking {
    [modeButton setEnabled:NO];
    [startStopButton setTitle:@"Stop"];
    [self updateMenuBarStatus:@"On"];
    [menuBarStartStopItem setTitle:@"Stop Clicking"];
}

- (void)stoppedClicking {
    [modeButton setEnabled:YES];
    [startStopButton setTitle:@"Start"];
    [self updateMenuBarStatus:@"Off"];
    [menuBarStartStopItem setTitle:@"Start Clicking"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self applicationShouldHandleReopen:NSApp hasVisibleWindows:YES];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:self];
    
    return YES;
}

- (IBAction)applicationShouldHandleReopen:(id)sender {
    [self applicationShouldHandleReopen:NSApp hasVisibleWindows:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSKeyedArchiver* archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [self encodeRestorableState:archiver];
    [archiver finishEncoding];

    [userDefaults setObject:archiver.encodedData forKey:@"State"];
}

- (IBAction)changedState:(id)sender {
    if (sender == ifStationaryCheckbox)
    {
        [ifStationaryForCheckbox setEnabled:[ifStationaryCheckbox state]];
        [ifStationaryForSelector setEnabled:[ifStationaryCheckbox state]];
        [[ifStationaryForSelector stepper] setEnabled:[ifStationaryCheckbox state]];
        
        if ([ifStationaryCheckbox state])
            [ifStationaryForText setTextColor:[NSColor textColor]];
        else
            [ifStationaryForText setTextColor:[NSColor disabledControlTextColor]];
    }
}

- (id)init {
    self = [super init];
    
    if (self)
    {
        userDefaults = [NSUserDefaults standardUserDefaults];
        iconArray = [NSArray arrayWithObjects:[NSImage imageNamed:@"clicking.icns"], [NSImage imageNamed:@"clicking1.icns"], [NSImage imageNamed:@"clicking2.icns"], [NSImage imageNamed:@"clicking3.icns"], nil];
        iconTimer = nil;
        [self defaultIcon];
        clicker = nil;
    }
    
    return self;
}

#pragma mark - Help & Support

- (IBAction)openGitHub:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/joelfernandes23/Autoclick"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark - Menu Bar Status

- (void)installMenuBarStatusItem {
    menuBarOffImage = [self menuBarImageForStatus:@"Off"];
    menuBarActiveImage = [self menuBarImageForStatus:@"On"];
    menuBarPausedImage = [self menuBarImageForStatus:@"Paused"];
    menuBarWaitingImage = [self menuBarImageForStatus:@"Waiting"];

    menuBarStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];

    NSStatusBarButton *button = [menuBarStatusItem button];
    [button setToolTip:@"Autoclick status"];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Autoclick"];
    menuBarStateItem = [[NSMenuItem alloc] initWithTitle:@"Status: Off" action:nil keyEquivalent:@""];
    [menuBarStateItem setEnabled:NO];
    [menu addItem:menuBarStateItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *showItem = [[NSMenuItem alloc] initWithTitle:@"Show Autoclick" action:@selector(applicationShouldHandleReopen:) keyEquivalent:@""];
    [showItem setTarget:self];
    [menu addItem:showItem];

    menuBarStartStopItem = [[NSMenuItem alloc] initWithTitle:@"Start Clicking" action:@selector(startStop:) keyEquivalent:@""];
    [menuBarStartStopItem setTarget:self];
    [menu addItem:menuBarStartStopItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Autoclick" action:@selector(terminate:) keyEquivalent:@""];
    [quitItem setTarget:NSApp];
    [menu addItem:quitItem];

    [menuBarStatusItem setMenu:menu];
    [self updateMenuBarStatus:@"Off"];
}

- (void)updateMenuBarStatus:(NSString *)status {
    NSStatusBarButton *button = [menuBarStatusItem button];
    [button setTitle:@""];
    [button setImage:[self menuBarImageForCurrentStatus:status]];
    [menuBarStateItem setTitle:[NSString stringWithFormat:@"Status: %@", status]];
    [button setToolTip:[NSString stringWithFormat:@"Autoclick: %@", status]];
}

- (NSImage *)menuBarImageForCurrentStatus:(NSString *)status {
    if ([status isEqualToString:@"On"]) return menuBarActiveImage;
    if ([status isEqualToString:@"Paused"]) return menuBarPausedImage;
    if ([status isEqualToString:@"Waiting"]) return menuBarWaitingImage;
    return menuBarOffImage;
}

- (NSImage *)menuBarImageForStatus:(NSString *)status {
    NSSize size = NSMakeSize(18, 18);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];

    NSRect canvas = NSMakeRect(0, 0, size.width, size.height);
    BOOL active = [status isEqualToString:@"On"];
    BOOL paused = [status isEqualToString:@"Paused"];
    BOOL waiting = [status isEqualToString:@"Waiting"];

    if (active) {
        [[NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:1.0] setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(canvas, 1.0, 1.0)] fill];
    }

    NSColor *strokeColor = active ? NSColor.whiteColor : NSColor.labelColor;
    [strokeColor setStroke];

    NSBezierPath *mouse = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(5.0, 2.0, 8.0, 14.0) xRadius:4.0 yRadius:4.0];
    [mouse setLineWidth:1.6];
    [mouse stroke];

    NSBezierPath *divider = [NSBezierPath bezierPath];
    [divider moveToPoint:NSMakePoint(9.0, 3.0)];
    [divider lineToPoint:NSMakePoint(9.0, 7.0)];
    [divider setLineWidth:1.2];
    [divider stroke];

    if (paused || waiting) {
        [strokeColor setFill];

        if (paused) {
            NSRect leftBar = NSMakeRect(6.2, 7.1, 1.8, 5.4);
            NSRect rightBar = NSMakeRect(10.0, 7.1, 1.8, 5.4);
            [[NSBezierPath bezierPathWithRoundedRect:leftBar xRadius:0.7 yRadius:0.7] fill];
            [[NSBezierPath bezierPathWithRoundedRect:rightBar xRadius:0.7 yRadius:0.7] fill];
        } else {
            NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7.0, 8.0, 4.0, 4.0)];
            [dot fill];
        }
    }

    [image unlockFocus];
    [image setTemplate:!active];
    return image;
}

#pragma mark - Icon Handling

- (void)defaultIcon {
    if (DEBUG_ENABLED) NSLog(@"defaultIcon call");
    [iconTimer invalidate];
    [NSApp setApplicationIconImage:[NSImage imageNamed:@"default.icns"]];
    [self updateMenuBarStatus:@"Off"];
}

- (void)pausedIcon {
    if (DEBUG_ENABLED) NSLog(@"pausedIcon call");
    [iconTimer invalidate];
    [NSApp setApplicationIconImage:[NSImage imageNamed:@"paused.icns"]];
    [self updateMenuBarStatus:@"Paused"];
}

- (void)waitingIcon {
    if (DEBUG_ENABLED) NSLog(@"waitingIcon call");
    [iconTimer invalidate];
    [NSApp setApplicationIconImage:[NSImage imageNamed:@"waiting.icns"]];
    [self updateMenuBarStatus:@"Waiting"];
}

- (void)clickingIcon {
    if (DEBUG_ENABLED) NSLog(@"clickingIcon call");
    [self updateMenuBarStatus:@"On"];
    if (!iconTimer || ![iconTimer isValid])
    {
        iconIndex = 1;
        [NSApp setApplicationIconImage:[iconArray objectAtIndex:0]];
        iconTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(nextIcon) userInfo:nil repeats:YES];
    }
}
                     
- (void)nextIcon {
    if (DEBUG_ENABLED) NSLog(@"nextIcon call");
    iconIndex++;
    if (iconIndex >= [iconArray count]) iconIndex = 0;
    [NSApp setApplicationIconImage:[iconArray objectAtIndex:iconIndex]];
}

@end
