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
    
    void motionSensorUpdate(bool invert);
    void audioInUpdate(bool invert);
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
    int             orientation, drawMode, shakeCount, silenceCount, isInverted;
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
    mAudioInput.start();
    
    ledMode = false;
    loopMode = true;
    autorec = false;
    
    orientation = 0;
    drawMode = 1;
    
    shakeCount = silenceCount = 0;
    shakeDelta = 0.1f;
    audioThreshold = 0.5f;
    isInverted = 0;
    
    //MotionManager::setAccelerometerFilter(0.7f);
    MotionManager::enable(30.0f, MotionManager::Accelerometer);
    
    currentTestProcess = bind( &GonzoCamApp::motionSensorUpdate, this, std::__1::placeholders::_1 );
    currentDrawProcess = bind( &GonzoCamApp::captureDraw, this );
    
    setLoopMode(true);
}


void GonzoCamApp::motionSensorUpdate(bool invert)
{
    bool ping_m;
    
    if(MotionManager::isShaking(shakeDelta) == invert){
        if(invert){ //!- move
            //if(!mCapture->isCapturing()) ping = true;
            ping_m = true;
        }else{ //!- stop
            if(!mCapture->isCapturing()){
                shakeCount ++;
            }else{
                shakeCount = 0;
            }
            
            if(!mCapture->isCapturing() && shakeCount > 60){
                ping_m = true;
                shakeCount = 0;
            }
        }
        
        if(!ping_m) return;
        
        if(ledMode) mCapture->getDevice()->ledOn();
        
        if(autorec){
            mCapture->startRecording(orientation, 30, llist[pLength], bind( &GonzoCamApp::onAutoStop, this, true ));
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
        }else{
            mCapture->start(orientation);
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
        }
    }else{
        shakeCount = 0;
        
        if(!invert && mCapture->isCapturing()){
            mCapture->stop();
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
        }
    }
}

void GonzoCamApp::audioInUpdate(bool invert)
{
    bool ping_a;
    
    if(!mCapture->isCapturing()){
        if (mAudioInput.isCapturing()) {
            mPcmBuffer = mAudioInput.getPcmBuffer();
            if( mPcmBuffer ) {
                uint32_t bufferSamples = mPcmBuffer->getSampleCount();
                audio::Buffer32fRef leftBuffer = mPcmBuffer->getChannelData( audio::CHANNEL_FRONT_LEFT );
                
                int endIdx = bufferSamples;
                
                int32_t startIdx = ( endIdx - 1024 );
                startIdx = math<int32_t>::clamp( startIdx, 0, endIdx );
                
                if(invert){ //!- find peak
                    for( uint32_t i = startIdx, c = 0; i < endIdx; i++, c++ ) {
                        if(leftBuffer->mData[i] > audioThreshold){
                            ping_a = true;
                            break;
                        }
                    }
                }else{ //!- find silence
                    for( uint32_t i = startIdx, c = 0; i < endIdx; i++, c++ ) {
                        if(leftBuffer->mData[i] > audioThreshold){
                            silenceCount = 0;
                            return;
                        }
                    }
                    
                    silenceCount ++;
                    
                    if(silenceCount > 120){
                        silenceCount = 0;
                        ping_a = true;
                    }
                }
            }
        }
        
        if(!ping_a) return;
        
        if(ledMode) mCapture->getDevice()->ledOn();
        
        if(autorec){
            mCapture->startRecording(orientation, 30, llist[pLength], bind( &GonzoCamApp::onAutoStop, this, true ));
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
        }else{
            mCapture->start(orientation);
            mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
        }
    }
}

void GonzoCamApp::update()
{
    if(!loopMode) return;

    if (currentTestProcess) currentTestProcess(isInverted);
}


void GonzoCamApp::captureDraw()
{
    gl::clear();
    gl::disableAlphaBlending();
    gl::color(Color(1, 1, 1));
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
    NSLog(@"auto stop done");
}


/*
 * binded to etc
 */
void GonzoCamApp::setLoopMode(bool b)
{
    loopMode = b;
    
    ///*
    if(loopMode){
        setFrameRate(30.0f);
    }else{
        setFrameRate(1.0f); //!- umm.. setting 0.0f is fail to restart
    }
    NSLog(@"reset fps %f:", getFrameRate());
    //*/
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
    mPcmBuffer = NULL;
    shakeCount = 0;
    silenceCount = 0;
    
    mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];

    if(i == 0){
        currentTestProcess = bind( &GonzoCamApp::motionSensorUpdate, this, std::__1::placeholders::_1 );
    }else{
        currentTestProcess = bind( &GonzoCamApp::audioInUpdate, this, std::__1::placeholders::_1 );
    }
}

void GonzoCamApp::mActiveSegmentUpdate(int i)
{
    mCapture->stop();
    mPcmBuffer = NULL;
    shakeCount = 0;
    silenceCount = 0;

    mNativeController.navigationBar.tintColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    
    isInverted = i;
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
