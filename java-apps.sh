#!/usr/bin/env bash 

# author : josh smith 
# Set some of the variables below

defaultuser=user1
if [ -z "$1" ]
  then
    project=${defaultuser}
else
    project="$1"
fi

#Setting up some colors for helping read the demo output
bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
reset=$(tput sgr0)

#echo -e "Using ${green}GREEN${reset} to start lab "
#echo -e "Using ${yellow}YELLOW${reset} for nothing "
#echo -e "Using ${blue}BLUE${reset} to list major steps"
#echo -e "Using ${cyan}CYAN${reset} to add notes "
#echo -e "Building an image called ${demoimg}"
read -p "${green}Java Apps on OpenShift - press enter to proceed ${reset}"

read -p "${blue} 0. Verify OpenShift Login ${reset}"
oc whoami > /dev/null && echo "${cyan}*** IN BUSINESS AS: $(oc whoami) ***${reset}"

#read -p "${blue} 1. Create a new project (${project}) ${reset}"
#oc new-project ${project} --display-name="Blue/Green Deployment"
oc project ${project}

read -p "${blue} 1. Deploy parksmap application  ${reset}"
#to cleanup:
#oc delete all -l app=parksmap
oc new-app --name=parksmap docker.io/openshiftroadshow/parksmap:1.2.0 --labels="app=workshop,component=parksmap,role=frontend"

read -p "${blue} 2. examine pods ${reset}"
oc get pods

read -p "${blue} 3. get yaml of pod  ${reset}"
oc get pod -l app=workshop -o yaml


read -p "${blue} 4. show services  ${reset}"
oc get services

read -p "${blue} 5. more info about parksmap service ${reset}"
oc get service parksmap -o yaml


read -p "${blue} 6. describe the service ${reset}"
oc describe service parksmap
echo

read -p "${green}Part 2: Scaling and Self-healing ${reset}"
read -p "${blue} review deployment config  ${reset}"
oc get dc
read -p "${blue} review replication controller  ${reset}"
oc get rc
read -p "${blue} scale to 2 replicas  ${reset}"
oc scale --replicas=2 dc/parksmap
read -p "${blue} review RC again  ${reset}"
oc get rc
read -p "${blue} two pods!  ${reset}"
oc get pods
read -p "${blue} the service has two pods it refers to:  ${reset}"
oc describe svc parksmap
read -p "${blue} check out the endpoints- ${reset}"
oc get endpoints parksmap
read -p "${blue} kill pods, see what happens  ${reset}"
oc delete pod -l app=workshop && oc get pods
read -p "${blue} scale down-  ${reset}"
oc scale --replicas=1 dc/parksmap

read -p "${green}Part 3: Routes ${reset}"
read -p "${blue} create route  ${reset}"
oc expose service parksmap
read -p "${blue} review route  ${reset}"
oc get route
echo "${blue} Route URL: ${yellow} http://$(oc get route parksmap --template='{{ .spec.host }}') ${reset}"
read -p "${blue}   Browse to the application to see the map ${reset}"

read -p "${green}Part 4: Role Based Access Control ${reset}"
oc project ${project}
read -p "${blue} grant view role to service accounts by default  ${reset}"
oc policy add-role-to-user view -z default

read -p "${blue} trigger a redeploy  ${reset}"
oc rollout latest dc/parksmap

read -p "${blue} grant view access to your user-neighbors  ${reset}"
oc policy add-role-to-user view user2

read -p "${green}Part 5: Deploying Java Applications ${reset}"
oc project ${project}
read -p "${blue} make a java app  ${reset}"
#oc new-app redhat-openjdk18-openshift:1.4 https://github.com/openshift-roadshow/nationalparks --labels="app=workshop,component=nationalparks,role=backend"
# oc new-app redhat-openjdk18-openshift:1.4 https://github.com/jboss-openshift/openshift-quickstarts --context-dir=undertow-servlet
# -e MAVEN_MIRROR_URL
oc new-app redhat-openjdk18-openshift:1.4 http://gogs-lab-infra.apps.omf-4b7d.open.redhat.com/user1/nationalparks.git --labels="app=workshop,component=nationalparks,role=backend" -e MAVEN_MIRROR_URL=http://nexus.lab-infra.svc.cluster.local:8081/repository/maven-all-public

oc expose service nationalparks

read -p "${yellow} CLEANUP! Press [enter] to cleanup, [ctrl+c] to leave the project ${reset}"
oc delete all -l app=workshop
#oc delete all -l app=nationalparks

#oc delete project ${project}












