//
//  SettingViewController.m
//  GonzoCamApp
//
//  Created by Takanobu Inafuku on 2013/08/16.
//
//
#import "SettingViewController.h"

//#include "cinder/app/AppCocoaTouch.h"

@interface SettingViewController ()

@end

@implementation SettingViewController

@synthesize modeSegmentCallback = _modeSegmentCallback;
@synthesize orientationSegmentCallback = _orientationSegmentCallback;
@synthesize ledSwitchCallback = _ledSwitchCallback;
@synthesize recSwitchCallback = _recSwitchCallback;

@synthesize mSensorSegmentCallback = _mSensorSegmentCallback;
@synthesize mActiveSegmentCallback = _mActiveSegmentCallback;
@synthesize mThreshSliderCallback = _mThreshSliderCallback;

@synthesize onSettingViewActiveCallback = _onSettingViewActiveCallback;
@synthesize onSettingViewDeactiveCallback = _onSettingViewDeactiveCallback;

@synthesize sensorSegment = _sensorSegment;
@synthesize abstractSlider = _abstractSlider;
@synthesize abstractSegment = _abstractSegment;

@synthesize scView = _scView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    motionCurrentActive = 0;
    micCurrentActive = 1;
    
    motionCurrentThreshold = 0.1f;
    micCurrentThreshold = 0.5f;
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
    
    if( _onSettingViewActiveCallback ) _onSettingViewActiveCallback(true);
}

- (void)viewWillDisappear:(BOOL)animated {
    [self resignFirstResponder];
    [super viewWillDisappear:animated];

    if( _onSettingViewDeactiveCallback ) _onSettingViewDeactiveCallback(true);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _scView.contentOffset = CGPointZero;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction) listenModeSegment:(id)sender
{
    UISegmentedControl *sgm = (UISegmentedControl *)sender;
    
    if( _modeSegmentCallback ) _modeSegmentCallback([sgm selectedSegmentIndex]);
}


- (IBAction) listenOrientationSegment:(id)sender
{
    UISegmentedControl *sgm = (UISegmentedControl *)sender;
    
    if( _orientationSegmentCallback ) _orientationSegmentCallback([sgm selectedSegmentIndex]);
}

- (IBAction) autoRecSwitch:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    
    if( _recSwitchCallback ) _recSwitchCallback(sw.on);
}

- (IBAction) listenLEDSwitch:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    
    if( _ledSwitchCallback ) _ledSwitchCallback(sw.on);
}

- (IBAction) listenMSensorSegment:(id)sender
{
    UISegmentedControl *sgm = (UISegmentedControl *)sender;
    
    if([sgm selectedSegmentIndex] == 0){
        _abstractSlider.value = motionCurrentThreshold;
        _abstractSegment.selectedSegmentIndex = motionCurrentActive;
    }else{
        _abstractSlider.value = micCurrentThreshold;
        _abstractSegment.selectedSegmentIndex = micCurrentActive;
    }
    
    if( _mSensorSegmentCallback ) _mSensorSegmentCallback([sgm selectedSegmentIndex]);
    if( _mActiveSegmentCallback ) _mActiveSegmentCallback([_abstractSegment selectedSegmentIndex]);
    if( _mThreshSliderCallback ) _mThreshSliderCallback([_abstractSlider value]);
}

- (IBAction) listenMActiveSegment:(id)sender
{
    UISegmentedControl *sgm = (UISegmentedControl *)sender;
    
    if (_sensorSegment.selectedSegmentIndex == 0) {
        motionCurrentActive = [sgm selectedSegmentIndex];
    }else{
        micCurrentActive = [sgm selectedSegmentIndex];
    }
    
    if( _mActiveSegmentCallback ) _mActiveSegmentCallback([sgm selectedSegmentIndex]);
}

- (IBAction) listenMThreshSlider:(id)sender
{
    UISlider *slider = (UISlider *)sender;
    
    if (_sensorSegment.selectedSegmentIndex == 0) {
        motionCurrentThreshold = [slider value];
    }else{
        micCurrentThreshold = [slider value];
    }
    
    if( _mThreshSliderCallback ) _mThreshSliderCallback([slider value]);
}

@end
