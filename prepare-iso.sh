#!/bin/bash

#
# This script will create a bootable ISO image from the installer application for El Capitan (10.11) or the new Sierra (10.12) macOS.
# Restructured a bit, and adapted the 10.11 script from this URL:
# https://forums.virtualbox.org/viewtopic.php?f=22&t=77068&p=358865&hilit=elCapitan+iso#p358865
#

#
# createISO
#
# This function creates the ISO image for the user.
# Inputs:  $1 = The name of the installer - located in your Applications folder or in your local folder/PATH.
#          $2 = The Name of the ISO you want created.
#
function createISO()
{
  if [ $# -eq 2 ] ; then
    local installerAppName=${1}
    local isoName=${2}
    local error=0

    # echo Debug: installerAppName = ${installerAppName} , isoName = ${isoName}

    # ==============================================================
    # 10.11 & 10.12: How to make an ISO from the Install app
    # ==============================================================
    echo
    echo Mount the installer image
    echo -----------------------------------------------------------

    if [ -e "${installerAppName}" ] ; then
      echo $ hdiutil attach "${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      hdiutil attach "${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      error=$?
    elif [ -e /Applications/"${installerAppName}" ] ; then
      echo $ hdiutil attach /Applications/"${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      hdiutil attach /Applications/"${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      error=$?
    else
      echo Installer Not found!
      error=1
    fi

    if [ ${error} -ne 0 ] ; then
      echo "Failed to mount the InstallESD.dmg from the instaler at ${installerAppName}.  Exiting. (${error})"
      return ${error}
    fi

    echo
    echo Create ${isoName} blank ISO image with a Single Partition - Apple Partition Map
    echo --------------------------------------------------------------------------
    echo $ hdiutil create -o /tmp/${isoName} -size 8g -layout SPUD -fs HFS+J -type SPARSE
    hdiutil create -o /tmp/${isoName} -size 8g -layout SPUD -fs HFS+J -type SPARSE

    echo
    echo Mount the sparse bundle for package addition
    echo --------------------------------------------------------------------------
    echo $ hdiutil attach /tmp/${isoName}.sparseimage -noverify -nobrowse -mountpoint /Volumes/install_build
    hdiutil attach /tmp/${isoName}.sparseimage -noverify -nobrowse -mountpoint /Volumes/install_build

    echo
    echo Restore the Base System into the ${isoName} ISO image
    echo --------------------------------------------------------------------------
    echo $ asr restore -source /Volumes/install_app/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase
    asr restore -source /Volumes/install_app/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase

    echo
    echo Remove Package link and replace with actual files
    echo --------------------------------------------------------------------------
    echo $ rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages
    rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages
    echo $ cp -Rp /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
    cp -Rp /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/

    echo
    echo Copy macOS ${isoName} installer dependencies
    echo --------------------------------------------------------------------------
    echo $ cp -Rp /Volumes/install_app/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
    cp -Rp /Volumes/install_app/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
    echo $ cp -Rp /Volumes/install_app/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg
    cp -Rp /Volumes/install_app/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg

    echo
    echo Unmount the installer image
    echo --------------------------------------------------------------------------
    echo $ hdiutil detach /Volumes/install_app
    hdiutil detach /Volumes/install_app

    echo
    echo Unmount the sparse bundle
    echo --------------------------------------------------------------------------
    echo $ hdiutil detach /Volumes/OS\ X\ Base\ System/
    hdiutil detach /Volumes/OS\ X\ Base\ System/

    echo
    echo Resize the partition in the sparse bundle to remove any free space
    echo --------------------------------------------------------------------------
    echo $ hdiutil resize -size `hdiutil resize -limits /tmp/${isoName}.sparseimage | tail -n 1 | awk '{ print $1 }'`b /tmp/${isoName}.sparseimage
    hdiutil resize -size `hdiutil resize -limits /tmp/${isoName}.sparseimage | tail -n 1 | awk '{ print $1 }'`b /tmp/${isoName}.sparseimage

    echo
    echo Convert the sparse bundle to ISO/CD master
    echo --------------------------------------------------------------------------
    echo $ hdiutil convert /tmp/${isoName}.sparseimage -format UDTO -o /tmp/${isoName}
    hdiutil convert /tmp/${isoName}.sparseimage -format UDTO -o /tmp/${isoName}

    echo
    echo Remove the sparse bundle
    echo --------------------------------------------------------------------------
    echo $ rm /tmp/${isoName}.sparseimage
    rm /tmp/${isoName}.sparseimage

    echo
    echo Rename the ISO and move it to the desktop
    echo --------------------------------------------------------------------------
    echo $ mv /tmp/${isoName}.cdr ~/Desktop/${isoName}.iso
    mv /tmp/${isoName}.cdr ~/Desktop/${isoName}.iso
  fi
}

#
# installerExists
#
# Returns 0 if the installer was found either locally or in the /Applications directory.  1 if not.
#
function installerExists()
{
  local installerAppName=$1
  local result=1
  if [ -e "${installerAppName}" ] ; then
    result=0
  elif [ -e /Applications/"${installerAppName}" ] ; then
    result=0
  fi
  return ${result}
}

#
# Main script code
#
# Eject installer disk in case it was opened after download from App Store
hdiutil info | grep /dev/disk | grep partition | cut -f 1 | xargs hdiutil detach -force

# See if we can find either the ElCapitan or the Sierra installer.
# If successful, then create the iso file from the installer.

installerExists "Install macOS Sierra.app"
result=$?
if [ ${result} -eq 0 ] ; then
  createISO "Install macOS Sierra.app" "Sierra"
else
  installerExists "Install OS X El Capitan.app"
  result=$?
  if [ ${result} -eq 0 ] ; then
    createISO "Install OS X El Capitan.app" "ElCapitan"
  else
    installerExists "Install OS X Yosemite.app"
    result=$?
    if [ ${result} -eq 0 ] ; then
      createISO "Install OS X Yosemite.app" "Yosemite"
    else
      echo "Could not find installer for Yosemite (10.10), El Capitan (10.11) or Sierra (10.12)."
    fi
  fi
fi
