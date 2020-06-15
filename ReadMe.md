
# JUST LOOKING FOR THE (SIGNED) SOUNDFLOWER INSTALLER?
https://github.com/mattingalls/Soundflower/releases/tag/2.0b2
is the latest version




# THE MOST RELIABLE WAY TO UNINSTALL

**OPEN THE TERMINAL APP** (found in /Applications/Utilities/)

then type these 3 lines: 
(entering your password if asked)
```
sudo rm -r /System/Library/Extensions/Soundflower.kext
sudo rm -r /Library/Extensions/Soundflower.kext
sudo kextcache --clear-staging
```
**RESTART** your computer






# ORIGINAL INSTRUCTIONS TO BUILD SOUNDFLOWER YOURSELF


Soundflower Source ReadMe

Originally by ma++ ingalls for Cycling'74
Revised by Tim Place, 16 October 2008, for version 1.4 



QUICK START

To build Soundflower, open a terminal window and cd to the Soundflower folder.  Then follow these steps:

1.	Change directories into the Tools directory:
	cd Tools
	
2.	Build Soundflower:
	./build.rb

	The build.rb will provide info about its required arg, which you will need to supply 
	(Development or Deployment -- or the shorthand for them: dev or dep).
	It will also prompt you for your password so that it can set permissions correctly 
	and load the kext automatically when the build is complete.

3.	If you wish, build an installer for Soundflower:
	./installer.rb



PROJECT CONFIGURATION

Soundflower.xcodeproj is an Xcode 3.1 compatible project.  You can download Xcode 3.1 as a part of Apple's developer tools from http://developer.apple.com/ .

There are two Build Configurations in the project: the Development build configuration builds Soundflower for the architecture of the machine you are using suitable for debugging. The Deployment configuration builds a Universal Binary version suitable for distribution.  Both configurations link against the Mac OS 10.4 SDK.



PERMISSIONS

Files in a kernel extension (kext) bundle have to be set as follows:
	owner: root - read/write
	group: wheel - read only
	others: read only

Unfortunately there doesn't seem to be a simple way to do this in Xcode.  Xcode cannot execute scripts with sudo permissions, and it cannot invoke any user interaction (e.g. and applescript dialog) to finish a build.  

In the Soundflower 'Tools' folder there is a Ruby script called 'load.rb' which will copy the built kext into the install location using sudo.  This sets the owner and group correctly.  When you run the 'build.rb' script it builds the project with Xcode and then runs the 'load.rb' script automatically.



VERSION NUMBER

The master version number is updated in the Xcode project's target settings.  
Specifically, you edit the MODULE_VERSION entry to set it.  All other places where the version number is needed (including in the installer), it is accessed from this master location.


LICENSE

Soundflower is licensed under the terms of the MIT license.  
For details please refer to the accompanying 'License.txt' file distributed with Soundflower.


