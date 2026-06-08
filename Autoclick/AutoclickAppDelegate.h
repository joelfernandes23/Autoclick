//
//  AutoclickAppDelegate.h
//  Autoclick
//

#import <Cocoa/Cocoa.h>
#import "ClickerHost.h"
#import <ShortcutRecorder/ShortcutRecorder.h>

@class AutoclickAppDelegate;
@class Clicker;
@class MBNumberField;

@interface NSApplication (AppDelegate)
- (AutoclickAppDelegate *)appDelegate;
@end

@interface AutoclickAppDelegate : NSObject <NSApplicationDelegate, ClickerHost> {
    __unsafe_unretained NSWindow *window;
    
    BOOL mode;
    __unsafe_unretained IBOutlet NSButton* modeButton;
    IBOutlet NSButton* startStopButton;
    
    IBOutlet NSBox* topBorder;
    IBOutlet NSBox* bottomBorder;
    IBOutlet NSBox* advancedBox;
    
    IBOutlet NSTextField* statusLabel;
    
    NSUserDefaults* userDefaults;
    
    Clicker* clicker;
    
    // Values
    IBOutlet NSPopUpButton* buttonSelector;
    IBOutlet MBNumberField* rateSelector;
    IBOutlet NSPopUpButton* rateUnitSelector;
    
    IBOutlet MBNumberField* startAfterSelector;
    IBOutlet NSPopUpButton* startAfterUnitSelector;
    IBOutlet NSButton* startAfterCheckbox;
    
    IBOutlet MBNumberField* stopAfterSelector;
    IBOutlet NSPopUpButton* stopAfterUnitSelector;
    IBOutlet NSButton* stopAfterCheckbox;
    
    IBOutlet NSButton* ifStationaryCheckbox;
    IBOutlet NSButton* ifStationaryForCheckbox;
    IBOutlet MBNumberField* ifStationaryForSelector;
    NSPopUpButton* ifStationaryForUnitSelector;
    IBOutlet NSTextField* ifStationaryForText;
    
    IBOutlet SRRecorderControl* shortcutRecorder;
    
    NSArray* iconArray;
    NSInteger iconIndex;
    NSTimer* iconTimer;

    NSSegmentedControl* modeSegmentedControl;
    NSStatusItem* menuBarStatusItem;
    NSMenuItem* menuBarStateItem;
    NSMenuItem* menuBarStartStopItem;
    NSImage* menuBarOffImage;
    NSImage* menuBarActiveImage;
    NSImage* menuBarActiveDimImage;
    NSImage* menuBarPausedImage;
    NSImage* menuBarWaitingImage;
    NSTimer* menuBarBlinkTimer;
    BOOL menuBarBlinkOn;
    NSString* menuBarCurrentStatus;
    NSTitlebarAccessoryViewController* modeTitlebarAccessory;
    SRShortcutAction* startStopShortcutAction;
    SRShortcutValidator* shortcutValidator;
}

@property (nonatomic, assign) IBOutlet NSWindow *window;
@property (nonatomic, assign) IBOutlet NSButton* modeButton;
@property (nonatomic, readonly) IBOutlet NSTextField* statusLabel;
@property (nonatomic, readonly) IBOutlet NSButton* startStopButton;

- (void)startedClicking;
- (void)stoppedClicking;

- (IBAction)changedState:(id)sender;
- (IBAction)startStop:(id)sender;

#pragma mark - Icon Handling

- (void)defaultIcon;
- (void)pausedIcon;
- (void)waitingIcon;
- (void)clickingIcon;

@end
