#import <AppKit/AppKit.h>

@protocol ClickerHost <NSObject>

@property (nonatomic, readonly) NSWindow *window;
@property (nonatomic, readonly) NSButton *modeButton;
@property (nonatomic, readonly) NSTextField *statusLabel;

- (void)stoppedClicking;

- (void)defaultIcon;
- (void)pausedIcon;
- (void)waitingIcon;
- (void)clickingIcon;

@end
