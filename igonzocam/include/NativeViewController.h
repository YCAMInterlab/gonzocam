#pragma once

#import <UIKit/UIKit.h>

#include "cinder/Function.h"
#include "SettingViewController.h"

@interface NativeViewController : UINavigationController

- (void)addCinderViewToFront;
- (void)addCinderViewAsBarButton;
- (void)gotoSetupPanel;

@property (nonatomic) std::function<void()> infoButtonCallback;

@property (nonatomic) SettingViewController *mSettingViewController;

@end
