#!/usr/bin/env ruby -wU

###################################################################
# build Soundflower, install it, and start it
# installs to /System/Library/Extensions
# do NOT install to /Library/Extensions -- on OS 10.9 this location requires kext to be signed,
#     and a signed kext will NOT load on OS 10.8 or earlier
# requires admin permissions and will ask for your password
###################################################################

require 'open3'
require 'fileutils'
require 'pathname'
require 'rexml/document'
include REXML

# This finds our current directory, to generate an absolute path for the require
libdir = "."
Dir.chdir libdir        # change to libdir so that requires work

if(ARGV.length != 1)
  puts "usage: "
  puts "build.rb <required:configuration (Development|Deployment)>"
  exit 0;
end

configuration = ARGV[0]
out = nil
err = nil

@svn_root = ".."
@source = "#{@svn_root}/Source"
@source_sfb = "#{@svn_root}/SoundflowerBed"


configuration = "Development" if configuration == "dev"
configuration = "Deployment" if configuration == "dep"

`sudo rm -rf #{@svn_root}/Build/InstallerRoot`

###################################################################

puts "  Building the new Soundflower.kext with Xcode"

Dir.chdir("#{@source}")
Open3.popen3("xcodebuild -project Soundflower.xcodeproj -target Soundflower -configuration #{configuration} clean build") do |stdin, stdout, stderr|
  out = stdout.read
  err = stderr.read
end

`sudo chown -R root #{@svn_root}/Build/InstallerRoot/Library/Extensions/Soundflower.kext`
`sudo chgrp -R wheel #{@svn_root}/Build/InstallerRoot/Library/Extensions/Soundflower.kext`

#if /BUILD SUCCEEDED/.match(out)
#  puts "    BUILD SUCCEEDED"
#  puts `ruby #{@svn_root}/Tools/load.rb`
#else
#  puts "    BUILD FAILED"
#end


###################################################################

puts "  Building the new Soundflowerbed.app with Xcode"

Dir.chdir("#{@source_sfb}")
Open3.popen3("xcodebuild -project Soundflowerbed.xcodeproj -target Soundflowerbed -configuration #{configuration} clean build") do |stdin, stdout, stderr|
  out = stdout.read
  err = stderr.read
end


if /BUILD SUCCEEDED/.match(out)
  puts "    BUILD SUCCEEDED"
else
  puts "    BUILD FAILED"
end


###################################################################

puts "  Done."
puts ""
exit 0
