/*	
*/

#import "AppController.h"


#include <CoreServices/CoreServices.h>
#include <CoreAudio/CoreAudio.h>

@implementation AppController

void	CheckErr(OSStatus err)
{
	if (err) {
		printf("error %-4.4s %i\n", (char *)&err, (int)err);
		throw 1;
	}
}

OSStatus	HardwareListenerProc (	AudioHardwarePropertyID	inPropertyID,
                                    void*					inClientData)
{
	AppController *app = (AppController *)inClientData;
    printf("HardwareListenerProc\n");
    
    switch(inPropertyID)
    { 
        case kAudioHardwarePropertyDevices:
//			printf("kAudioHardwarePropertyDevices\n");
			
       		// An audio device has been added or removed to the system, so lets just start over
            //[NSThread detachNewThreadSelector:@selector(refreshDevices) toTarget:app withObject:nil];
            [app refreshDevices];
            break;
			
        case kAudioHardwarePropertyIsInitingOrExiting:
            printf("kAudioHardwarePropertyIsInitingOrExiting\n");
                       // A UInt32 whose value will be non-zero if the HAL is either in the midst of
                        //initializing or in the midst of exiting the process.
            break;
			
        case kAudioHardwarePropertySleepingIsAllowed:
            printf("kAudioHardwarePropertySleepingIsAllowed\n");
                    //    A UInt32 where 1 means that the process will allow the CPU to idle sleep
                    //    even if there is audio IO in progress. A 0 means that the CPU will not be
                    //    allowed to idle sleep. Note that this property won't affect when the CPU is
                    //    forced to sleep.
            break;
			
        case kAudioHardwarePropertyUnloadingIsAllowed:
            printf("kAudioHardwarePropertyUnloadingIsAllowed\n");
                     //   A UInt32 where 1 means that this process wants the HAL to unload itself
                     //   after a period of inactivity where there are no IOProcs and no listeners
                     //   registered with any AudioObject.
			break;

    }
    
    return (noErr);
}

OSStatus	DeviceListenerProc (	AudioDeviceID           inDevice,
                                    UInt32                  inChannel,
                                    Boolean                 isInput,
                                    AudioDevicePropertyID   inPropertyID,
                                    void*                   inClientData)
{
	AppController *app = (AppController *)inClientData;
	
    switch(inPropertyID)
    {		
        case kAudioDevicePropertyNominalSampleRate:
			//printf("kAudioDevicePropertyNominalSampleRate\n");	
			if (isInput) {
				//printf("soundflower device potential sample rate change\n");	
				if (app->mThruEngine[0]->IsRunning() && app->mThruEngine[0]->GetInputDevice() == inDevice){
					//[NSThread detachNewThreadSelector:@selector(srChanged2ch) toTarget:app withObject:nil];
                    [app srChanged2ch];
                }
                else if (app->mThruEngine[1]->IsRunning() && app->mThruEngine[1]->GetInputDevice() == inDevice){
					//[NSThread detachNewThreadSelector:@selector(srChanged16ch) toTarget:app withObject:nil];
                    [app srChanged16ch];
                }
			}
			else {
				if (inChannel == 0) {
					//printf("non-soundflower device potential sample rate change\n");
					if (app->mThruEngine[0]->IsRunning() && app->mThruEngine[0]->GetOutputDevice() == inDevice){
						//[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
                        [app srChanged2chOutput];
                    }else if (app->mThruEngine[1]->IsRunning() && app->mThruEngine[1]->GetOutputDevice() == inDevice){
                        //[NSThread detachNewThreadSelector:@selector(srChanged16chOutput) toTarget:app withObject:nil];
                        [app srChanged16chOutput];
                    
                    }
				}
			}
			break;
	
		case kAudioDevicePropertyDeviceIsAlive:
//			printf("kAudioDevicePropertyDeviceIsAlive\n");	
			break;
				
		case kAudioDevicePropertyDeviceHasChanged:
//			printf("kAudioDevicePropertyDeviceHasChanged\n");	
			break;
				
		case kAudioDevicePropertyDataSource:
			// printf("DeviceListenerProc : HEADPHONES! \n");
			if (app->mThruEngine[0]->IsRunning() && app->mThruEngine[0]->GetOutputDevice() == inDevice){
				//[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
                [app srChanged2chOutput];
            }else if (app->mThruEngine[1]->IsRunning() && app->mThruEngine[1]->GetOutputDevice() == inDevice){
				//[NSThread detachNewThreadSelector:@selector(srChanged16chOutput) toTarget:app withObject:nil];
                [app srChanged16chOutput];
            }
			break;
            
        case kAudioDevicePropertyVolumeScalar:
            NSLog(@"kAudioDevicePropertyVolumeScalar");
            if (app->mThruEngine[0]->GetOutputDevice() == inDevice){
                [app volChanged2ch];
            }
            break;
			
		case kAudioDevicePropertyDeviceIsRunning:
//			printf("kAudioDevicePropertyDeviceIsRunning\n");	
			break;
				
		case kAudioDeviceProcessorOverload:
//			printf("kAudioDeviceProcessorOverload\n");	
			break;
			
		case kAudioDevicePropertyAvailableNominalSampleRates:
			//printf("kAudioDevicePropertyAvailableNominalSampleRates\n");	
			break;
			
		case kAudioStreamPropertyPhysicalFormat:
			//printf("kAudioStreamPropertyPhysicalFormat\n");	
			break;
		case kAudioDevicePropertyStreamFormat:
			//printf("kAudioDevicePropertyStreamFormat\n");	
			break;
			
		case kAudioDevicePropertyStreams:
			//printf("kAudioDevicePropertyStreams\n");
		case kAudioDevicePropertyStreamConfiguration:
			//printf("kAudioDevicePropertyStreamConfiguration\n");
			if (!isInput) {
				if (inChannel == 0) {
					if (app->mThruEngine[0]->GetOutputDevice() == inDevice || app->mThruEngine[1]->GetOutputDevice() == inDevice) {
						//printf("non-soundflower device potential # of chnls change\n");
						//[NSThread detachNewThreadSelector:@selector(checkNchnls) toTarget:app withObject:nil];
                        [app checkNchnls];
					}
					else{ // this could be an aggregate device in the middle of constructing, going from/to 0 chans & we need to add/remove to menu
						//[NSThread detachNewThreadSelector:@selector(refreshDevices) toTarget:app withObject:nil];
                        [app refreshDevices];
                    }
				}
			}
			break;
		
		default:
			//printf("unsupported notification:%s\n", (char*)inPropertyID);	
			break;
	}
	
	return noErr;
}

#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

io_connect_t  root_port;

void
MySleepCallBack(void * x, io_service_t y, natural_t messageType, void * messageArgument)
{  
	AppController *app = (AppController *)x;

    switch ( messageType ) {
        case kIOMessageSystemWillSleep:
		    //printf("kIOMessageSystemWillSleep\n");

            [app suspend];
            IOAllowPowerChange(root_port, (long)messageArgument);
            break;
			
		case kIOMessageSystemWillNotSleep:
			//printf("kIOMessageSystemWillNotSleep\n");
			break;
			
        case kIOMessageCanSystemSleep:
			 //printf("kIOMessageCanSystemSleep\n");
            /* Idle sleep is about to kick in, but applications have a chance to prevent sleep
            by calling IOCancelPowerChange.  Most applications should not do this. */

            //IOCancelPowerChange(root_port, (long)messageArgument);

            /*  Power Manager waits for your reply via one of these functions for up
            to 30 seconds. If you don't acknowledge the power change by calling
            IOAllowPowerChange(), you'll delay sleep by 30 seconds. */

            IOAllowPowerChange(root_port, (long)messageArgument);
            break;

        case kIOMessageSystemHasPoweredOn:
			//printf("kIOMessageSystemHasPoweredOn\n");
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:app selector:@selector(resume) userInfo:nil repeats:NO];
		
			break;
			
		default:
			 //printf("iomessage: %08lx\n", messageType);//"kIOMessageSystemWillPowerOn\n");
			break;
    }
}

- (IBAction)suspend
{
    //printf("begin suspend\n");
    mSuspended2chDeviceID = mThruEngine[0]->GetOutputDevice();
    //mThruEngine[0]->SetOutputDevice(kAudioDeviceUnknown);
    [self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex]];
    
    mSuspended16chDeviceID = mThruEngine[1]->GetOutputDevice();
    //mThruEngine[1]->SetOutputDevice(kAudioDeviceUnknown);
    [self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex]];
    //printf("return suspend\n");
}

- (IBAction)resume
{
    //printf("resume\n");
    
    if (mSuspended2chDeviceID == kAudioDeviceUnknown && mSuspended16chDeviceID == kAudioDeviceUnknown){
        return;
    }
    
    [self refreshDevices];
    
    if (mSuspended2chDeviceID != kAudioDeviceUnknown){
        //find index for suspended device ID
    
        int index = -1;
        for (int i = 0 ; i < 64 ; i++){
            if (mMenuID2[i] == mSuspended2chDeviceID){
                index = i;
                break;
            }
        }
        if (index < 0){
            printf("device disconnected while sleep");
        }else{
            [self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex+1+index]];
        }
    }

    if (mSuspended16chDeviceID != kAudioDeviceUnknown){
        //find index for suspended device ID
        
        int index = -1;
        for (int i = 0 ; i < 64 ; i++){
            if (mMenuID16[i] == mSuspended16chDeviceID){
                index = i;
                break;
            }
        }
        if (index < 0){
            printf("device disconnected while sleep");
        }else{
            [self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex+1+index]];
        }
    }
    
}


- (IBAction)srChanged2ch
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mThruEngine[0]->Mute();
	OSStatus err = mThruEngine[0]->MatchSampleRate(true);
			
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	
	mThruEngine[0]->Mute(false);
	
	[pool release];
}


- (IBAction)srChanged16ch
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mThruEngine[1]->Mute();
	OSStatus err = mThruEngine[1]->MatchSampleRate(true);

	NSMenuItem *curdev = mCur16chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	mThruEngine[1]->Mute(false);
	
	[pool release];
}

- (IBAction)srChanged2chOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mThruEngine[0]->Mute();
	OSStatus err = mThruEngine[0]->MatchSampleRate(false);
			
	// restart devices
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	mThruEngine[0]->Mute(false);
	
	[pool release];
}

- (IBAction)srChanged16chOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mThruEngine[1]->Mute();
	OSStatus err = mThruEngine[1]->MatchSampleRate(false);
			
	// restart devices
	NSMenuItem	*curdev = mCur16chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	mThruEngine[1]->Mute(false);
	
	[pool release];
}


- (IBAction)checkNchnls
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (mNchnls2 != mThruEngine[0]->GetOutputNchnls())
	 {
		NSMenuItem	*curdev = mCur2chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex]];
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
		
	if (mNchnls16 != mThruEngine[1]->GetOutputNchnls()) 
	{
		NSMenuItem	*curdev = mCur16chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex]];
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	
	[pool release];
}


- (IBAction)refreshDevices
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self buildDeviceList];
	[mSbItem setMenu:nil];
	//[mMenu dealloc];
    [mMenu release];
	
	[self buildMenu];
	
	// make sure that one of our current device's was not removed!
	AudioDeviceID dev = mThruEngine[0]->GetOutputDevice();
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	AudioDeviceList::DeviceList::iterator i;
	for (i = thelist.begin(); i != thelist.end(); ++i){
		if ((*i).mID == dev) {
            break;
        }
    }
    
	if (i == thelist.end()){ // we didn't find it, turn selection to none
        [self outputDeviceSelected:[mMenu itemAtIndex:m2StartIndex]];
    }else{
        [[mMenu itemAtIndex:m2StartIndex] setState:NSOffState];
        
        for (int i = 0 ; i < 64 ; i++){
            if (mMenuID2[i] == dev){
                mCur2chDevice = [mMenu itemAtIndex:m2StartIndex+1+i];
                break;
            }
        }
        
		[mCur2chDevice setState:NSOnState];
        
        AudioDevice outDevice(dev,false);
        VolumeView *volumeView = (VolumeView *)[mVolumeViewController2ch view];
        if (outDevice.IsVolumeAvailableForMaster() || outDevice.IsVolumeAvailableForChannels()){
            [volumeView setEnabled:true];
            float scalar = outDevice.GetVolumeScalar();
            float db = outDevice.GetVolumeDB();
            [volumeView setScalar: scalar];
            [volumeView setDB: db];
        }
		[self buildRoutingMenu:YES];
	}
    
	dev = mThruEngine[1]->GetOutputDevice();
	for ( i= thelist.begin(); i != thelist.end(); ++i){
		if ((*i).mID == dev){
			break;
        }
    }
	if (i == thelist.end()) // we didn't find it, turn selection to none
		[self outputDeviceSelected:[mMenu itemAtIndex:m16StartIndex]];
	else{
        [[mMenu itemAtIndex:m16StartIndex] setState:NSOffState];
        
        for (int i = 0; i < 64; i++){
            if (mMenuID16[i] == dev){
                mCur16chDevice = [mMenu itemAtIndex:(m16StartIndex+1+i)];
                break;
            }
        }
        
		[mCur16chDevice setState:NSOnState];
		[self buildRoutingMenu:NO];
    }

	[pool release];
}



- (void)InstallListeners;
{	
	// add listeners for all devices, including soundflowers
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strncmp("Soundflower", (*i).mName, strlen("Soundflower"))) {
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioStreamPropertyPhysicalFormat, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyStreamFormat, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyLatency, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertySafetyOffset, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyAvailableNominalSampleRates, DeviceListenerProc, self));
			
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyDeviceIsAlive, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyDeviceHasChanged, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyDeviceIsRunning, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDeviceProcessorOverload, DeviceListenerProc, self));
		}
		else {
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioStreamPropertyPhysicalFormat, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreamFormat, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyLatency, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertySafetyOffset, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc, self));
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreams, DeviceListenerProc, self));
			//__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyAvailableNominalSampleRates, DeviceListenerProc, self));

			// this provides us, for example, with notification when the headphones are plugged/unplugged during playback
			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyDataSource, DeviceListenerProc, self));

			__Verify_noErr (AudioDeviceAddPropertyListener((*i).mID, 1, false, kAudioDevicePropertyVolumeScalar, DeviceListenerProc, self));
		}
	}
		
	// check for added/removed devices
   __Verify_noErr (AudioHardwareAddPropertyListener(kAudioHardwarePropertyDevices, HardwareListenerProc, self));
   
	__Verify_noErr (AudioHardwareAddPropertyListener(kAudioHardwarePropertyIsInitingOrExiting, HardwareListenerProc, self));
	__Verify_noErr (AudioHardwareAddPropertyListener(kAudioHardwarePropertySleepingIsAllowed, HardwareListenerProc, self));
	__Verify_noErr (AudioHardwareAddPropertyListener(kAudioHardwarePropertyUnloadingIsAllowed, HardwareListenerProc, self));
	
/*	UInt32 val, size = sizeof(UInt32);
	AudioHardwareGetProperty(kAudioHardwarePropertySleepingIsAllowed, &size, &val);
	printf("Sleep is %s\n", (val ? "allowed" : "not allowed"));
	AudioHardwareGetProperty(kAudioHardwarePropertyUnloadingIsAllowed, &size, &val);
	printf("Unloading is %s\n", (val ? "allowed" : "not allowed"));
*/
}	

- (void)RemoveListeners
{
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strncmp("Soundflower", (*i).mName, strlen("Soundflower"))) {
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, true, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc));
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, true, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc));
		}
		else {
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc));
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc));
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreams, DeviceListenerProc));
			__Verify_noErr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyDataSource, DeviceListenerProc));
		}
	}

	 __Verify_noErr (AudioHardwareRemovePropertyListener(kAudioHardwarePropertyDevices, HardwareListenerProc));
}

- (id)init
{
	mOutputDeviceList = NULL;
	
	mSoundflower2Device = 0;
	mSoundflower16Device = 0;
	mNchnls2 = 0;
	mNchnls16 = 0;
	
	//mSuspended2chDevice = NULL;
	//mSuspended16chDevice = NULL;
	
	return self;
}

- (void)dealloc
{
	[ self RemoveListeners];
	delete mOutputDeviceList;
		
	[super dealloc];
}

/*- (void)updateThruLatency
{
	[mTotalLatencyText setIntValue:gThruEngine->GetThruLatency()];
}
*/
- (void)buildRoutingMenu:(BOOL)is2ch
{
	NSMenuItem *hostMenu = (is2ch ? m2chMenu : m16chMenu);
	UInt32 nchnls = (is2ch ? mNchnls2 = mThruEngine[0]->GetOutputNchnls() : mNchnls16 = mThruEngine[1]->GetOutputNchnls());
	AudioDeviceID outDev = (is2ch ? mThruEngine[0]->GetOutputDevice(): mThruEngine[1]->GetOutputDevice());
	SEL menuAction = (is2ch ? @selector(routingChanged2ch:): @selector(routingChanged16ch:));
	
	for (UInt32 menucount = 0; menucount < (is2ch ? 2 : 16); menucount++) {
		NSMenuItem *superMenu = [[hostMenu submenu] itemAtIndex:(menucount+3)];
		
		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Output Device Channel"];
		NSMenuItem *item;
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		char *name = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			if ((*i).mID == outDev)
				name = (*i).mName;
		}
		
		item = [menu addItemWithTitle:@"None" action:menuAction keyEquivalent:@""];
		[item setState:NSOnState];
		
		char text[128];
		for (UInt32 c = 1; c <= nchnls; ++c) {
			sprintf(text, "%s [%d]", name, (int)c);
			item = [menu addItemWithTitle:[NSString stringWithCString:text] action:menuAction keyEquivalent:@""];
			[item setTarget:self];
			
			// set check marks according to route map	
			if (c == 1 + (is2ch ? (UInt32)mThruEngine[0]->GetChannelMap(menucount) : (UInt32)mThruEngine[1]->GetChannelMap(menucount))) {
				[[menu itemAtIndex:0] setState:NSOffState];
				[item setState:NSOnState];
			}
		}
		
		[superMenu setSubmenu:menu];
	}
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];
    for (int i = 0; i < 64; i++){
        mMenuID2[i] = 0;
    }
		
	if (mSoundflower2Device) {
		m2chMenu = [mMenu addItemWithTitle:@"Soundflower (2ch)" action:@selector(doNothing) keyEquivalent:@""];
		[m2chMenu setImage:[NSImage imageNamed:@"sf2"]];
		[m2chMenu setTarget:self];
			NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"2ch submenu"];
			NSMenuItem *bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
				m2chBuffer = [[NSMenu alloc] initWithTitle:@"2ch Buffer"];
				item = [m2chBuffer addItemWithTitle:@"64" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"128" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"256" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"512" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				[item setState:NSOnState]; // default
				mCur2chBufferSize = item;
				item = [m2chBuffer addItemWithTitle:@"1024" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];
				item = [m2chBuffer addItemWithTitle:@"2048" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];
			[bufItem setSubmenu:m2chBuffer];

			[submenu addItem:[NSMenuItem separatorItem]];
					
			item = [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
			item = [submenu addItemWithTitle:@"Channel 1" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 2" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
		
			// iSchemy's edit
			//
			[submenu addItem:[NSMenuItem separatorItem]];
		
			[[submenu addItemWithTitle:@"Clone to all channels" action:@selector(cloningChanged:) keyEquivalent:@""] setTarget:self];
			//
			// end
		
		[m2chMenu setSubmenu:submenu];
	
        //Volume Slider
        NSMenuItem *volumeMenu = [mMenu addItemWithTitle:@"Volume2" action:
                @selector(doNothing) keyEquivalent:@""];
        [volumeMenu setView:[mVolumeViewController2ch view]];
        [[mVolumeViewController2ch view] setEnabled:false];
        
		item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
		[item setTarget:self];
		[item setState:NSOnState];
		m2StartIndex = [mMenu indexOfItem:item];
        mCur2chDevice = item;
        
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		int index = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			AudioDevice ad((*i).mID, false);
			if (ad.CountChannels()) 
			{
				item = [mMenu addItemWithTitle:[NSString stringWithUTF8String: (*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
				[item setTarget:self];
				mMenuID2[index++] = (*i).mID;
			}
		}
	}
	else {
		item = [mMenu addItemWithTitle:@"Soundflower Is Not Installed!!" action:NULL keyEquivalent:@""];
		[item setTarget:self];
	}
	
	[mMenu addItem:[NSMenuItem separatorItem]];
	
	
	if (mSoundflower16Device) {
	
		m16chMenu = [mMenu addItemWithTitle:@"Soundflower (64ch)" action:@selector(doNothing) keyEquivalent:@""];
		[m16chMenu setImage:[NSImage imageNamed:@"sf16"]];
		[m16chMenu setTarget:self];
			NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"16ch submenu"];
				NSMenuItem *bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
				m16chBuffer = [[NSMenu alloc] initWithTitle:@"16ch Buffer"];
				item = [m16chBuffer addItemWithTitle:@"64" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"128" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"256" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"512" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				[item setState:NSOnState]; // default
				mCur16chBufferSize = item;
				item = [m16chBuffer addItemWithTitle:@"1024" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];
				item = [m16chBuffer addItemWithTitle:@"2048" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];
			[bufItem setSubmenu:m16chBuffer];

			[submenu addItem:[NSMenuItem separatorItem]];
			
			item = [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
			item = [submenu addItemWithTitle:@"Channel 1" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 2" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 3" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 4" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 5" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 6" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 7" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 8" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];
			item = [submenu addItemWithTitle:@"Channel 9" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 10" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 11" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 12" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];
			item = [submenu addItemWithTitle:@"Channel 13" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 14" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 15" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 16" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
		[m16chMenu setSubmenu:submenu];
        
        NSMenuItem *volumeMenu2 = [mMenu addItemWithTitle:@"Volume16" action:
                                   @selector(doNothing) keyEquivalent:@""];
        [volumeMenu2 setView:[mVolumeViewController16ch view]];
        [[mVolumeViewController16ch view] setEnabled:false];
        
		item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
		[item setTarget:self];
		[item setState:NSOnState];
		m16StartIndex = [mMenu indexOfItem:item];
        mCur16chDevice = item;
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		int index = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			AudioDevice ad((*i).mID, false);
			if (ad.CountChannels()) 
			{
				item = [mMenu addItemWithTitle:[NSString stringWithUTF8String: (*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
				[item setTarget:self];	
				mMenuID16[index++] = (*i).mID;
			}
		}
		
		[mMenu addItem:[NSMenuItem separatorItem]];
	}
	
	item = [mMenu addItemWithTitle:@"Audio Setup..." action:@selector(doAudioSetup) keyEquivalent:@""];
	[item setTarget:self];
	
	item = [mMenu addItemWithTitle:@"About Soundflowerbed..." action:@selector(doAbout) keyEquivalent:@""];
	[item setTarget:self];
    
	// item = [mMenu addItemWithTitle:@"Hide Soundflowerbed" action:@selector(hideMenuItem) keyEquivalent:@""];
	// [item setTarget:self];
	
	item = [mMenu addItemWithTitle:@"Quit Soundflowerbed" action:@selector(doQuit) keyEquivalent:@""];
	[item setTarget:self];

	[mSbItem setMenu:mMenu];
}

- (void)buildDeviceList
{
	if (mOutputDeviceList) {
		[ self RemoveListeners];
		delete mOutputDeviceList;
	}
	
    
    //Sometimes selecting "Airplay" causes empty device list for a while and then
    //changes all DeviceID(CoreAudio Restarted??), In that case we need retart
    Boolean restartRequired = false;
	mOutputDeviceList = new AudioDeviceList(false);
    while(mOutputDeviceList->GetList().size() == 0){
        restartRequired = true;
        delete mOutputDeviceList;
        [NSThread sleepForTimeInterval:0.1];
        mOutputDeviceList = new AudioDeviceList(false);
        NSLog(@"----------waiting for devices");
    }
	
	// find soundflower devices, store and remove them from our output list
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strcmp("Soundflower (2ch)", (*i).mName)) {
			mSoundflower2Device = (*i).mID;
			AudioDeviceList::DeviceList::iterator toerase = i;
			i--;
			thelist.erase(toerase);
		}
		else if (0 == strcmp("Soundflower (16ch)", (*i).mName)) {
			mSoundflower16Device = (*i).mID;
			AudioDeviceList::DeviceList::iterator toerase = i;
			i--;
			thelist.erase(toerase);
		}
        else if (0 == strcmp("Soundflower (64ch)", (*i).mName)) {
            mSoundflower16Device = (*i).mID;
            AudioDeviceList::DeviceList::iterator toerase = i;
            i--;
            thelist.erase(toerase);
        }
	}
    
    if (restartRequired) {
        NSLog(@"restarting Thru Engines");
        
        if (mThruEngine[0]){
            delete mThruEngine[0];
            mThruEngine[0] = NULL;
        }
       
        if (mThruEngine[1]){
            delete mThruEngine[1];
            mThruEngine[0] = NULL;
        }
    }

    if ((!mThruEngine[0] || !mThruEngine[1]) && mSoundflower2Device && mSoundflower16Device) {

        mThruEngine[0] = new AudioThruEngine;
        mThruEngine[0]->SetInputDevice(mSoundflower2Device);
        
        mThruEngine[1] = new AudioThruEngine;
        mThruEngine[1]->SetInputDevice(mSoundflower16Device);
        
        mThruEngine[0]->Start();
        mThruEngine[1]->Start();
    }

    [self InstallListeners];
    
}

- (void)awakeFromNib
{
	[[NSApplication sharedApplication] setDelegate:self];
    
    mVolumeViewController2ch = [[VolumeViewController alloc] initWithNibName:@"VolumeView" bundle:nil];
    NSSlider *slider = (NSSlider *)[[mVolumeViewController2ch view] slider];
    [slider setTarget:self];
    [slider setAction:@selector(setVolume2ch:)];
    mVolumeViewController16ch = [[VolumeViewController alloc] initWithNibName:@"VolumeView" bundle:nil];

	
	[self buildDeviceList];
	
	mSbItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[mSbItem retain];
	
	//[sbItem setTitle:@"ее"];
	[mSbItem setImage:[NSImage imageNamed:@"menuIcon"]];
	[mSbItem setHighlightMode:YES];
	
	[self buildMenu];
	
	if (mSoundflower2Device && mSoundflower16Device) {
		mThruEngine[0] = new AudioThruEngine;
		mThruEngine[0]->SetInputDevice(mSoundflower2Device);
		
		mThruEngine[1] = new AudioThruEngine;
		mThruEngine[1]->SetInputDevice(mSoundflower16Device);

		mThruEngine[0]->Start();
		mThruEngine[1]->Start();
		
		// build default 'off' channel routing menus
		[self buildRoutingMenu:YES];
		[self buildRoutingMenu:NO];
		
		// now read prefs
		[self readGlobalPrefs];
	}
	
	// ask to be notified on system sleep to avoid a crash
	IONotificationPortRef  notify;
    io_object_t            anIterator;

    root_port = IORegisterForSystemPower(self, &notify, MySleepCallBack, &anIterator);
    if ( !root_port ) {
		printf("IORegisterForSystemPower failed\n");
    }
	else
		CFRunLoopAddSource(CFRunLoopGetCurrent(),
                        IONotificationPortGetRunLoopSource(notify),
                        kCFRunLoopCommonModes);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (mThruEngine[0])
		mThruEngine[0]->Stop();
		
	if (mThruEngine[1])
		mThruEngine[1]->Stop();
		
	if (mSoundflower2Device && mSoundflower16Device)
		[self writeGlobalPrefs];
}


- (IBAction)bufferSizeChanged2ch:(id)sender
{
	UInt32 val = [m2chBuffer indexOfItem:sender];
	UInt32 size = 64 << val;
	mThruEngine[0]->SetBufferSize(size);

	[mCur2chBufferSize setState:NSOffState];
	[sender setState:NSOnState];
	mCur2chBufferSize = sender;
}

- (IBAction)bufferSizeChanged16ch:(id)sender
{
	UInt32 val = [m2chBuffer indexOfItem:sender];
	UInt32 size = 64 << val;
	mThruEngine[1]->SetBufferSize(size);

	[mCur16chBufferSize setState:NSOffState];
	[sender setState:NSOnState];
	mCur16chBufferSize = sender;
}

// iSchemy's edit
//
// action for item was clicked
- (IBAction)cloningChanged:(id)sender 
{
	// change item's state
	[sender setState:([sender state]==NSOnState) ? NSOffState : NSOnState];
	mThruEngine[0]->SetCloneChannels([sender state]==NSOnState);
	[self writeDevicePrefs:YES];
}

// preferences read
- (IBAction)cloningChanged:(id)sender cloneChannels:(bool)clone
{
	mThruEngine[0]->SetCloneChannels(clone);
	[sender setState:(clone ? NSOnState : NSOffState)];
}
//
// end

- (IBAction)routingChanged2ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];
	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	
	// set the new channel map
	mThruEngine[0]->SetChannelMap(sfChan, outDevChan-1);
	
	// turn off all check marks
	for (int i = 0; i < [outDevMenu numberOfItems]; i++)
		[[outDevMenu itemAtIndex:i] setState:NSOffState];
		
	// set this one
	[outDevChanItem setState:NSOnState];
		
	// write to prefs
	[self writeDevicePrefs:YES];
}

- (IBAction)routingChanged16ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];
	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	
	mThruEngine[1]->SetChannelMap(sfChan, outDevChan-1);
	
	// turn off all check marks
	for (int i = 0; i < [outDevMenu numberOfItems]; i++)
		[[outDevMenu itemAtIndex:i] setState:NSOffState];
		
	// set this one
	[outDevChanItem setState:NSOnState];
	
	// write to prefs
	[self writeDevicePrefs:NO];
}

- (IBAction)volChanged2ch
{
    AudioDeviceID outDevID = mThruEngine[0]->GetOutputDevice();
    if (outDevID == kAudioDeviceUnknown){
        return;
    }
    
    AudioDevice device(outDevID, false);
    VolumeView *view = (VolumeView *)[mVolumeViewController2ch view];
    [view setScalar:device.GetVolumeScalar()];
    [view setDB:device.GetVolumeDB()];
}

- (IBAction)setVolume2ch:(id)sender
{
    NSSlider *slider = (NSSlider *)sender;
    NSLog(@"vol changed to %f",[slider floatValue]);
    //
    
    AudioDeviceID outDevID = mThruEngine[0]->GetOutputDevice();
    if (outDevID == kAudioDeviceUnknown){
        return;
    }
    
    AudioDevice device(outDevID,false);
    
    device.SetVolumeScalar([slider floatValue]);
    VolumeView *view = (VolumeView *)[sender superview];
    [view setDB:device.GetVolumeDB()];
    
}

- (IBAction)outputDeviceSelected:(id)sender
{
	int val = [mMenu indexOfItem:sender];
	if (val < m16StartIndex) {
		//val -= 2;
		val -= (m2StartIndex + 1);
		// if 'None' was selected, our val will be == -1, which will return a NULL
		// device from the list, which is what we want anyway, and seems to work
		// here -- probably should check to see if there are any potential problems
		// and handle this more properly
		mThruEngine[0]->SetOutputDevice( (val < 0 ? kAudioDeviceUnknown : mMenuID2[val]) );
		//[self updateThruLatency];	
		
		[mCur2chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur2chDevice = sender;
		
		// get the channel routing from the prefs
		[self readDevicePrefs:YES];
	
		// now set the menu
		[self buildRoutingMenu:YES];
        
        //
        AudioDevice outDevice((val <0 ? kAudioDeviceUnknown : mMenuID2[val]), false);
        VolumeView *volumeView = (VolumeView *)[mVolumeViewController2ch view];
        [volumeView setEnabled:false];
        if (outDevice.mID != kAudioDeviceUnknown){
            if (outDevice.IsVolumeAvailableForMaster() || outDevice.IsVolumeAvailableForChannels()){
                [volumeView setEnabled:true];
                float scalar = outDevice.GetVolumeScalar();
                float db = outDevice.GetVolumeDB();
                [volumeView setScalar: scalar];
                [volumeView setDB: db];
            }
        }
	}
	else {
		//val -= (m16StartIndex+2);
        val -= (m16StartIndex+1);
		
		// if 'None' was selected, our val will be == -1, which will return a NULL
		// device from the list, which is what we want anyway, and seems to work
		// here -- probably should check to see if there are any potential problems
		// and handle this more properly
		mThruEngine[1]->SetOutputDevice( (val < 0 ? kAudioDeviceUnknown : mMenuID16[val]) );
		//[self updateThruLatency];

		[mCur16chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur16chDevice = sender;
		
		// get the channel routing from the prefs
		[self readDevicePrefs:NO];
	
		// now set the menu
		[self buildRoutingMenu:NO];
	}
}



- (void)doNothing
{

}

- (void)readGlobalPrefs
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    NSString *strng = [prefs stringForKey:@"2ch Output Device"];
	if (strng) {
        NSMenuItem *item = [mMenu itemWithTitle:strng];
		if (item)
			[self outputDeviceSelected:item];
	}
	
	strng = [prefs stringForKey:@"16ch Output Device"];
	if (strng) {
		// itemWithTitle only returns the first instance, and we need to find the second one, so
		// make calculations based on index #
		int index = [mMenu indexOfItemWithTitle:strng];
		if (index >= 0)
			[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+index-m2StartIndex)]];
	}
	

    switch ([prefs integerForKey:@"2ch Buffer Size"]) {
        case 64:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:0]];
            break;
        case 128:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:1]];
            break;
        case 256:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:2]];
            break;
        case 1024:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:4]];
            break;
        case 2048:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:5]];
            break;
            
        case 512:
        default:
            [self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:3]];
            break;
    }
			
    switch ([prefs integerForKey:@"16ch Buffer Size"]) {
        case 64:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:0]];
            break;
        case 128:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:1]];
            break;
        case 256:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:2]];
            break;
        case 1024:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:4]];
            break;
        case 2048:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:5]];
            break;
            
        case 512:
        default:
            [self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:3]];
            break;
	}
}
		
- (void)writeGlobalPrefs
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    [prefs setObject:[mCur2chDevice title] forKey:@"2ch Output Device"];
    [prefs setObject:[mCur16chDevice title] forKey:@"16ch Output Device"];
    
    UInt32 val = 64 << [m2chBuffer indexOfItem:mCur2chBufferSize];
    [prefs setObject:[NSNumber numberWithInt:val] forKey:@"2ch Buffer Size"];
    
    val = 64 << [m16chBuffer indexOfItem:mCur16chBufferSize];
    [prefs setObject:[NSNumber numberWithInt:val]  forKey:@"16ch Buffer Size"];

    [prefs synchronize];
}

- (CFStringRef)formDevicePrefName:(BOOL)is2ch
{
	if (is2ch) {
		NSString *routingTag = @" [2ch Routing]";
		NSString *deviceName  = [mCur2chDevice title];
		return CFStringCreateWithCString(kCFAllocatorSystemDefault, [[deviceName stringByAppendingString:routingTag] cString], kCFStringEncodingMacRoman);
	} else {
		NSString *routingTag = @" [16ch Routing]";
		NSString *deviceName  = [mCur16chDevice title];
		return CFStringCreateWithCString(kCFAllocatorSystemDefault, [[deviceName stringByAppendingString:routingTag] cString], kCFStringEncodingMacRoman);
	}
}

- (void)readDevicePrefs:(BOOL)is2ch
{
	AudioThruEngine	*thruEng = (is2ch ? mThruEngine[0] : mThruEngine[1]);
	int numChans = (is2ch ? 2 : 64);
	CFStringRef arrayName = [self formDevicePrefName:is2ch];
	CFArrayRef mapArray = (CFArrayRef) CFPreferencesCopyAppValue(arrayName, kCFPreferencesCurrentApplication);
	
	if (mapArray) {
		for (int i = 0; i < numChans; i++) {
			CFNumberRef num = (CFNumberRef)CFArrayGetValueAtIndex(mapArray, i);
			if (num) {
				UInt32 val;
				CFNumberGetValue(num, kCFNumberLongType, &val);	
				thruEng->SetChannelMap(i, val-1);
				//CFRelease(num);
			}
		}
		//CFRelease(mapArray);
	}
	else { // set to default
		for (int i = 0; i < numChans; i++) 
			thruEng->SetChannelMap(i, i);
	}
	
	//CFRelease(arrayName);
	
	// iSchemy's edit
	//
	// cloning is enabled only for 2ch mode
	// sorta makes sense, huh?
	if (is2ch) {
		CFBooleanRef clone = (CFBooleanRef)CFPreferencesCopyAppValue(CFSTR("Clone channels"), kCFPreferencesCurrentApplication);
		// if cloning is enabled in preferences, it will affect also the menu item's state
		NSMenuItem* item = [[m2chMenu submenu] itemWithTitle:@"Clone to all channels"];
			if (clone && item) {
				[self cloningChanged:item cloneChannels:CFBooleanGetValue(clone)];
				CFRelease(clone);
			}
			// but if it is disabled, no state changing is needed
			else {
				thruEng->SetCloneChannels(false);
			}
	}
	//
	// end
}

- (void)writeDevicePrefs:(BOOL)is2ch
{
	AudioThruEngine	*thruEng = (is2ch ? mThruEngine[0] : mThruEngine[1]);
	int numChans = (is2ch ? 2 : 64);
	CFNumberRef map[64];
	
	CFStringRef arrayName = [self formDevicePrefName:is2ch];
	
	for (int i = 0; i < numChans; i++)
	{	
		UInt32 val = thruEng->GetChannelMap(i) + 1;
		map[i] = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberIntType, &val);
	}

	CFArrayRef mapArray = CFArrayCreate(kCFAllocatorSystemDefault, (const void**)&map, numChans, NULL);
	CFPreferencesSetAppValue(arrayName, mapArray, kCFPreferencesCurrentApplication);
	//CFRelease(mapArray);
	
	//for (int i = 0; i < numChans; i++)
	//	CFRelease(map[i]);
	
	//CFRelease(arrayName);
	
	// iSchemy's edit
	//
	// I think that this needs no commentary
	if(is2ch){
		char cloneValue = thruEng->CloneChannels();
		CFNumberRef clone = (CFNumberRef)CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberCharType, &cloneValue);
		CFPreferencesSetAppValue(CFSTR("Clone channels"),
								 clone,
								 kCFPreferencesCurrentApplication);
		CFRelease(clone);
	}
	//
	// end
	
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

-(void)doAudioSetup
{
	[[NSWorkspace sharedWorkspace] launchApplication:@"Audio MIDI Setup"];
}

-(void)doAbout
{
	// orderFrontStandardAboutPanel doesnt work for background apps
	[mAboutController doAbout];
}
- (void)doQuit
{
	[NSApp terminate:nil];
}


/*- (void)updateActualLatency:(NSTimer *)timer
{
	double thruTime = mThruEngine[0]->GetThruTime();
	NSString *msg = [NSString stringWithFormat: @"%.0f", thruTime];
	
	char *errmsg = mThruEngine[0]->GetErrorMessage();
	msg = [NSString stringWithCString: errmsg];
}


- (IBAction)toggleThru:(id)sender
{
	bool enabled = [sender intValue];
	mThruEngine[0]->EnableThru(enabled);
}

- (IBAction)inputLoadChanged:(id)sender
{
	mThruEngine[0]->SetInputLoad( [sender floatValue] / 100. );
	mThruEngine[1]->SetInputLoad( [sender floatValue] / 100. );
}

- (IBAction)outputLoadChanged:(id)sender
{
	mThruEngine[0]->SetOutputLoad( [sender floatValue] / 100. );
	mThruEngine[1]->SetOutputLoad( [sender floatValue] / 100. );
}

- (IBAction)extraLatencyChanged:(id)sender
{
	int val = [sender intValue];
	mThruEngine[0]->SetExtraLatency(val);
	[self updateThruLatency];
}
*/

@end
