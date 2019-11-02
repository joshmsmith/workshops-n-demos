#!/usr/bin/env bash 

# author : josh smith (based on ipbabble's other demos) 
# Set some of the variables below

demoimg=mymultidemo
quayuser=myquauuser
myname=MyName
distrorelease=30
pkgmgr=dnf   # switch to yum if using yum 

#Setting up some colors for helping read the demo output
bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

echo -e "Using ${green}GREEN${reset} to introduce Buildah steps"
echo -e "Using ${yellow}YELLOW${reset} to introduce code"
echo -e "Using ${blue}BLUE${reset} to introduce Podman steps"
echo -e "Using ${cyan}CYAN${reset} to introduce bash commands"
echo -e "Building an image called ${demoimg}"
read -p "${green}Start of the script${reset}"

read -p "${green} add permissions if using OpenShift ${reset}"
oc adm policy add-scc-to-user privileged -n kube-system -z kubevirt-privileged
oc adm policy add-scc-to-user privileged -n kube-system -z kubevirt-controller
oc adm policy add-scc-to-user privileged -n kube-system -z kubevirt-apiserver
read -p "${green} apply the KubeVirt configuration, adjust RELEASE for the current version ${reset}"
RELEASE=v0.11.0
#kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt.yaml
oc apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt.yaml

read -p "${green} create a vm ${reset}"
oc create -f https://raw.githubusercontent.com/kubevirt/demo/master/manifests/vm.yaml

