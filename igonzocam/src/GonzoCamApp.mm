//
//  GonzoCamApp.mm
//  GonzoCamApp
//
//  Created by Takanobu Inafuku on 2013/08/16.
//
//  Note: this code is compiled with ARC enabled

#include "cinder/app/AppNative.h"
#include "cinder/app/CinderViewCocoaTouch.h"
#include "cinder/gl/gl.h"
#include "cinder/Camera.h"
#include "cinder/gl/Texture.h"
#include "cinder/Font.h"

#include "cinder/audio/Input.h"

#include "IOSCapture.h"

#include "MotionManager.h"

#include "NativeViewController.h"
#include "SettingViewController.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class GonzoCamApp : public AppNative {
public:
	void prepareSettings( Settings *settings );
	void setup();
	void update();
	void draw();
    
    void onAutoStop(bool b);
    
    IOSCaptureRef mCapture;
    gl::TextureRef mTexture;
    
    audio::Input mAudioInput;
    audio::PcmBuffer32fRef mPcmBuffer;
    
    std::function<void(bool b)> currentTestProcess;
    std::function<void(bool b)> currentDrawProcess;
    
    void motionUpdate();
    void activeMotionUpdate();
    void audioInUpdate();
    //void silenceAudioInUpdate();
    void captureDraw();
    void sensorDraw();
    
private:
    void drowModeSegmentUpdate(int i);
    void orientationSegmentUpdate(int i);
    void mSensorSegmentUpdate(int i);
    void mActiveSegmentUpdate(int i);
    void mThreshSliderUpdate(float f);
    void ledSwitchUpdate(bool b);
    void recSwitchUpdate(bool b);
    void setLoopMode(bool b);
    
	gl::Texture 	mTex;
	Font			mFont;
    
    bool            ledMode, loopMode, autorec;
    int             orientation, drawMode, shakeCount, isInverted, calibCount;
    int             pLength, pQuality;
    float           shakeDelta, audioThreshold;
    //
    const int    llist[3] = {3, 5, 10};
    const Vec2i  qlist[2] = {Vec2i(1280, 720), Vec2f(640, 480)};
    
	NativeViewController *mNativeController;
    SettingViewController *mSettingViewController;
};


void GonzoCamApp::prepareSettings( Settings *settings )
{
	mNativeController = [NativeViewController new];
    
	settings->prepareWindow( Window::Format().rootViewController( mNativeController ) );
    
    //
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    pLength = (int) [defaults integerForKey:@"length_preference"];
    pQuality = (int) [defaults integerForKey:@"quality_preference"];
    NSLog(@"read from bundle, length > %d seconds / quality > %d×%d", llist[pLength], qlist[pQuality].x, qlist[pQuality].y);
    //
}


void GonzoCamApp::setup()
{
    NSLog(@"cinder loop initialize..");
    
	[mNativeController addCinderViewToFront];
    
    //! UI callbacks from SettingViewController
    [mNativeController.mSettingViewController setModeSegmentCallback: bind( &GonzoCamApp::drowModeSegmentUpdate, this, std::__1::placeholders::_1 ) ];
    [mNativeController.mSettingViewController setOrientationSegmentCallback: bind( &GonzoCamApp::orientationSegmentUpdate, this, std::__1::placeholders::_1 ) ];
    [mNativeController.mSettingViewController setLedSwitchCallback: bind( &GonzoCamApp::ledSwitchUpdate, this, std::__1::placeholders::_1 ) ];
    [mNativeController.mSettingViewController setRecSwitchCallback: bind( &GonzoCamApp::recSwitchUpdate, this, std::__1::placeholders::_1 ) ];
    //! sensor setting
    [mNativeController.mSettingViewController setMSensorSegmentCallback: bind( &GonzoCamApp::mSensorSegmentUpdate, this, std::__1::placeholders::_1 ) ];
    [mNativeController.mSettingViewController setMActiveSegmentCallback: bind( &GonzoCamApp::mActiveSegmentUpdate, this, std::__1::placeholders::_1 ) ];
    [mNativeController.mSettingViewController setMThreshSliderCallback: bind( &GonzoCamApp::mThreshSliderUpdate, this, std::__1::placeholders::_1 ) ];
    
    //! UI callbacks from SettingViewController
    [mNativeController.mSettingViewController setOnSettingViewActiveCallback: bind( &GonzoCamApp::setLoopMode, this, false ) ];
    [mNativeController.mSettingViewController setOnSettingViewDeactiveCallback: bind( &GonzoCamApp::setLoopMode, this, true ) ];
    
    
    // camera setup
    /*
     for( auto device = IOSCapture::getDevices().begin(); device != IOSCapture::getDevices().end(); ++device ) {
     console() << "Device: " << (*device)->getName() << " "
     << ( (*device)->isFrontFacing() ? "Front" : "Rear" ) << "-facing"
     << endl;
     }
     */
    try {
        //mCapture = IOSCapture::create( 1280, 720 ); //..?
        mCapture = IOSCapture::create( qlist[pQuality].x, qlist[pQuality].y ); //..?
	}
	catch( ... ) {
		NSLog(@"Failed to initialize capture");
	}
    //
    
    mAudioInput = audio::Input();
    
    ledMode = false;
    loopMode = true;
    autorec = false;
    
    orientation = 0;
    drawMode = 1;
    
    shakeCount = calibCount = 0;
    shakeDelta = 0.1f;
    audioThreshold = 0.5f;
    
    setFrameRate(30.0f);
    //setFrameRate(24.0f);
    
    //MotionManager::setAccelerometerFilter(0.7f);
    //MotionManager::enable(24.0f, MotionManager::Accelerometer);
    MotionManager::enable(30.0f, MotionManager::Accelerometer);
    
    currentTestProcess = bind( &GonzoCamApp::motionUpdate, this );
    currentDrawProcess = bind( &GonzoCamApp::captureDraw, this );
    
    setLoopMode(true);
    
    //[mNativeController gotoSetupPanel];
}


void GonzoCamApp::motionUpdate()
{
    if(!MotionManager::isShaking(shakeDelta)){
        if(!mCapture->isCapturing()){
            shakeCount ++;
        }else{
            shakeCount = 0;
        }
        
        if(!mCapture->isCapturing() && shakeCount > 60){
            if(ledMode) mCapture->getDevice()->ledOn();
            
            shakeCount = 0;
            
            if(autorec){
                mCapture->startRecording(orientation, 30, llist[pLength], bind( &GonzoCamApp::onAutoStop, this, true ));
                mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            }else{
                mCapture->start(orientation);
                mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
            }
        }
    }else{
        shakeCount = 0;
        
        if(mCapture->isCapturing()){
            mCapture->stop();
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
        }
    }
}


void GonzoCamApp::activeMotionUpdate()
{
    if(MotionManager::isShaking(shakeDelta)){
        if(!mCapture->isCapturing()){
            if(ledMode) mCapture->getDevice()->ledOn();
            
            if(autorec){
                mCapture->startRecording(orientation, 30, llist[pLength], bind( &GonzoCamApp::onAutoStop, this, true ));
                mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            }else{
                mCapture->start(orientation);
                mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
            }
        }
    }else{
        shakeCount = 0;
    }
}


void GonzoCamApp::audioInUpdate()
{
    if(!mCapture->isCapturing()){
        if (!mAudioInput.isCapturing()) {
            mAudioInput.start();
        }else{
            mPcmBuffer = mAudioInput.getPcmBuffer();
            if( mPcmBuffer ) {
                uint32_t bufferSamples = mPcmBuffer->getSampleCount();
                audio::Buffer32fRef leftBuffer = mPcmBuffer->getChannelData( audio::CHANNEL_FRONT_LEFT );
                
                int endIdx = bufferSamples;
                
                int32_t startIdx = ( endIdx - 1024 );
                startIdx = math<int32_t>::clamp( startIdx, 0, endIdx );
                
                for( uint32_t i = startIdx, c = 0; i < endIdx; i++, c++ ) {
                    if(leftBuffer->mData[i] > audioThreshold){
                        //console() << "find peak " << leftBuffer->mData[i] << endl;
                        
                        if(ledMode) mCapture->getDevice()->ledOn();
                        
                        if(autorec){
                            mCapture->startRecording(orientation, 30, llist[pLength], bind( &GonzoCamApp::onAutoStop, this, true ));
                            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
                        }else{
                            mCapture->start(orientation);
                            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
                        }
                        
                        break;
                    }
                }
            }
        }
    }else{
        if (mAudioInput.isCapturing()) {
            mAudioInput.stop();
            mPcmBuffer = NULL;
        }
    }
}

/*
void GonzoCamApp::silenceAudioInUpdate()
{

}
*/

void GonzoCamApp::update()
{
    if(!loopMode) return;

    if (currentTestProcess) currentTestProcess(true);
}


void GonzoCamApp::captureDraw()
{
    gl::clear();
    gl::disableAlphaBlending();
    gl::color(Color(1, 1, 1));
    
    //glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );

    gl::setMatricesWindow( getWindowWidth(), getWindowHeight() );
    
    if( mCapture && mCapture->checkNewFrame()) mTexture = gl::Texture::create( mCapture->getSurface() );
    
    if( mTexture ) {
        glPushMatrix();
        
        //change iphone to landscape orientation
        if (orientation == 2 || orientation == 3 ) gl::rotate( 90.0f );
        gl::translate( 0.0f, -getWindowWidth());
        
        //Rectf flippedBounds( 0.0f, 0.0f, [self getWindowHeight], [self getWindowWidth] );
        //gl::draw( mTexture, flippedBounds );
        
        gl::draw( mTexture );
        glPopMatrix();
    }
}

void GonzoCamApp::sensorDraw()
{
    gl::clear( Color( 0.0f, 0.0f, 0.0f ) );
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    gl::setMatricesWindow( getWindowWidth(), getWindowHeight() );
    
    if( mPcmBuffer ) {
        uint32_t bufferSamples = mPcmBuffer->getSampleCount();
        audio::Buffer32fRef leftBuffer = mPcmBuffer->getChannelData( audio::CHANNEL_FRONT_LEFT );
        
        int displaySize = getWindowWidth();
        int endIdx = bufferSamples;
        
        //only draw the last 1024 samples or less
        int32_t startIdx = ( endIdx - 1024 );
        startIdx = math<int32_t>::clamp( startIdx, 0, endIdx );
        
        float scale = displaySize / (float)( endIdx - startIdx );
        
        PolyLine<Vec2f>	line;
        for( uint32_t i = startIdx, c = 0; i < endIdx; i++, c++ ) {
            
            float y = ( ( leftBuffer->mData[i] - 1 ) * - 100 );
            line.push_back( Vec2f( ( c * scale ), y ) );
        }
        glPushMatrix();
        gl::translate( 0.0f, getWindowWidth() / 2);
        gl::draw( line );
        glPopMatrix();
    }
}


void GonzoCamApp::draw()
{
    if(!loopMode || drawMode == 0) return;
    
    if (currentDrawProcess) currentDrawProcess(true);
}


void GonzoCamApp::onAutoStop(bool b)
{
    mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    shakeCount = 0;
    NSLog(@"autostop done");
}


/*
 * binded to etc
 */
void GonzoCamApp::setLoopMode(bool b)
{
    loopMode = b;
    
    /*
    if(loopMode){
        //setFrameRate(30.0f);
        setFrameRate(24.0f);
        console() << "fps: " << getFrameRate() << endl;
    }else{
        setFrameRate(0.0f);
    }
    */
}

void GonzoCamApp::drowModeSegmentUpdate(int i)
{
    drawMode = i;
    
    if(drawMode == 2){
        currentDrawProcess = bind( &GonzoCamApp::sensorDraw, this );
    }else{
        currentDrawProcess = bind( &GonzoCamApp::captureDraw, this );
    }
}

void GonzoCamApp::orientationSegmentUpdate(int i)
{
    mCapture->stop();
    mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    orientation = i;
}

void GonzoCamApp::recSwitchUpdate(bool b)
{
    autorec = b;
}

void GonzoCamApp::ledSwitchUpdate(bool b)
{
    ledMode = b;
    if(ledMode){
        mCapture->getDevice()->ledOn();
    }else{
        mCapture->getDevice()->ledOff();
    }
}

void GonzoCamApp::mSensorSegmentUpdate(int i)
{
    mCapture->stop();
    mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    
    if(isInverted == 0){
        if (i == 0) {
            currentTestProcess = bind( &GonzoCamApp::motionUpdate, this );
        }else{
            currentTestProcess = bind( &GonzoCamApp::audioInUpdate, this );
        }
    }else{
        if (i == 0) {
            currentTestProcess = bind( &GonzoCamApp::activeMotionUpdate, this );
        }else{
            currentTestProcess = bind( &GonzoCamApp::audioInUpdate, this );
        }
    }
}

void GonzoCamApp::mActiveSegmentUpdate(int i)
{
    isInverted = i;
    
    if(isInverted == 0){
        if (i == 0) {
            currentTestProcess = bind( &GonzoCamApp::motionUpdate, this );
        }else{
            currentTestProcess = bind( &GonzoCamApp::audioInUpdate, this );
        }
    }else{
        if (i == 0) {
            currentTestProcess = bind( &GonzoCamApp::activeMotionUpdate, this );
        }else{
            currentTestProcess = bind( &GonzoCamApp::audioInUpdate, this );
        }
    }
}

void GonzoCamApp::mThreshSliderUpdate(float f)
{
    if(mSettingViewController.sensorSegment.selectedSegmentIndex == 0){
        shakeDelta = f;
    }else{
        audioThreshold = f;
    }
}


CINDER_APP_NATIVE( GonzoCamApp, RendererGl )
