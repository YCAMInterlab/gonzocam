/*
 Copyright (c) 2010, The Barbarian Group
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that
 the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and
	the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
	the following disclaimer in the documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
*/

#import "IOSCaptureImplAvFoundation.h"
#include "cinder/cocoa/CinderCocoa.h"
#include "cinder/Vector.h"
#include "cinder/System.h"
#import <AVFoundation/AVFoundation.h>

namespace cinder {

IOSCaptureImplAvFoundationDevice::IOSCaptureImplAvFoundationDevice( AVCaptureDevice *device )
	: IOSCapture::Device()
{
	mUniqueId = cocoa::convertNsString( [device uniqueID] );
	mName = cocoa::convertNsString( [device localizedName] );
	mNativeDevice = [device retain];
	mFrontFacing = device.position == AVCaptureDevicePositionFront;
}

IOSCaptureImplAvFoundationDevice::~IOSCaptureImplAvFoundationDevice()
{
	[mNativeDevice release];
}

void IOSCaptureImplAvFoundationDevice::ledOn() const
{
    if ([mNativeDevice hasTorch] && [mNativeDevice hasFlash]){
        
        [mNativeDevice lockForConfiguration:nil];
        [mNativeDevice setTorchMode:AVCaptureTorchModeOn];
        [mNativeDevice setFlashMode:AVCaptureFlashModeOn];

        [mNativeDevice unlockForConfiguration];
    }
}

void IOSCaptureImplAvFoundationDevice::ledOff() const
{
    if ([mNativeDevice hasTorch] && [mNativeDevice hasFlash]){
        
        [mNativeDevice lockForConfiguration:nil];
        [mNativeDevice setTorchMode:AVCaptureTorchModeOff];
        [mNativeDevice setFlashMode:AVCaptureFlashModeOff];

        [mNativeDevice unlockForConfiguration];
    }
}


bool IOSCaptureImplAvFoundationDevice::checkAvailable() const
{
	return mNativeDevice.connected;
}

bool IOSCaptureImplAvFoundationDevice::isConnected() const
{
	return mNativeDevice.connected;
}

} //namespace


static void frameDeallocator( void *refcon )
{
	CVPixelBufferRef pixelBuffer = reinterpret_cast<CVPixelBufferRef>( refcon );
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	CVBufferRelease( pixelBuffer );
}

static std::vector<cinder::IOSCapture::DeviceRef> sDevices;
static BOOL sDevicesEnumerated = false;

@implementation IOSCaptureImplAvFoundation

+ (const std::vector<cinder::IOSCapture::DeviceRef>&)getDevices:(BOOL)forceRefresh
{
	if( sDevicesEnumerated && ( ! forceRefresh ) ) {
		return sDevices;
	}

	sDevices.clear();
	
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for( int i = 0; i < [devices count]; i++ ) {
		AVCaptureDevice *device = [devices objectAtIndex:i];
		sDevices.push_back( cinder::IOSCapture::DeviceRef( new cinder::IOSCaptureImplAvFoundationDevice( device ) ) );
	}
	sDevicesEnumerated = true;
	return sDevices;
}

- (id)initWithDevice:(const cinder::IOSCapture::DeviceRef)device width:(int)width height:(int)height
{
	if( ( self = [super init] ) ) {

		mDevice = device;
		if( ! mDevice ) {
			if( [IOSCaptureImplAvFoundation getDevices:NO].empty() )
				throw cinder::IOSCaptureExcInitFail();
			mDevice = [IOSCaptureImplAvFoundation getDevices:NO][0];
		}
		
		mDeviceUniqueId = [NSString stringWithUTF8String:mDevice->getUniqueId().c_str()];
		[mDeviceUniqueId retain];
		
		mIsCapturing = false;
		mWidth = width;
		mHeight = height;
		mHasNewFrame = false;
		mExposedFrameBytesPerRow = 0;
		mExposedFrameWidth = 0;
		mExposedFrameHeight = 0;
        
        self.mOrientation = 0;
        
        mWithRecording = false;
        recFps = 30;
        recFrames = 0;
        recMaxLength = -1;
	}
	return self;
}


- (void)dealloc
{
	if( mIsCapturing ) {
		[self stopCapture];
	}
	
	[mDeviceUniqueId release];
	
	[super dealloc];
}

- (bool)prepareStartCapture 
{
    NSError *error = nil;

    mSession = [[AVCaptureSession alloc] init];

	if( cinder::Vec2i( mWidth, mHeight ) == cinder::Vec2i( 640, 480 ) )
		mSession.sessionPreset = AVCaptureSessionPreset640x480;
	else if( cinder::Vec2i( mWidth, mHeight ) == cinder::Vec2i( 1280, 720 ) )
		mSession.sessionPreset = AVCaptureSessionPreset1280x720;
	else
		mSession.sessionPreset = AVCaptureSessionPresetMedium;

    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = nil;
	if( ! mDeviceUniqueId ) {
		device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	}
	else {
		device = [AVCaptureDevice deviceWithUniqueID:mDeviceUniqueId];
	}
	
	if( ! device ) {
		throw cinder::IOSCaptureExcInitFail();
	}
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if( ! input ) {
        throw cinder::IOSCaptureExcInitFail();
    }
    [mSession addInput:input];

    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];

    [mSession addOutput:output];
	    
	//adjust connection settings
	///*
	//Testing indicates that at least the 3GS doesn't support video orientation changes
	NSArray * connections = output.connections;
	for( int i = 0; i < [connections count]; i++ ) {
		AVCaptureConnection * connection = [connections objectAtIndex:i];
		if( connection.supportsVideoOrientation ) {
            switch (self.mOrientation) {
                case 0:
                    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                    break;
                case 1:
                    connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                    break;
                case 2:
                    connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                    break;
                case 3:
                    connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                default:
                    break;
            }
            
            if( cinder::System::getOsMajorVersion() >= 7 ){
                //! iOS7 warning fix
                [device lockForConfiguration:nil];
                device.activeVideoMinFrameDuration = CMTimeMake(1, recFps);
                [device unlockForConfiguration];
            }else{
                connection.videoMinFrameDuration = CMTimeMake(1, recFps);
            }
            
            NSLog(@"Set orientation %d", self.mOrientation);
		}
	}
    //*/

    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);

    // Specify the pixel format
    output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];

    // If you wish to cap the frame rate to a known value, such as 15 fps, set minFrameDuration.
    // output.minFrameDuration = CMTimeMake(1, recFps);
        
	return true;
}

- (void)startCapture 
{
	if( mIsCapturing )
		return; 

	@synchronized( self ) {
		if( [self prepareStartCapture] ) {
			mWorkingPixelBuffer = 0;
			mHasNewFrame = false;
		
			mIsCapturing = true;
			[mSession startRunning];
                        
            mWithRecording = false;
            autoStopCallback = NULL;
		}
	}
}

- (void)startCaptureWithRecording:(int)fps limit:(int)limit autoStopCallback:(std::function<void(bool b)>)func
{
	if( mIsCapturing )
		return;
    
	@synchronized( self ) {
		if( [self prepareStartCapture] ) {
			mWorkingPixelBuffer = 0;
			mHasNewFrame = false;
            
			mIsCapturing = true;
            mWithRecording = true;
            recFps = fps;
            recFrames = 0;
            recMaxLength = limit;
            
			[mSession startRunning];
            
            [self initVideoWriterSession];
            
            if(func) autoStopCallback = func;
            
            NSLog(@"Start with recording fps:%d, max length:%d frames", recFps, recMaxLength * recFps);
		}
	}
}

- (void)stopCapture
{
	if( ! mIsCapturing )
		return;

	@synchronized( self ) {
        
        if(mWithRecording){
            [self closeVideoWriterSession];
            [self saveMovieToLibrary];
            
            mWithRecording = false;
        }
        
		[mSession stopRunning];
		[mSession release];
		mSession = nil;

		mIsCapturing = false;
		mHasNewFrame = false;
		
		mCurrentFrame.reset();
		
		if( mWorkingPixelBuffer ) {
			CVBufferRelease( mWorkingPixelBuffer );
			mWorkingPixelBuffer = 0;
		}        
	}
}

- (bool)isCapturing
{
	return mIsCapturing;
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{ 
    @synchronized( self ) {
		if( mIsCapturing ) {
			// if the last pixel buffer went unclaimed, we'll need to release it
			if( mWorkingPixelBuffer ) {
				CVBufferRelease( mWorkingPixelBuffer );
				mWorkingPixelBuffer = NULL;
			}
			
			CVImageBufferRef videoFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
			// Lock the base address of the pixel buffer
			//CVPixelBufferLockBaseAddress( videoFrame, 0 );
                
			CVBufferRetain( videoFrame );
		
			mWorkingPixelBuffer = (CVPixelBufferRef)videoFrame;
			mHasNewFrame = true;
                                    
            if(mWithRecording){
                [self writeImageinVideo:recFrames fps:recFps];
                recFrames ++;
                
                if(recMaxLength > 0 && recFrames > (recMaxLength * recFps)) [self stopCapture];
            }
		}
	}
}

- (void)initVideoWriterSession
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/movie.mov"]];
    
    // removing temp file from home dir
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:NULL];
    
    NSError *error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                            fileType:AVFileTypeQuickTimeMovie /*AVFileTypeMPEG4*/
                                               error:&error];
    NSParameterAssert(videoWriter);

    NSDictionary *videoSettings = nil;
    if(self.mOrientation == 0 || self.mOrientation == 1){
        videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecH264/*AVVideoCodecJPEG*/
                                       , AVVideoCodecKey,
                                       [NSNumber numberWithInt:mHeight], AVVideoWidthKey,
                                       [NSNumber numberWithInt:mWidth], AVVideoHeightKey,
                                       nil];
    }else{
        videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecH264/*AVVideoCodecJPEG*/
                                       , AVVideoCodecKey,
                                       [NSNumber numberWithInt:mWidth], AVVideoWidthKey,
                                       [NSNumber numberWithInt:mHeight], AVVideoHeightKey,
                                       nil];
    }
    
    writerInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings] retain];
    
    writerInput.expectsMediaDataInRealTime = YES;
    
    NSDictionary *sourcePixelBufferAttributesDictionary = nil;
    if([self mOrientation] == 0 || [self mOrientation] == 1){
        sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                 [NSNumber numberWithInt:mHeight], kCVPixelBufferWidthKey,
                                                 [NSNumber numberWithInt:mWidth], kCVPixelBufferHeightKey,
                                                 nil];
    }else{
        sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                                 [NSNumber numberWithInt:mWidth], kCVPixelBufferWidthKey,
                                                 [NSNumber numberWithInt:mHeight], kCVPixelBufferHeightKey,
                                                 nil];
    }
    
    adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    [adaptor retain];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    [videoWriter addInput:writerInput];
    [videoWriter retain];
    
    // Mirror the video to comply with OpenGL's upside-down rendering
    // writerInput.transform = CGAffineTransformMakeScale(1, -1);
    // writerInput.transform = CGAffineTransformMakeRotation(M_PI/2);
    
    // Start a session
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    // write first image
    //[self writeImageinVideo:0 fps:1];
}

- (void)closeVideoWriterSession
{
    if (writerInput.readyForMoreMediaData) {
        // Finish the session
        [writerInput markAsFinished];
        [videoWriter finishWriting];
        CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
        [videoWriter release];
        [writerInput release];
        NSLog (@"Done writing movie");
    }
}

-(void)writeImageinVideo:(int)fid fps:(int)fps
{
    if (writerInput.readyForMoreMediaData) {
        
        CMTime currentTime = CMTimeMake(fid, fps);

        [adaptor appendPixelBuffer:mWorkingPixelBuffer withPresentationTime:currentTime];
    }
}

- (void)saveMovieToLibrary
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Documents/movie.mov"]];
    
    // moving file to photo lib
    [self downloadVideo:path];
}

-(void)downloadVideo:(NSString *)sampleMoviePath
{
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(sampleMoviePath))
        UISaveVideoAtPathToSavedPhotosAlbum(sampleMoviePath, self, @selector(video:didFinishSavingWithError: contextInfo:), sampleMoviePath);
}

-(void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSLog(@"Finished with error: %@", error);
    
    if (autoStopCallback) {
        autoStopCallback(true);
    }
}


- (cinder::Surface8u)getCurrentFrame
{
	if( ( ! mIsCapturing ) || ( ! mWorkingPixelBuffer ) ) {
		return mCurrentFrame;
	}
	
	@synchronized (self) {        
		CVPixelBufferLockBaseAddress( mWorkingPixelBuffer, 0 );
		
		uint8_t *data = (uint8_t *)CVPixelBufferGetBaseAddress( mWorkingPixelBuffer );
		mExposedFrameBytesPerRow = CVPixelBufferGetBytesPerRow( mWorkingPixelBuffer );
		mExposedFrameWidth = CVPixelBufferGetWidth( mWorkingPixelBuffer );
		mExposedFrameHeight = CVPixelBufferGetHeight( mWorkingPixelBuffer );

		mCurrentFrame = cinder::Surface8u( data, mExposedFrameWidth, mExposedFrameHeight, mExposedFrameBytesPerRow, cinder::SurfaceChannelOrder::BGRA );
		mCurrentFrame.setDeallocator( frameDeallocator, mWorkingPixelBuffer );
		
		// mark the working pixel buffer as empty since we have wrapped it in the current frame
		mWorkingPixelBuffer = 0;
	}
	
	return mCurrentFrame;
}

- (bool)checkNewFrame
{
	bool result;
	@synchronized (self) {
		result = mHasNewFrame;
		mHasNewFrame = FALSE;
	}
	return result;
}

- (const cinder::IOSCapture::DeviceRef)getDevice {
	return mDevice;
}

- (int32_t)getWidth
{
	return mWidth;
}

- (int32_t)getHeight
{
	return mHeight;
}

- (int32_t)getCurrentFrameBytesPerRow
{
	return mExposedFrameBytesPerRow;
}

- (int32_t)getCurrentFrameWidth
{
	return mExposedFrameWidth;
}

- (int32_t)getCurrentFrameHeight
{
	return mExposedFrameHeight;
}

@end
