//
//  SettingViewController.h
//  GonzoCamApp
//
//  Created by Takanobu Inafuku on 2013/08/16.
//
//
#pragma once

#import <UIKit/UIKit.h>

//#include "cinder/Function.h"

@interface SettingViewController : UIViewController{    
    int motionCurrentActive;
    int micCurrentActive;    
    float motionCurrentThreshold;
    float micCurrentThreshold;
}

@property (nonatomic) std::function<void(int i)> modeSegmentCallback;
@property (nonatomic) std::function<void(int i)> orientationSegmentCallback;
@property (nonatomic) std::function<void(bool b)> ledSwitchCallback;
@property (nonatomic) std::function<void(bool b)> recSwitchCallback;

@property (nonatomic) std::function<void(int i)> mSensorSegmentCallback;
@property (nonatomic) std::function<void(int i)> mActiveSegmentCallback;
@property (nonatomic) std::function<void(float f)> mThreshSliderCallback;

@property (nonatomic) std::function<void(bool b)> onSettingViewActiveCallback;
@property (nonatomic) std::function<void(bool b)> onSettingViewDeactiveCallback;

@property (weak, nonatomic) IBOutlet UISegmentedControl *sensorSegment;
@property (weak, nonatomic) IBOutlet UISlider *abstractSlider;
@property (weak, nonatomic) IBOutlet UISegmentedControl *abstractSegment;

@property (weak, nonatomic) IBOutlet UIScrollView *scView;


- (IBAction)listenModeSegment:(id)sender;
- (IBAction)listenOrientationSegment:(id)sender;

- (IBAction)listenLEDSwitch:(id)sender;
- (IBAction)autoRecSwitch:(id)sender;

- (IBAction)listenMSensorSegment:(id)sender;
- (IBAction)listenMActiveSegment:(id)sender;
- (IBAction)listenMThreshSlider:(id)sender;

@end