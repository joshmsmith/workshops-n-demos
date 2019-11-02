#!/usr/bin/env bash 

# author : josh smith 
# Set some of the variables below
#Setting up some colors for helping read the demo output
bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
reset=$(tput sgr0)


defaultURL=http://console-openshift-console.apps.cluster-eville-fe3d.eville-fe3d.example.opentlc.com/
defaultCOUNT=999
if [ -z "$1" ]
  then
    URL=${defaultURL}
else
    URL="$1"
fi

if [ -z "$2" ]
  then
    COUNT=${defaultCOUNT}
else
    COUNT=${2}
fi


for ((i=1;i<=${COUNT};i++)); do   
   #curl -v -k --header "Connection: keep-alive" "${URL}";
   echo -e "${blue}pinging (${i}/${COUNT}) ${URL} ${reset}...";
   curl -k -IL ${URL};
   sleep 5m; 
done

