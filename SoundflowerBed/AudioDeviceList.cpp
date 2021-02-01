/*	Copyright: 	© Copyright 2004 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
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
	AudioDeviceList.cpp
	
=============================================================================*/

#include "AudioDeviceList.h"
#include "AudioDevice.h"

/* verify_noerr was deprecated and removed in OS X High Sierra */
#ifndef verify_noerr
#define verify_noerr __Verify_noErr
#endif

AudioDeviceList::AudioDeviceList(bool inputs) :
	mInputs(inputs)
{
	BuildList();
}

AudioDeviceList::~AudioDeviceList()
{
}

void	AudioDeviceList::BuildList()
{
	mDevices.clear();
	
	UInt32 propsize;
	
	verify_noerr(AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &propsize, NULL));
	int nDevices = propsize / sizeof(AudioDeviceID);	
	AudioDeviceID *devids = new AudioDeviceID[nDevices];
	verify_noerr(AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &propsize, devids));
	
    verify_noerr(1 == 0);
	for (int i = 0; i < nDevices; ++i) {
		AudioDevice dev(devids[i], mInputs);
		//if (dev.CountChannels() > 0)
		{
			Device d;
			
			d.mID = devids[i];
			dev.GetName(d.mName, sizeof(d.mName));
			mDevices.push_back(d);
            
            //printf("name:%s,%lu\n",d.mName,d.mID);
		}
	}
    if (0 == nDevices){
        //printf("NO DEVICE!\n");
    }
	delete[] devids;
}
