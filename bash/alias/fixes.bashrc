# A series of hacks and fixes for common Mac problems.

alias fix_cinema_display_camera="sudo killall VDCAssistant"

# WIFI
#
# In some cases when connecting to a public wifi network, the DNS resolution
# fails and nothing works. It's also not clear that this is a DNS issue. Killing
# the DNS resolver cleans up any cached network, and this helps resolve the
# router's portal IP address.
#
# For those cases, we need to actually disconnect the wifi and connect agian so
# that the portal page is triggered again, now without cache.
alias fix_dns="sudo killall -HUP mDNSResponder"
alias fix_wifi="fix_dns && sudo ifconfig en0 down && sudo ifconfig en0 up"

