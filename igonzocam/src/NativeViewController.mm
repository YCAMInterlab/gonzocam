#import "NativeViewController.h"
#import "SettingViewController.h"

#include "cinder/app/AppCocoaTouch.h"

@interface NativeViewController ()

@property (nonatomic) UIButton *infoButton;

//- (NSArray *)tabBarItems;
//- (void)barButtonTapped:(UIBarButtonItem *)sender;
- (void)addEmptyViewControllerToFront;
- (void)infoButtonWasTapped:(id)sender;

@end


@implementation NativeViewController

// note: these synthesizers aren't necessary with Clang 3.0 since it will autogenerate the same thing, but it is added for clarity
@synthesize infoButton = _infoButton;
@synthesize infoButtonCallback = _infoButtonCallback;

@synthesize mSettingViewController = _mSettingViewController;
// -------------------------------------------------------------------------------------------------
#pragma mark - Public: Adding CinderView to Heirarchy

// Note: changing the parent viewcontroller may inhibit the App's orientation related signals.
// To regain signals like willRotate and didRotate, emit them from this view controller

// Get CinderView's parent view controller so we can add it to a our stack, then set some navigation items
- (void)addCinderViewToFront
{
	UIViewController *cinderViewParent = ci::app::getWindow()->getNativeViewController();

	self.viewControllers = @[cinderViewParent];

	cinderViewParent.title = @"Main View";
	cinderViewParent.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.infoButton];    
}

// Get this app's CinderView and add it as a child in our view heirarchy, in this case the left nav bar button.
// Manually resizing is necessary.
- (void)addCinderViewAsBarButton
{
	[self addEmptyViewControllerToFront];
	UIViewController *front = [self.viewControllers objectAtIndex:0];
	UIView *cinderView = (__bridge UIView *)ci::app::getWindow()->getNative();
	cinderView.frame = CGRectMake( 0, 0, 60, self.navigationBar.frame.size.height );
	front.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cinderView];
}

- (void)gotoSetupPanel
{
    // call directory
    [self pushViewController:_mSettingViewController animated:YES];
}

// -------------------------------------------------------------------------------------------------
#pragma mark - UIViewController overridden methods

- (void)viewDidLoad
{
	[super viewDidLoad];

	self.toolbarHidden = YES;
    
	UIColor *tintColor = [UIColor colorWithRed:0.2f green:0.2f blue:0.2f alpha:1.0f];
	self.navigationBar.tintColor = tintColor;
    
	_infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    /*
    _infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _infoButton.frame = CGRectMake(100.0f, 150.0f, 100.0f, 30.0f);
    [_infoButton setTitle:@"Settings" forState:UIControlStateNormal];
    [_infoButton setTitleColor:[UIColor colorWithRed:0.8f green:0.8f blue:0.8f alpha:1.0f] forState:UIControlStateNormal];
    */
    
	[_infoButton addTarget:self action:@selector(infoButtonWasTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    _mSettingViewController = [SettingViewController alloc];
    _mSettingViewController.title = @"Settings";    
}

/*
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	NSLog(@"%@ will rotate", NSStringFromClass([self class]));
	ci::app::AppCocoaTouch::get()->emitWillRotate();
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	ci::app::AppCocoaTouch::get()->emitDidRotate();
}
*/

// pre iOS 6
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	//return YES;
    return NO;
}

// iOS 6+
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
- (NSUInteger)supportedInterfaceOrientations
{
	//return UIInterfaceOrientationMaskAll;    
    return UIInterfaceOrientationMaskPortrait;
}
#endif

// -------------------------------------------------------------------------------------------------
#pragma mark - Private UI

- (void)addEmptyViewControllerToFront
{
    /*
	UIViewController *emptyViewController = [UIViewController new];
	emptyViewController.title = @"Empty VC";
	emptyViewController.view.backgroundColor = [UIColor clearColor];

	self.viewControllers = @[emptyViewController];
	emptyViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.infoButton];
	emptyViewController.toolbarItems = [self tabBarItems];
    */
}

- (void)infoButtonWasTapped:(id)sender
{
    [self gotoSetupPanel];
}

@end
