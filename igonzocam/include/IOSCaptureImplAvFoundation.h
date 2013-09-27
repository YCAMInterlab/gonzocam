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

#include "cinder/Cinder.h"
#include "cinder/Surface.h"
#include "IOSCapture.h"
#import <AVFoundation/AVFoundation.h>
#include <vector>

namespace cinder {

class IOSCaptureImplAvFoundationDevice : public IOSCapture::Device {
  public:
	IOSCaptureImplAvFoundationDevice( AVCaptureDevice *device );
	~IOSCaptureImplAvFoundationDevice();
	
	bool						checkAvailable() const;
	bool						isConnected() const;
    void						ledOn() const;
    void						ledOff() const;
	IOSCapture::DeviceIdentifier	getUniqueId() const { return mUniqueId; }
	bool						isFrontFacing() const { return mFrontFacing; }
	void*						getNative() const { return mNativeDevice; }
  private:
	IOSCapture::DeviceIdentifier	mUniqueId;
	AVCaptureDevice				*mNativeDevice;
	bool						mFrontFacing;
};

} //namespace

@interface IOSCaptureImplAvFoundation : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
	AVCaptureSession				*mSession;
	CVPixelBufferRef				mWorkingPixelBuffer;
	cinder::Surface8u				mCurrentFrame;
	NSString						*mDeviceUniqueId;
    
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* writerInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
	
	cinder::IOSCapture::DeviceRef		mDevice;
	bool							mHasNewFrame;
	bool							mIsCapturing;
    bool                            mWithRecording;
	int32_t							mWidth, mHeight;
	int32_t							mSurfaceChannelOrderCode;
	int32_t							mExposedFrameBytesPerRow;
	int32_t							mExposedFrameHeight;
	int32_t							mExposedFrameWidth;

    //int8_t                          mOrientation;
    
    int                             recFrames;
    int                             recMaxLength;
    int                             recFps;
    std::function<void()>           autoStopCallback;
}

@property (nonatomic) int8_t mOrientation;

+ (const std::vector<cinder::IOSCapture::DeviceRef>&)getDevices:(BOOL)forceRefresh;

- (id)initWithDevice:(const cinder::IOSCapture::DeviceRef)device width:(int)width height:(int)height;
- (bool)prepareStartCapture;
- (void)startCapture;
- (void)startCaptureWithRecording:(int)fps limit:(int)limit autoStopCallback:(std::function<void()>)func;
- (void)stopCapture;
- (bool)isCapturing;

- (void)initVideoWriterSession;
- (void)closeVideoWriterSession;
- (void)writeImageinVideo:(int)fid fps:(int)fps;
- (void)saveMovieToLibrary;
- (void)downloadVideo:(NSString *)sampleMoviePath;
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

- (cinder::Surface8u)getCurrentFrame;
- (bool)checkNewFrame;
- (const cinder::IOSCapture::DeviceRef)getDevice;
- (int32_t)getWidth;
- (int32_t)getHeight;
- (int32_t)getCurrentFrameBytesPerRow;
- (int32_t)getCurrentFrameWidth;
- (int32_t)getCurrentFrameHeight;

@end
