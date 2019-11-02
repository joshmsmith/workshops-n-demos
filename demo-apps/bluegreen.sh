#!/usr/bin/env bash 

# author : josh smith (based on ipbabble's other demos) 
# Set some of the variables below

#demoimg=mymultidemo
#quayuser=myquauuser
#myname=MyName
#distrorelease=30
#pkgmgr=dnf   # switch to yum if using yum 
defaultproject=bluegreen
if [ -z "$1" ]
  then
    project=${defaultproject}
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
read -p "${green}Demo Blue/Green deploys - press enter to proceed ${reset}"

read -p "${blue} 0. Verify OpenShift Login ${reset}"
oc whoami > /dev/null && echo "${cyan}*** IN BUSINESS AS: $(oc whoami) ***${reset}"

read -p "${blue} 1. Create a new project (${project}) ${reset}"
oc new-project ${project} --display-name="Blue/Green Deployment"

read -p "${blue} 2. Deploy first copy of the example application  ${reset}"
oc new-app --name=example-blue openshift/deployment-example:v1

read -p "${blue} 3. Create route to first copy of the example application  ${reset}"
oc expose svc/example-blue --name=example

echo "${blue} Route URL: ${yellow} http://$(oc get route example --template='{{ .spec.host }}') ${reset}"
read -p "${blue}   Browse to the application to see the 'v1' image ${reset}"

read -p "${blue} 4. Deploy second copy of the example application  ${reset}"
oc new-app --name=example-green openshift/deployment-example:v2

read -p "${blue} 5. Edit the route and change service to example-blue ${reset}"
read -p "${blue}   (Change spec.to.name to example-green and save and exit the editor.)  ${reset}"

#oc delete route example && oc expose svc/example-green --name=example

oc edit route/example

read -p "${blue} 6. In your browser, refresh the page until you see the 'v2' image. ${reset}"
echo 

read -p "${green}Part 2: Pipeline Blue-Green Deployment - press enter to begin ${reset}"

read -p "${blue} 1. Create a Jenkins instance ${reset}"
oc new-app jenkins-ephemeral --param MEMORY_LIMIT=1Gi

read -p "${blue} 2. Turn off all triggers from our deployment configurations ${reset}"
oc set triggers dc/example-green --remove-all
oc set triggers dc/example-blue --remove-all

read -p "${blue} 3. Create the Pipeline Build Configuration ${reset}"
oc create -f \
https://raw.githubusercontent.com/wkulhanek/openshift-bluegreen/master/example-pipeline.yaml

read -p "${blue} 4. In the Web Console navigate to your project. ${reset}"
read -p "${blue} 5. Select Builds/Pipelines in the navigator on the left. " 
read -p "   ● You will see your Pipeline configuration. It points to a Jenkinsfile in Github. "
read -p "   ● Click Start Pipeline to kick off a new build. "
read -p "   ● The build will progress until it is time to approve switching over to the new version of the application. "
read -p "   ● At this point you can verify that even though we deployed a new version of the application in the other deployment configuration our route still displays the blue v1 text."
read -p "   ● Back in your pipeline click the Input Required link. You will be directed to the Jenkins Login Page. Log in with your OpenShift credentials. "
read -p "   ● Click Proceed to continue the deployment of the new application version. "
read -p "   ● Refresh the route to see the updated application. The first time you will see a light green box with text ‘v2’. ${reset}"

read -p "${yellow} CLEANUP! Press [enter] to cleanup, [ctrl+c] to leave the project ${reset}"
oc delete project ${project}












