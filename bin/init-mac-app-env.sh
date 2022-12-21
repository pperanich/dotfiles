#!/usr/bin/env zsh
source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
for i in $(export); do
    var=$(echo $i|sed 's/=.*//')
    val=$(echo $i|sed 's/^[^=]*=//')
    [[ $val != "" ]] && {
        launchctl setenv $var $val
    }
done
