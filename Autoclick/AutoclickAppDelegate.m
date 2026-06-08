//
//  AutoclickAppDelegate.m
//  Autoclick
//

#import "AutoclickAppDelegate.h"
#import "Autoclick-Swift.h"
@import IOKit;

static NSValueTransformerName const AutoclickShortcutTransformerName = @"AutoclickShortcutTransformer";

@interface AutoclickShortcutTransformer : NSSecureUnarchiveFromDataTransformer
@end

@implementation AutoclickShortcutTransformer

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[
        SRShortcut.class,
        NSDictionary.class,
        NSString.class,
        NSNumber.class
    ];
}

- (id)transformedValue:(id)value {
    if (!value || (NSNull *)value == NSNull.null) {
        return nil;
    }

    if ([value isKindOfClass:SRShortcut.class]) {
        return value;
    }

    if ([value isKindOfClass:NSDictionary.class]) {
        return [SRShortcut shortcutWithDictionary:value];
    }

    return [super transformedValue:value];
}

@end

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
    [state encodeInteger:[ifStationaryForUnitSelector indexOfSelectedItem] forKey:@"ifStationaryForUnitSelector"];
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
    [ifStationaryForUnitSelector selectItemAtIndex:[state decodeIntegerForKey:@"ifStationaryForUnitSelector"]];
    
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
    [self configureModernInterface];
    [rateSelector syncWithStepper];
    [startAfterSelector syncWithStepper];
    [stopAfterSelector syncWithStepper];
    [ifStationaryForSelector syncWithStepper];

    [self registerDefaultShortcutIfNeeded];

    shortcutValidator = [[SRShortcutValidator alloc] initWithDelegate:nil];
    [shortcutRecorder setDelegate:shortcutValidator];
    [shortcutRecorder setAllowedModifierFlags:SRCocoaModifierFlagsMask
                        requiredModifierFlags:(NSEventModifierFlagCommand | NSEventModifierFlagOption)
                     allowsEmptyModifierFlags:NO];

    _defaults = NSUserDefaultsController.sharedUserDefaultsController;
    NSString *keyPath = @"values.shortcut";
    [NSValueTransformer setValueTransformer:[[AutoclickShortcutTransformer alloc] init]
                                     forName:AutoclickShortcutTransformerName];
    NSDictionary *options = @{NSValueTransformerNameBindingOption: AutoclickShortcutTransformerName};

    startStopShortcutAction = [SRShortcutAction shortcutActionWithKeyPath:keyPath
                                                                 ofObject:_defaults
                                                            actionHandler:^BOOL(SRShortcutAction *anAction) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSApp appDelegate] startStop:nil];
        });
        return YES;
    }];
    [[SRGlobalShortcutMonitor sharedMonitor] addAction:startStopShortcutAction forKeyEvent:SRKeyEventTypeDown];

    [shortcutRecorder bind:NSValueBinding toObject:_defaults withKeyPath:keyPath options:options];

    [self installMenuBarStatusItem];

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

- (void)registerDefaultShortcutIfNeeded {
    if ([userDefaults objectForKey:@"shortcut"]) {
        return;
    }

    SRShortcut *defaultShortcut = [SRShortcut shortcutWithKeyEquivalent:@"⌃⌥⌘C"];
    if (!defaultShortcut) {
        return;
    }

    NSData *shortcutData = [NSKeyedArchiver archivedDataWithRootObject:defaultShortcut
                                                 requiringSecureCoding:YES
                                                                 error:nil];
    if (shortcutData) {
        [userDefaults setObject:shortcutData forKey:@"shortcut"];
    }
}

- (void)configureMenuBarUtilityWindow {
    [window setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [window setShowsResizeIndicator:NO];
    [window setStyleMask:([window styleMask] & ~(NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable))];
    [[window standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    [[window standardWindowButton:NSWindowZoomButton] setHidden:YES];
}

- (void)configureModernInterface {
    [window setTitleVisibility:NSWindowTitleHidden];
    [window setTitlebarAppearsTransparent:NO];
    [window setMovableByWindowBackground:YES];
    [window setBackgroundColor:NSColor.windowBackgroundColor];

    [modeButton setHidden:YES];

    [self configureModeControl];
    [self configureWindowSections];
    [self configureControlStyling];
    [self configureStationaryUnitSelector];
}

- (void)configureModeControl {
    modeSegmentedControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Basic", @"Advanced"]
                                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                    target:self
                                                                    action:@selector(changeMode:)];
    [modeSegmentedControl setSegmentStyle:NSSegmentStyleTexturedRounded];
    [modeSegmentedControl setControlSize:NSControlSizeSmall];
    [modeSegmentedControl setToolTip:@"Switch mode"];
    [modeSegmentedControl setFrame:NSMakeRect(0.0, 3.0, 176.0, 24.0)];

    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 186.0, 30.0)];
    [accessoryView addSubview:modeSegmentedControl];

    modeTitlebarAccessory = [[NSTitlebarAccessoryViewController alloc] init];
    [modeTitlebarAccessory setView:accessoryView];
    [modeTitlebarAccessory setLayoutAttribute:NSLayoutAttributeRight];
    [window addTitlebarAccessoryViewController:modeTitlebarAccessory];
}

- (void)configureWindowSections {
    [topBorder setFillColor:NSColor.separatorColor];
    [bottomBorder setFillColor:NSColor.separatorColor];
    [advancedBox setFillColor:NSColor.controlBackgroundColor];
    [advancedBox setBorderColor:NSColor.clearColor];
}

- (void)configureControlStyling {
    [self styleLabelsInView:[window contentView]];

    [statusLabel setFont:[NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold]];
    [statusLabel setTextColor:NSColor.labelColor];

    [startStopButton setControlSize:NSControlSizeRegular];
    [startStopButton setBezelStyle:NSBezelStyleRounded];
    [startStopButton setToolTip:@"Start or stop clicking"];
    [self updateStartStopButtonForClicking:NO];

    NSArray<NSPopUpButton *> *popUpButtons = @[
        buttonSelector,
        rateUnitSelector,
        startAfterUnitSelector,
        stopAfterUnitSelector
    ];
    for (NSPopUpButton *popUpButton in popUpButtons) {
        [popUpButton setControlSize:NSControlSizeRegular];
        [[popUpButton cell] setBezelStyle:NSBezelStyleRounded];
    }

    NSArray<NSTextField *> *numberFields = @[
        rateSelector,
        startAfterSelector,
        stopAfterSelector,
        ifStationaryForSelector
    ];
    NSFont *numberFont = [NSFont monospacedDigitSystemFontOfSize:13.0 weight:NSFontWeightRegular];
    for (NSTextField *numberField in numberFields) {
        [numberField setFont:numberFont];
        [numberField setAlignment:NSTextAlignmentRight];
    }

    NSArray<NSButton *> *checkboxes = @[
        startAfterCheckbox,
        stopAfterCheckbox,
        ifStationaryCheckbox,
        ifStationaryForCheckbox
    ];
    for (NSButton *checkbox in checkboxes) {
        [checkbox setControlSize:NSControlSizeRegular];
    }

    [buttonSelector setToolTip:@"Mouse button to click"];
    [rateSelector setToolTip:@"Number of clicks"];
    [rateUnitSelector setToolTip:@"Click rate unit"];
    [startAfterCheckbox setToolTip:@"Delay clicking after starting"];
    [stopAfterCheckbox setToolTip:@"Stop clicking after a duration"];
    [ifStationaryCheckbox setToolTip:@"Only click while the pointer has not moved"];
    [shortcutRecorder setToolTip:@"Global shortcut to start or stop clicking. Defaults to Control-Option-Command-C."];
}

- (void)styleLabelsInView:(NSView *)view {
    for (NSView *subview in [view subviews]) {
        if ([subview isKindOfClass:[NSTextField class]]) {
            NSTextField *textField = (NSTextField *)subview;
            if (![textField isEditable] && ![textField isSelectable]) {
                [textField setBordered:NO];
                [textField setDrawsBackground:NO];

                if (textField == statusLabel) {
                    [textField setTextColor:NSColor.labelColor];
                } else if ([[textField font] pointSize] <= [NSFont smallSystemFontSize]) {
                    [textField setTextColor:NSColor.secondaryLabelColor];
                } else if ([[textField cell] isEnabled]) {
                    [textField setTextColor:NSColor.labelColor];
                } else {
                    [textField setTextColor:NSColor.disabledControlTextColor];
                }
            }
        }

        [self styleLabelsInView:subview];
    }
}

- (void)updateStartStopButtonForClicking:(BOOL)isClicking {
    if ([startStopButton respondsToSelector:@selector(setBezelColor:)]) {
        [startStopButton setBezelColor:isClicking ? NSColor.systemRedColor : NSColor.controlAccentColor];
    }
}

- (void)configureStationaryUnitSelector {
    ifStationaryForUnitSelector = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(146.0, 58.0, 91.0, 26.0) pullsDown:NO];
    [ifStationaryForUnitSelector addItemsWithTitles:@[@"seconds", @"minutes"]];
    [[ifStationaryForUnitSelector cell] setBezelStyle:NSBezelStyleRounded];
    [ifStationaryForUnitSelector setControlSize:NSControlSizeRegular];
    [ifStationaryForUnitSelector setToolTip:@"Stationary duration unit"];
    [ifStationaryForUnitSelector setEnabled:[ifStationaryCheckbox state]];

    NSView *advancedContentView = [advancedBox contentView];
    [advancedContentView addSubview:ifStationaryForUnitSelector];

    [ifStationaryForText setStringValue:@"or longer"];
    [ifStationaryForText setFrame:NSMakeRect(240.0, 64.0, 74.0, 17.0)];
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
    if (sender == modeSegmentedControl) {
        [self setMode:[modeSegmentedControl selectedSegment] == 1];
    } else {
        [self setMode:!mode];
    }
}

/* val: YES = Advanced / NO = Basic */
- (void)setMode:(BOOL)val {
    [modeSegmentedControl setSelectedSegment:val ? 1 : 0];

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
                        
            NSInteger stationaryUnit = ([ifStationaryForUnitSelector indexOfSelectedItem] == 0) ? 1 : 60;
            NSInteger stationaryFor = ([ifStationaryCheckbox state])?([ifStationaryForCheckbox state]?([ifStationaryForSelector intValue] * stationaryUnit):1):0;
            
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
                               message:@"Enable Autoclick in System Settings > Privacy & Security > Accessibility, then return to Autoclick and click Start again."
                            settingsURL:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    return NO;
}

- (BOOL)ensureInputMonitoringPermission {
    if (@available(macOS 10.15, *)) {
        if (IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted) {
            return YES;
        }

        [statusLabel setStringValue:@"Input Monitoring permission required."];
        [self showPermissionAlertWithTitle:@"Allow Input Monitoring"
                                   message:@"Enable Autoclick in System Settings > Privacy & Security > Input Monitoring, then return to Autoclick and click Start again."
                               settingsURL:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"];
        return NO;
    }

    return YES;
}

- (void)showPermissionAlertWithTitle:(NSString *)title message:(NSString *)message settingsURL:(NSString *)settingsURL {
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
    } else if (response == NSAlertSecondButtonReturn) {
        [NSApp terminate:self];
    }
}

- (void)startedClicking {
    [modeButton setEnabled:NO];
    [modeSegmentedControl setEnabled:NO];
    [startStopButton setTitle:@"Stop"];
    [self updateStartStopButtonForClicking:YES];
    [self updateMenuBarStatus:@"On"];
    [menuBarStartStopItem setTitle:@"Stop Clicking"];
}

- (void)stoppedClicking {
    [modeButton setEnabled:YES];
    [modeSegmentedControl setEnabled:YES];
    [startStopButton setTitle:@"Start"];
    [self updateStartStopButtonForClicking:NO];
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
        [ifStationaryForUnitSelector setEnabled:[ifStationaryCheckbox state]];
        
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
    menuBarCurrentStatus = [status copy];

    [button setTitle:@""];
    [menuBarStateItem setTitle:[NSString stringWithFormat:@"Status: %@", status]];
    [button setToolTip:[NSString stringWithFormat:@"Autoclick: %@", status]];

    if ([status isEqualToString:@"On"]) {
        [self startMenuBarPulsing];
    } else {
        [self stopMenuBarPulsing];
        [button setImage:[self menuBarImageForCurrentStatus:status]];
    }
}

- (NSImage *)menuBarImageForCurrentStatus:(NSString *)status {
    if ([status isEqualToString:@"On"]) return menuBarActiveImage;
    if ([status isEqualToString:@"Paused"]) return menuBarPausedImage;
    if ([status isEqualToString:@"Waiting"]) return menuBarWaitingImage;
    return menuBarOffImage;
}

- (void)startMenuBarPulsing {
    NSStatusBarButton *button = [menuBarStatusItem button];
    menuBarPulseAlpha = 1.0;
    menuBarPulseIncreasing = NO;
    [button setImage:menuBarActiveImage];

    if (!menuBarPulseTimer || ![menuBarPulseTimer isValid]) {
        menuBarPulseTimer = [NSTimer timerWithTimeInterval:0.06
                                                    target:self
                                                  selector:@selector(updateMenuBarPulse)
                                                  userInfo:nil
                                                   repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:menuBarPulseTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopMenuBarPulsing {
    [menuBarPulseTimer invalidate];
    menuBarPulseTimer = nil;
    menuBarPulseAlpha = 1.0;
    menuBarPulseIncreasing = NO;
}

- (void)updateMenuBarPulse {
    if (![menuBarCurrentStatus isEqualToString:@"On"]) {
        [self stopMenuBarPulsing];
        return;
    }

    CGFloat minimumAlpha = 0.36;
    CGFloat maximumAlpha = 1.0;
    CGFloat step = 0.055;

    menuBarPulseAlpha += menuBarPulseIncreasing ? step : -step;
    if (menuBarPulseAlpha <= minimumAlpha) {
        menuBarPulseAlpha = minimumAlpha;
        menuBarPulseIncreasing = YES;
    } else if (menuBarPulseAlpha >= maximumAlpha) {
        menuBarPulseAlpha = maximumAlpha;
        menuBarPulseIncreasing = NO;
    }

    NSStatusBarButton *button = [menuBarStatusItem button];
    [button setImage:[self menuBarImageForStatus:@"On" pulseAlpha:menuBarPulseAlpha]];
}

- (NSImage *)menuBarImageForStatus:(NSString *)status {
    return [self menuBarImageForStatus:status pulseAlpha:1.0];
}

- (NSImage *)menuBarImageForStatus:(NSString *)status pulseAlpha:(CGFloat)pulseAlpha {
    NSSize size = NSMakeSize(18, 18);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];

    NSRect canvas = NSMakeRect(0, 0, size.width, size.height);
    BOOL active = [status isEqualToString:@"On"];
    BOOL paused = [status isEqualToString:@"Paused"];
    BOOL waiting = [status isEqualToString:@"Waiting"];

    if (active) {
        CGFloat clampedPulseAlpha = MIN(MAX(pulseAlpha, 0.0), 1.0);
        CGFloat glowAlpha = 0.22 + (0.78 * clampedPulseAlpha);
        NSColor *glowColor = [NSColor colorWithCalibratedRed:0.0
                                                       green:0.48
                                                        blue:1.0
                                                       alpha:glowAlpha];
        [glowColor setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(canvas, 1.0, 1.0)] fill];
    }

    NSColor *pointerFillColor = active ? NSColor.whiteColor : NSColor.blackColor;
    NSColor *pointerStrokeColor = active ? [[NSColor blackColor] colorWithAlphaComponent:0.22] : NSColor.blackColor;

    NSBezierPath *pointer = [NSBezierPath bezierPath];
    [pointer moveToPoint:NSMakePoint(4.5, 2.4)];
    [pointer lineToPoint:NSMakePoint(4.5, 15.6)];
    [pointer lineToPoint:NSMakePoint(14.3, 6.4)];
    [pointer lineToPoint:NSMakePoint(9.8, 6.0)];
    [pointer lineToPoint:NSMakePoint(12.3, 1.9)];
    [pointer lineToPoint:NSMakePoint(10.1, 0.8)];
    [pointer lineToPoint:NSMakePoint(7.7, 4.9)];
    [pointer closePath];
    [pointer setLineJoinStyle:NSLineJoinStyleRound];
    [pointer setLineWidth:1.0];

    [pointerFillColor setFill];
    [pointer fill];
    [pointerStrokeColor setStroke];
    [pointer stroke];

    if (paused || waiting) {
        [NSColor.blackColor setFill];

        if (paused) {
            NSRect leftBar = NSMakeRect(10.4, 3.1, 1.8, 5.4);
            NSRect rightBar = NSMakeRect(13.3, 3.1, 1.8, 5.4);
            [[NSBezierPath bezierPathWithRoundedRect:leftBar xRadius:0.7 yRadius:0.7] fill];
            [[NSBezierPath bezierPathWithRoundedRect:rightBar xRadius:0.7 yRadius:0.7] fill];
        } else {
            NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(11.0, 4.0, 4.2, 4.2)];
            [dot fill];
        }
    }

    [image unlockFocus];
    [image setTemplate:NO];
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
