#!/usr/bin/env zsh
source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
unset __HM_SESS_VARS_SOURCED
for i in $(export); do
    var=$(echo $i|sed 's/=.*//')
    val=$(echo $i|sed 's/^[^=]*=//')
    [[ $val != "" ]] && {
        launchctl setenv $var $val
    }
done
