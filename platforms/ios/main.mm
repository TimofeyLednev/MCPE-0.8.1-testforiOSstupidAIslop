#ifdef MCPE_IOS
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <sys/time.h>

#include <_types.h>
#include <utils.h>
#include <AppContext.hpp>
#include <NinecraftApp.hpp>
#include <input/Mouse.hpp>
#include <input/Multitouch.hpp>
#include <input/Keyboard.hpp>

#include "EAGLView.h"
#include "AppPlatform_iOS.hpp"

// ---------------------------------------------------------------------------
// Globals shared with AppPlatform_iOS.mm (keyboard bridge).
// ---------------------------------------------------------------------------
static AppPlatform_iOS* g_platform = nullptr;
static NinecraftApp* g_app = nullptr;

@class MCPEViewController;
static MCPEViewController* g_viewController = nil;

// ===========================================================================
// View controller: owns the EAGLView, the CADisplayLink loop, touch input,
// and a hidden text field for the soft keyboard.
// ===========================================================================
@interface MCPEViewController : UIViewController <UITextFieldDelegate> {
	EAGLView* _glView;
	CADisplayLink* _displayLink;
	BOOL _hasInit;
	UITextField* _keyboardField;
}
- (void)showKeyboardWithText:(NSString*)text;
- (void)hideKeyboard;
@end

@implementation MCPEViewController

- (void)loadView {
	CGRect bounds = [UIScreen mainScreen].bounds;
	_glView = [[EAGLView alloc] initWithFrame:bounds];
	_glView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                           UIViewAutoresizingFlexibleHeight;
	_glView.multipleTouchEnabled = YES;
	self.view = _glView;

	_keyboardField = [[UITextField alloc] initWithFrame:CGRectZero];
	_keyboardField.delegate = self;
	_keyboardField.autocorrectionType = UITextAutocorrectionTypeNo;
	_keyboardField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	_keyboardField.hidden = YES;
	[_glView addSubview:_keyboardField];
}

- (CGFloat)scale {
	if ([_glView respondsToSelector:@selector(contentScaleFactor)])
		return _glView.contentScaleFactor;
	return 1.0f;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[_glView createFramebuffer];

	// Tell the platform / game the real pixel resolution.
	g_platform->setScreenSize(_glView.backingWidth, _glView.backingHeight,
	                          [self scale]);

	_displayLink = [CADisplayLink displayLinkWithTarget:self
	                                           selector:@selector(tick:)];
	[_displayLink addToRunLoop:[NSRunLoop currentRunLoop]
	                   forMode:NSDefaultRunLoopMode];
}

- (void)tick:(CADisplayLink*)link {
	[_glView setFramebuffer];

	if (!_hasInit) {
		_hasInit = YES;
		g_app->init();
		g_app->setSize(_glView.backingWidth, _glView.backingHeight);
	}

	g_app->update();

	[_glView presentFramebuffer];

	if (g_app->wantToQuit()) {
		[_displayLink invalidate];
		_displayLink = nil;
	}
}

// --- touch -> Multitouch/Mouse --------------------------------------------
- (void)feedTouches:(NSSet*)touches pressed:(BOOL)pressed moved:(BOOL)moved {
	CGFloat scale = [self scale];
	for (UITouch* t in touches) {
		CGPoint p = [t locationInView:_glView];
		int16_t x = (int16_t)(p.x * scale);
		int16_t y = (int16_t)(p.y * scale);
		// pointer id: stable-ish per touch object hash, clamped in feed().
		int8_t pid = (int8_t)(((intptr_t)t >> 4) & 0x7);
		if (moved) {
			Multitouch::feed(0, 0, x, y, pid);
		} else {
			Multitouch::feed(1, pressed ? 1 : 0, x, y, pid);
		}
		// Drive the single-pointer Mouse too (menus use it like a cursor).
		if (pid == 0) {
			if (moved) Mouse::feed(0, 0, x, y);
			else Mouse::feed(1, pressed ? 1 : 0, x, y);
		}
	}
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)e {
	[self feedTouches:touches pressed:YES moved:NO];
}
- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)e {
	[self feedTouches:touches pressed:YES moved:YES];
}
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)e {
	[self feedTouches:touches pressed:NO moved:NO];
}
- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)e {
	[self feedTouches:touches pressed:NO moved:NO];
}

// --- soft keyboard ---------------------------------------------------------
- (void)showKeyboardWithText:(NSString*)text {
	_keyboardField.text = text ?: @"";
	[_keyboardField becomeFirstResponder];
}
- (void)hideKeyboard {
	[_keyboardField resignFirstResponder];
}

- (BOOL)textField:(UITextField*)tf
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString*)string {
	if (string.length == 0) {
		// backspace
		Keyboard::feed(8, 1);
		Keyboard::feed(8, 0);
	} else {
		Keyboard::feedText(std::string([string UTF8String]), 0);
	}
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField*)tf {
	Keyboard::feed(13, 1);
	Keyboard::feed(13, 0);
	return YES;
}

- (BOOL)prefersStatusBarHidden { return YES; }

@end

// ===========================================================================
// App delegate.
// ===========================================================================
@interface MCPEAppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow* _window;
}
@end

@implementation MCPEAppDelegate

- (BOOL)application:(UIApplication*)application
didFinishLaunchingWithOptions:(NSDictionary*)options {
	[application setStatusBarHidden:YES];
	[application setIdleTimerDisabled:YES];

	_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

	g_viewController = [[MCPEViewController alloc] init];
	if ([_window respondsToSelector:@selector(setRootViewController:)]) {
		_window.rootViewController = g_viewController;
	} else {
		[_window addSubview:g_viewController.view];
	}
	[_window makeKeyAndVisible];
	return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application {
	if (g_app) g_app->pauseGame(1);
}

@end

// ===========================================================================
// Keyboard bridge used by AppPlatform_iOS.
// ===========================================================================
void MCPE_iOS_ShowKeyboard(const std::string& current) {
	NSString* s = [NSString stringWithUTF8String:current.c_str()];
	[g_viewController performSelectorOnMainThread:@selector(showKeyboardWithText:)
	                                   withObject:s
	                                waitUntilDone:NO];
}
void MCPE_iOS_HideKeyboard(void) {
	[g_viewController performSelectorOnMainThread:@selector(hideKeyboard)
	                                   withObject:nil
	                                waitUntilDone:NO];
}

// ===========================================================================
// Entry point.
// ===========================================================================
int main(int argc, char* argv[]) {
	@autoreleasepool {
		struct timeval start;
		gettimeofday(&start, 0);
		startedAtSec = start.tv_sec;

		static AppPlatform_iOS platform;
		g_platform = &platform;

		NinecraftApp* app = new NinecraftApp();
		g_app = app;

		AppContext ctx;
		ctx.platform = &platform;
		app->context = ctx;

		// Game data path: app sandbox Documents directory.
		@autoreleasepool {
			NSArray* dirs = NSSearchPathForDirectoriesInDomains(
				NSDocumentDirectory, NSUserDomainMask, YES);
			if ([dirs count] > 0) {
				std::string docs([[dirs objectAtIndex:0] UTF8String]);
				app->dataPathMaybe = docs;
				app->field_CC4 = docs;
			}
		}

		return UIApplicationMain(argc, argv, nil, @"MCPEAppDelegate");
	}
}
#endif
