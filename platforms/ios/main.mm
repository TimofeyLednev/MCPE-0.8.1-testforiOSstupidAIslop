#ifdef MCPE_IOS
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
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

static void MCPEConfigureAudioSession(void) {
	Class sessionClass = NSClassFromString(@"AVAudioSession");
	if (!sessionClass) {
		return;
	}

	id session = [sessionClass sharedInstance];
	if (!session) {
		return;
	}

	if ([session respondsToSelector:@selector(setCategory:error:)]) {
		NSError* error = nil;
		[session setCategory:AVAudioSessionCategoryPlayback error:&error];
		if (error) {
			NSLog(@"[MCPE] audio session category setup failed: %@", error);
		}
	}

	if ([session respondsToSelector:@selector(setActive:error:)]) {
		NSError* error = nil;
		[session setActive:YES error:&error];
		if (error) {
			NSLog(@"[MCPE] audio session activation failed: %@", error);
		}
	} else if ([session respondsToSelector:@selector(setActive:)]) {
		[session setActive:YES];
	}
}

@interface MCPEKeyboardResponder : UIView <UIKeyInput, UITextInputTraits> {
	NSMutableString* _buffer;
}
- (void)setInitialText:(NSString*)text;
@end

@implementation MCPEKeyboardResponder

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		_buffer = [[NSMutableString alloc] init];
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		self.alpha = 0.01f;
		self.userInteractionEnabled = NO;
	}
	return self;
}

- (void)dealloc {
	[_buffer release];
	[super dealloc];
}

- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return [_buffer length] > 0; }

- (void)setInitialText:(NSString*)text {
	[_buffer setString:text ? text : @""];
}

- (void)insertText:(NSString*)text {
	if (!text || [text length] == 0) {
		return;
	}
	if ([text isEqualToString:@"\n"]) {
		Keyboard::feed(13, 1);
		Keyboard::feed(13, 0);
		return;
	}
	[_buffer appendString:text];
	Keyboard::feedText(std::string([text UTF8String]), 0);
}

- (void)deleteBackward {
	if ([_buffer length] > 0) {
		[_buffer deleteCharactersInRange:NSMakeRange([_buffer length] - 1, 1)];
	}
	Keyboard::feed(8, 1);
	Keyboard::feed(8, 0);
}

// UITextInputTraits. secureTextEntry disables the iOS 13+ continuous-path
// (QuickPath / slide-to-type) overlay and the predictive bar. That overlay's
// internal Auto Layout setup is what aborts on this off-screen responder, so
// turning it off is the actual crash fix. All of these traits exist since
// iOS 2-5, so the iOS 5.0 armv7 slice stays compatible.
- (UITextAutocapitalizationType)autocapitalizationType { return UITextAutocapitalizationTypeNone; }
- (UITextAutocorrectionType)autocorrectionType { return UITextAutocorrectionTypeNo; }
- (UITextSpellCheckingType)spellCheckingType { return UITextSpellCheckingTypeNo; }
- (UIKeyboardType)keyboardType { return UIKeyboardTypeDefault; }
- (UIKeyboardAppearance)keyboardAppearance { return UIKeyboardAppearanceDefault; }
- (UIReturnKeyType)returnKeyType { return UIReturnKeyDefault; }
- (BOOL)enablesReturnKeyAutomatically { return NO; }
- (BOOL)isSecureTextEntry { return YES; }

@end

// ---------------------------------------------------------------------------
// Globals shared with AppPlatform_iOS.mm (keyboard bridge).
// ---------------------------------------------------------------------------
static AppPlatform_iOS* g_platform = nullptr;
static NinecraftApp* g_app = nullptr;

@class MCPEViewController;
static MCPEViewController* g_viewController = nil;

// ===========================================================================
// View controller: owns the EAGLView, the CADisplayLink loop, touch input,
// and a hidden keyboard responder for the soft keyboard.
// ===========================================================================
@interface MCPEViewController : UIViewController {
	UIView* _rootView;
	EAGLView* _glView;
	CADisplayLink* _displayLink;
	BOOL _hasInit;
	BOOL _paused;
	MCPEKeyboardResponder* _keyboardField;
	UITouch* _mouseTouch;
}
- (void)showKeyboardWithText:(NSString*)text;
- (void)hideKeyboard;
- (void)pauseRendering;
- (void)resumeRendering;
@end

@implementation MCPEViewController

- (void)loadView {
	CGRect bounds = [UIScreen mainScreen].bounds;
	_rootView = [[UIView alloc] initWithFrame:bounds];
	_rootView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                             UIViewAutoresizingFlexibleHeight;
	_rootView.backgroundColor = [UIColor blackColor];
	_rootView.multipleTouchEnabled = YES;
	self.view = _rootView;

	_glView = [[EAGLView alloc] initWithFrame:bounds];
	_glView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                           UIViewAutoresizingFlexibleHeight;
	_glView.multipleTouchEnabled = YES;
	[_rootView addSubview:_glView];

	_keyboardField = [[MCPEKeyboardResponder alloc] initWithFrame:CGRectMake(-100.0, -100.0, 1.0, 1.0)];
	[_rootView addSubview:_keyboardField];
}

- (CGFloat)scale {
	if ([_glView respondsToSelector:@selector(contentScaleFactor)])
		return _glView.contentScaleFactor;
	return 1.0f;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[_glView createFramebuffer];

	g_platform->setScreenSize(_glView.backingWidth, _glView.backingHeight,
	                          [self scale]);

	_displayLink = [CADisplayLink displayLinkWithTarget:self
	                                           selector:@selector(tick:)];
	[_displayLink addToRunLoop:[NSRunLoop currentRunLoop]
	                   forMode:NSDefaultRunLoopMode];
}

- (void)tick:(CADisplayLink*)link {
	if (_paused) {
		return;
	}

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

- (void)pauseRendering {
	_paused = YES;
	_mouseTouch = nil;
	[_displayLink setPaused:YES];
}

- (void)resumeRendering {
	[_glView makeCurrent];
	[_glView destroyFramebuffer];
	[_glView createFramebuffer];
	[_displayLink setPaused:NO];
	_paused = NO;
}

- (void)feedTouches:(NSSet*)touches pressed:(BOOL)pressed moved:(BOOL)moved {
	CGFloat scale = [self scale];
	UITouch* primaryTouch = _mouseTouch;
	if (!primaryTouch && [touches count] > 0) {
		primaryTouch = [touches anyObject];
		if (pressed && !moved) {
			_mouseTouch = primaryTouch;
		}
	}

	for (UITouch* t in touches) {
		CGPoint p = [t locationInView:_glView];
		int16_t x = (int16_t)(p.x * scale);
		int16_t y = (int16_t)(p.y * scale);
		int8_t pid = (int8_t)(((intptr_t)t >> 4) & 0x7);
		if (moved) {
			Multitouch::feed(0, 0, x, y, pid);
		} else {
			Multitouch::feed(1, pressed ? 1 : 0, x, y, pid);
		}
	}

	if (primaryTouch && [touches containsObject:primaryTouch]) {
		CGPoint p = [primaryTouch locationInView:_glView];
		int16_t x = (int16_t)(p.x * scale);
		int16_t y = (int16_t)(p.y * scale);
		if (moved) {
			Mouse::feed(0, 0, x, y);
		} else {
			Mouse::feed(1, pressed ? 1 : 0, x, y);
			if (!pressed) {
				_mouseTouch = nil;
			}
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
	if (_mouseTouch && [touches containsObject:_mouseTouch]) {
		_mouseTouch = nil;
	}
	[self feedTouches:touches pressed:NO moved:NO];
}

- (void)showKeyboardWithText:(NSString*)text {
	[_keyboardField setInitialText:text];
	[_keyboardField becomeFirstResponder];
}
- (void)hideKeyboard {
	[_keyboardField resignFirstResponder];
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
	MCPEConfigureAudioSession();

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
	if (g_viewController) {
		[g_viewController pauseRendering];
	}
	if (g_app) {
		g_app->pauseGame(1);
		if (g_app->level) {
			g_app->cancelLocateMultiplayer();
		}
	}
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
	if (g_viewController) {
		[g_viewController pauseRendering];
	}
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
	if (g_viewController) {
		[g_viewController resumeRendering];
	}
}

- (void)applicationWillEnterForeground:(UIApplication*)application {
	if (g_viewController) {
		[g_viewController resumeRendering];
	}
}

@end

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
