#!/usr/bin/env bash 

# author : josh smith (see also https://www.redhat.com/sysadmin/containerized-matrix-animation?sc_cid=701f2000000txokAAA&utm_source=bambu&utm_medium=social&utm_campaign=abm)

# Set some of the variables below
imagePull=true

#Setting up some colors for helping read the demo output
bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

read -p "${bold} Demo Podman Matrix - hit [ENTER] to proceed  ${reset}"

echo "${blue} Downloading matrix package and extract binary... ${reset}"
wget https://kojipkgs.fedoraproject.org//packages/cmatrix/1.2a/4.fc30/x86_64/cmatrix-1.2a-4.fc30.x86_64.rpm -nc

if $imagePull;
  then
    echo "${blue} Pulling ubi container using podman... (${project}) ${reset}"
    set -x
    sudo podman pull registry.access.redhat.com/ubi8/ubi
fi

set -x
mkdir -p podman-demo-temp 
cp cmatrix* podman-demo-temp
cd podman-demo-temp
rpm2cpio cmatrix-1.2a-4.fc30.x86_64.rpm | cpio -id

set +x ; echo "${blue} Podman: create and  run new container...once it starts exit the shell: ${bold} # exit  ${reset}"; set -x
sudo podman run --name matrix -it registry.access.redhat.com/ubi8/ubi /usr/bin/bash

set +x; read -p "${blue} Ready to copy the Matrix into the container? [ENTER]   ${reset}"; set -x
sudo podman cp usr/bin/cmatrix matrix:/usr/bin/matrix

set +x; echo "${blue} Take the Blue Pill (hit [ENTER] a few times if nothing happens)   ${reset}"
echo "${cyan}   Start the animation : # matrix "
echo "   Show usage options : # matrix -h "
echo "   Stop the animation : # q \n " 
echo "   Leave the container : # exit ${reset}"

set -x
sudo podman start matrix
sudo podman attach matrix

cd .. 
pwd
ls -aL
rm -r podman-demo-temp
sudo podman  stop  matrix ; sudo podman rm matrix
















