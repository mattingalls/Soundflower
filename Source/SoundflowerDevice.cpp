/*
  File:SoundflowerDevice.cpp

	Version: 1.0.1, ma++ ingalls
    
	Copyright (c) 2004 Cycling '74

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/

/*
    Soundflower is derived from Apple's 'PhantomAudioDriver'
    sample code.  It uses the same timer mechanism to simulate a hardware
    interrupt, with some additional code to compensate for the software
    timer's inconsistencies.  
    
    Soundflower basically copies the mixbuffer and presents it to clients
    as an input buffer, allowing applications to send audio one another.
*/

#include "SoundflowerDevice.h"
#include "SoundflowerEngine.h"
#include <IOKit/audio/IOAudioControl.h>
#include <IOKit/audio/IOAudioLevelControl.h>
#include <IOKit/audio/IOAudioToggleControl.h>
#include <IOKit/audio/IOAudioDefines.h>
#include <IOKit/IOLib.h>

#define super IOAudioDevice

OSDefineMetaClassAndStructors(SoundflowerDevice, IOAudioDevice)

// There should probably only be one of these? This needs to be 
// set to the last valid position of the log lookup table. 
const SInt32 SoundflowerDevice::kVolumeMax = 99;
const SInt32 SoundflowerDevice::kGainMax = 99;




bool SoundflowerDevice::initHardware(IOService *provider)
{
    bool result = false;
    
	//IOLog("SoundflowerDevice[%p]::initHardware(%p)\n", this, provider);
    
    if (!super::initHardware(provider))
        goto Done;
    
    setDeviceName("Soundflower");
    setDeviceShortName("Soundflower");
    setManufacturerName("ma++ ingalls for Cycling '74");
    
    if (!createAudioEngines())
        goto Done;
    
    result = true;
    
Done:

    return result;
}


bool SoundflowerDevice::createAudioEngines()
{
    OSArray*				audioEngineArray = OSDynamicCast(OSArray, getProperty(AUDIO_ENGINES_KEY));
    OSCollectionIterator*	audioEngineIterator;
    OSDictionary*			audioEngineDict;
	
    if (!audioEngineArray) {
        IOLog("SoundflowerDevice[%p]::createAudioEngine() - Error: no AudioEngine array in personality.\n", this);
        return false;
    }
    
	audioEngineIterator = OSCollectionIterator::withCollection(audioEngineArray);
    if (!audioEngineIterator) {
		IOLog("SoundflowerDevice: no audio engines available.\n");
		return true;
	}
    
    while ((audioEngineDict = (OSDictionary*)audioEngineIterator->getNextObject())) {
		SoundflowerEngine*	audioEngine = NULL;
		
        if (OSDynamicCast(OSDictionary, audioEngineDict) == NULL)
            continue;
        
		audioEngine = new SoundflowerEngine;
        if (!audioEngine)
			continue;
        
        if (!audioEngine->init(audioEngineDict))
			continue;

		initControls(audioEngine);
        activateAudioEngine(audioEngine);	// increments refcount and manages the object
        audioEngine->release();				// decrement refcount so object is released when the manager eventually releases it
    }
	
    audioEngineIterator->release();
    return true;
}


#define addControl(control, handler) \
    if (!control) {\
		IOLog("Soundflower failed to add control.\n");	\
		return false; \
	} \
    control->setValueChangeHandler(handler, this); \
    audioEngine->addDefaultAudioControl(control); \
    control->release();

bool SoundflowerDevice::initControls(SoundflowerEngine* audioEngine)
{
    IOAudioControl*	control = NULL;
    
    for (UInt32 channel=0; channel <= NUM_CHANS; channel++) {
        mVolume[channel] = mGain[channel] = kVolumeMax;
        mMuteOut[channel] = mMuteIn[channel] = false;
    }
    
    const char *channelNameMap[NUM_CHANS+1] = {	kIOAudioControlChannelNameAll,
										kIOAudioControlChannelNameLeft,
										kIOAudioControlChannelNameRight,
										kIOAudioControlChannelNameCenter,
										kIOAudioControlChannelNameLeftRear,
										kIOAudioControlChannelNameRightRear,
										kIOAudioControlChannelNameSub };
	
    for (UInt32 channel=7; channel <= NUM_CHANS; channel++)
        channelNameMap[channel] = "Unknown Channel";
    
    for (unsigned channel=0; channel <= NUM_CHANS; channel++) {
		
        // Create an output volume control for each channel with an int range from 0 to 65535
        // and a db range from -72 to 0
        // Once each control is added to the audio engine, they should be released
        // so that when the audio engine is done with them, they get freed properly
		 
		 // Volume level notes.
		 //
		 // Previously, the minimum volume was actually 10*log10(1/65535) = -48.2 dB. In the new
		 // scheme, we use a size 100 lookup table to compute the correct log scaling. And set
		 // the minimum to -40 dB. Perhaps -50 dB would have been better, but this seems ok.
		 
        control = IOAudioLevelControl::createVolumeControl(SoundflowerDevice::kVolumeMax,		// Initial value
                                                           0,									// min value
                                                           SoundflowerDevice::kVolumeMax,		// max value
                                                           (UInt32(1 + ~40) << 16) + (32768),	// -72 in IOFixed (16.16)
                                                           0,									// max 0.0 in IOFixed
                                                           channel,								// kIOAudioControlChannelIDDefaultLeft,
                                                           channelNameMap[channel],				// kIOAudioControlChannelNameLeft,
                                                           channel,								// control ID - driver-defined
                                                           kIOAudioControlUsageOutput);
        addControl(control, (IOAudioControl::IntValueChangeHandler)volumeChangeHandler);
        
        // Gain control for each channel
        control = IOAudioLevelControl::createVolumeControl(SoundflowerDevice::kGainMax,			// Initial value
                                                           0,									// min value
                                                           SoundflowerDevice::kGainMax,			// max value
                                                           0,									// min 0.0 in IOFixed
                                                           (40 << 16) + (32768),				// 72 in IOFixed (16.16)
                                                           channel,								// kIOAudioControlChannelIDDefaultLeft,
                                                           channelNameMap[channel],				// kIOAudioControlChannelNameLeft,
                                                           channel,								// control ID - driver-defined
                                                           kIOAudioControlUsageInput);
        addControl(control, (IOAudioControl::IntValueChangeHandler)gainChangeHandler);
    }
	
    // Create an output mute control
    control = IOAudioToggleControl::createMuteControl(false,									// initial state - unmuted
                                                      kIOAudioControlChannelIDAll,				// Affects all channels
                                                      kIOAudioControlChannelNameAll,
                                                      0,										// control ID - driver-defined
                                                      kIOAudioControlUsageOutput);
    addControl(control, (IOAudioControl::IntValueChangeHandler)outputMuteChangeHandler);
    
    // Create an input mute control
    control = IOAudioToggleControl::createMuteControl(false,									// initial state - unmuted
                                                      kIOAudioControlChannelIDAll,				// Affects all channels
                                                      kIOAudioControlChannelNameAll,
                                                      0,										// control ID - driver-defined
                                                      kIOAudioControlUsageInput);
    addControl(control, (IOAudioControl::IntValueChangeHandler)inputMuteChangeHandler);
    
    return true;
}


IOReturn SoundflowerDevice::volumeChangeHandler(IOService *target, IOAudioControl *volumeControl, SInt32 oldValue, SInt32 newValue)
{
    IOReturn			result = kIOReturnBadArgument;
    SoundflowerDevice*	audioDevice = (SoundflowerDevice *)target;
	
    if (audioDevice)
        result = audioDevice->volumeChanged(volumeControl, oldValue, newValue);
    return result;
}


IOReturn SoundflowerDevice::volumeChanged(IOAudioControl *volumeControl, SInt32 oldValue, SInt32 newValue)
{
    if (volumeControl)
         mVolume[volumeControl->getChannelID()] = newValue;
    return kIOReturnSuccess;
}


IOReturn SoundflowerDevice::outputMuteChangeHandler(IOService *target, IOAudioControl *muteControl, SInt32 oldValue, SInt32 newValue)
{
    IOReturn			result = kIOReturnBadArgument;
    SoundflowerDevice*	audioDevice = (SoundflowerDevice*)target;
	
    if (audioDevice)
        result = audioDevice->outputMuteChanged(muteControl, oldValue, newValue);
    return result;
}


IOReturn SoundflowerDevice::outputMuteChanged(IOAudioControl *muteControl, SInt32 oldValue, SInt32 newValue)
{
    if (muteControl)
         mMuteOut[muteControl->getChannelID()] = newValue;
    return kIOReturnSuccess;
}


IOReturn SoundflowerDevice::gainChangeHandler(IOService *target, IOAudioControl *gainControl, SInt32 oldValue, SInt32 newValue)
{
    IOReturn			result = kIOReturnBadArgument;
    SoundflowerDevice*	audioDevice = (SoundflowerDevice *)target;
	
    if (audioDevice)
        result = audioDevice->gainChanged(gainControl, oldValue, newValue);
    return result;
}


IOReturn SoundflowerDevice::gainChanged(IOAudioControl *gainControl, SInt32 oldValue, SInt32 newValue)
{
    if (gainControl)
		mGain[gainControl->getChannelID()] = newValue;
    return kIOReturnSuccess;
}


IOReturn SoundflowerDevice::inputMuteChangeHandler(IOService *target, IOAudioControl *muteControl, SInt32 oldValue, SInt32 newValue)
{
    IOReturn			result = kIOReturnBadArgument;
    SoundflowerDevice*	audioDevice = (SoundflowerDevice*)target;

    if (audioDevice)
        result = audioDevice->inputMuteChanged(muteControl, oldValue, newValue);
    return result;
}


IOReturn SoundflowerDevice::inputMuteChanged(IOAudioControl *muteControl, SInt32 oldValue, SInt32 newValue)
{
    if (muteControl)
         mMuteIn[muteControl->getChannelID()] = newValue;
    return kIOReturnSuccess;
}
