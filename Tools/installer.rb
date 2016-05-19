#!/usr/bin/env ruby -wU

###################################################################
# make an installer for Soundflower
# requires: you must have already performed a Deployment build
###################################################################

require 'open3'
require 'fileutils'
require 'pathname'
require 'rexml/document'
include REXML

# This finds our current directory, to generate an absolute path for the require
libdir = "."
Dir.chdir libdir        # change to libdir so that requires work

@svn_root = ".."
Dir.chdir @svn_root
@svn_root = Dir.pwd


###################################################################
# sub routines
###################################################################

def create_logs
  @build_log = File.new("#{@svn_root}/Installer/_installer.log", "w")
  @build_log.write("SOUNDFLOWER INSTALLER LOG: #{`date`}\n\n")
  @build_log.flush
  @error_log = File.new("#{@svn_root}/Installer/_error.log", "w")
  @error_log.write("SOUNDFLOWER INSTALLER ERROR LOG: #{`date`}\n\n")
  @error_log.flush
  trap("SIGINT") { die }
end
  
def die
  close_logs
  exit 0
end

def close_logs
  @build_log.close
  @error_log.close
end

def log_build(str)
  @build_log.write(str)
  @build_log.write("\n\n")
  @build_log.flush
end

def log_error(str)
  @error_log.write(str)
  @error_log.write("\n\n")
  @error_log.flush
end


# This defines a wrapper that we use to call shell commands
def cmd(commandString)
  out = ""
  err = ""
  
  Open3.popen3(commandString) do |stdin, stdout, stderr|
    out = stdout.read
    err = stderr.read
  end
  log_error(out)
  log_error(err)
end


def getversion()
  theVersion = "0.0.0"

  system_dir = File.directory?("#{@installer_root}/System/Library/Extensions/Soundflower.kext/") ? "/System" : ""
  f = File.open("#{@installer_root}#{system_dir}/Library/Extensions/Soundflower.kext/Contents/Info.plist", "r")
  str = f.read
  theVersion = str.match(/<key>CFBundleShortVersionString<\/key>\n.*<string>(.*)<\/string>/).captures[0]
  f.close
  
  puts"  version: #{theVersion}"
  return theVersion;
end

###################################################################
# here is where we actually build the installer
###################################################################

create_logs()

@installer_root = "#{@svn_root}/Build/InstallerRoot"
@version = getversion()
@build_folder = "#{@svn_root}/Build/Soundflower-#{@version}"

puts "  Creating installer directory structure..."
cmd("rm -rfv \"#{@build_folder}\"")                       # remove an old temp dir if it exists
cmd("mkdir -pv \"#{@build_folder}\"")                     # now make a clean one, and build dir structure in it

cmd("cp \"#{@svn_root}/Tools/Uninstall Soundflower.scpt\"           \"#{@installer_root}\"/Applications/Soundflower")
cmd("cp \"#{@svn_root}/License.txt\"                                \"#{@installer_root}\"/Applications/Soundflower")
cmd("cp \"#{@svn_root}/Installer/ReadMe.rtf\"                       \"#{@installer_root}\"/Applications/Soundflower")
cmd("cp \"#{@svn_root}/SoundflowerBed/Soundflowerbed README.rtf\"   \"#{@installer_root}\"/Applications/Soundflower")

puts "  Building Package -- this could take a while..."
puts `pkgbuild --root \"#{@installer_root}\" --identifier com.cycling74.soundflower --version #{@version} --install-location "/" \"#{@build_folder}/Soundflower.pkg\" --ownership preserve  --scripts \"#{@svn_root}/Installer/scripts\" --sign \"Developer ID Installer: Cycling '74\"`

puts "  Copying readme, license, etc...."
cmd("cp \"#{@svn_root}/License.txt\" \"#{@build_folder}\"")
cmd("cp \"#{@svn_root}/Installer/ReadMe.rtf\" \"#{@build_folder}\"")
cmd("cp \"#{@svn_root}/Tools/Uninstall Soundflower.scpt\" \"#{@build_folder}\"")

puts "  Creating Disk Image..."
cmd("rm -rfv \"#{@svn_root}/Installer/Soundflower-#{@version}.dmg\"")
cmd("hdiutil create -srcfolder \"#{@build_folder}\" \"#{@svn_root}/Build/Soundflower-#{@version}.dmg\"")

puts "  All done!"

close_logs
puts ""
exit 0
