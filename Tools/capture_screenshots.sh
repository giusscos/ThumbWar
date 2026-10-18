#!/bin/zsh
# Captures raw App Store screenshots from a booted simulator running a DEBUG build.
#
#   Tools/capture_screenshots.sh <device-udid> <prefix> [display-width]
#
# display-width picks one screen on multi-display devices, e.g. 2007 for the
# iPhone Duo inner display (unfold it in Device Hub first) or 1398 for the outer one.
# A screen held sideways (the Duo inner display in Device Hub) is saved in landscape.
# Gameplay shots are taken as bursts; pick the best frame of each by hand.
# Output: Art/Screenshots/raw/<prefix>-<screen>[-<n>].png

set -e
device=$1; prefix=$2; width=$3
out=${0:A:h:h}/Art/Screenshots/raw
io=(--mask=ignored)
if [[ -n $width ]]; then
  display=$(xcrun simctl io $device enumerate | grep -B6 "Default width: $width" | awk '/UUID/{print $2}' | tail -1)
  [[ -z $display ]] && { echo "no $width px wide display on $device" >&2; exit 1; }
  io+=(--display=$display)
fi

# shot <name> <wait> <frames> [launch args...]
shot() {
  local name=$1 wait=$2 frames=$3; shift 3
  xcrun simctl launch --terminate-running-process $device com.giusscos.ThumbestWar -debugOrientation portrait "$@" >/dev/null
  sleep $wait
  if (( frames == 1 )); then
    xcrun simctl io $device screenshot $io $out/$prefix-$name.png >/dev/null
  else
    for i in {1..$frames}; do xcrun simctl io $device screenshot $io $out/$prefix-$name-$i.png >/dev/null; sleep 0.6; done
  fi
}

shot 1-menu 14 1
shot 2-pin 3.5 7 -debugChallenge 10
shot 3-two-players 3.5 5 -autostart2P
shot 4-tour 6 1 -openTour
shot 5-locker 7 1 -openLocker
shot 6-trophies 6 1 -openTrophies
echo "saved to $out"
