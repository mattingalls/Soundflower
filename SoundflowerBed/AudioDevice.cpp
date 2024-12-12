/*	Copyright: 	© Copyright 2004 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under AppleÕs
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*=============================================================================
	AudioDevice.cpp
	
=============================================================================*/

#include "AudioDevice.h"

/* verify_noerr was deprecated and removed in OS X High Sierra */
#ifndef verify_noerr
#define verify_noerr __Verify_noErr
#endif

void	AudioDevice::Init(AudioDeviceID devid, bool isInput)
{
	mID = devid;
	mIsInput = isInput;
	if (mID == kAudioDeviceUnknown) return;
	
	UInt32 propsize;
	
	propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertySafetyOffset, &propsize, &mSafetyOffset));
	
	propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyBufferFrameSize, &propsize, &mBufferSizeFrames));
	
	UpdateFormat();
}

void	AudioDevice::UpdateFormat()
{
	UInt32 propsize = sizeof(AudioStreamBasicDescription);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyStreamFormat, &propsize, &mFormat));
}

void	AudioDevice::SetBufferSize(UInt32 size)
{
	UInt32 propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceSetProperty(mID, NULL, 0, mIsInput, kAudioDevicePropertyBufferFrameSize, propsize, &size));

	propsize = sizeof(UInt32);
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyBufferFrameSize, &propsize, &mBufferSizeFrames));
}

OSStatus	AudioDevice::SetSampleRate(Float64 sr)
{
	UInt32 propsize = sizeof(AudioStreamBasicDescription);
	mFormat.mSampleRate = sr;
	OSStatus err = AudioDeviceSetProperty(mID, NULL, 0, mIsInput, kAudioDevicePropertyStreamFormat, propsize, &mFormat);

	// now re-read to see what actual value is
	//printf("pre update = %f\n", mFormat.mSampleRate);
    if (noErr != err){
        UpdateFormat();
    }
    //printf("post update = %f\n", mFormat.mSampleRate);
	
	return err;
}

bool    AudioDevice::IsVolumeAvailableForMaster()
{
    //Assume all device which support getting Volume also support setting Volume.
    Boolean isWritable = false;
    verify_noerr(AudioDeviceGetPropertyInfo(mID,0,false,kAudioDevicePropertyVolumeScalar,NULL,&isWritable));
    return isWritable;
}

bool    AudioDevice::IsVolumeAvailableForChannels()
{
    Boolean isWritable = false;
    verify_noerr(AudioDeviceGetPropertyInfo(mID,1,false,kAudioDevicePropertyVolumeScalar,NULL,&isWritable));
    return isWritable;
}


void    AudioDevice::SetVolumeScalar(float val)
{
    UInt32 propSize = sizeof(Float32);
    Float32 volumeScalar = val;
    
    /*
     Some devices support volume control only via master channel.
     Some devices support volume control only via each channel.
     Some devices support both of master or channels.
    */
    
    if(IsVolumeAvailableForMaster())
    {
        verify_noerr(AudioDeviceSetProperty(mID, NULL, 0/*master channel*/, false, kAudioDevicePropertyVolumeScalar, propSize, &volumeScalar));
    }else if(IsVolumeAvailableForChannels())
    {
        int channel_num = this->CountChannels();
        for (int i = 0 ; i < channel_num; i++){
            verify_noerr(AudioDeviceSetProperty(mID, NULL, 1 + i, false, kAudioDevicePropertyVolumeScalar, propSize, &volumeScalar));
        }
    }else{
        //No Support for kAudioDevicePropertyVolumeScalar
    }
}

float   AudioDevice::GetVolumeScalar()
{
    UInt32 propSize = sizeof(Float32);
    Float32 volumeScalar = 0;
    
    if(IsVolumeAvailableForMaster())
    {
        verify_noerr(AudioDeviceGetProperty(mID, 0/*master channel*/, false, kAudioDevicePropertyVolumeScalar, &propSize, &volumeScalar));
    }else if(IsVolumeAvailableForChannels())
    {
        //we take value from channel 1
        verify_noerr(AudioDeviceGetProperty(mID, 1, false, kAudioDevicePropertyVolumeScalar, &propSize, &volumeScalar));
        
    }else{
        //No Support for kAudioDevicePropertyVolumeScalar
    }
    return volumeScalar;
}

float   AudioDevice::GetVolumeDB()
{
    UInt32 propSize = sizeof(Float32);
    Float32 volumeDB = 0;
    
    if(IsVolumeAvailableForMaster())
    {
        verify_noerr(AudioDeviceGetProperty(mID, 0/*master channel*/, false, kAudioDevicePropertyVolumeDecibels, &propSize, &volumeDB));
    }else if(IsVolumeAvailableForChannels())
    {
        //we take value from channel 1
        verify_noerr(AudioDeviceGetProperty(mID, 1, false, kAudioDevicePropertyVolumeDecibels, &propSize, &volumeDB));
        
    }else{
        //No Support for kAudioDevicePropertyVolumeDecibels
    }
    return volumeDB;
}

int		AudioDevice::CountChannels()
{
	OSStatus err;
	UInt32 propSize;
	int result = 0;
	
	err = AudioDeviceGetPropertyInfo(mID, 0, mIsInput, kAudioDevicePropertyStreamConfiguration, &propSize, NULL);
	if (err) return 0;

	AudioBufferList *buflist = (AudioBufferList *)malloc(propSize);
	err = AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyStreamConfiguration, &propSize, buflist);
	if (!err) {
		for (UInt32 i = 0; i < buflist->mNumberBuffers; ++i) {
			result += buflist->mBuffers[i].mNumberChannels;
		}
	}
	free(buflist);
	return result;
}

char *	AudioDevice::GetName(char *buf, UInt32 maxlen)
{
	verify_noerr(AudioDeviceGetProperty(mID, 0, mIsInput, kAudioDevicePropertyDeviceName, &maxlen, buf));
	return buf;
}
