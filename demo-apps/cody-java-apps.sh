
#!/bin/bash
# usage: -u user1 -i 4b7d -p openshift -n user1

# create some util functions

isPrereqMet(){
  if [[ ($END_AFTER_STEP == "" || $END_AFTER_STEP -ge 14) && $(type $1 2> /dev/null ) == '' ]];then 
    if [[ $3 != "false" ]];then
      echo "$1 not found, this is a prereq for step $2"
      exit 1
    else
      echo "$1 not found, step $2 will be skipped"
    fi
  fi
}

sq(){
    echo "'$@'"
}
uid(){
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 |tr '[A-Z]' '[a-z]'
}
createFromJson(){
    echo $@ | oc create -f -
}
endOfStep (){
    echo 
    echo "------------- END OF STEP $1 ------------- "
    echo
    if [[ $END_AFTER_STEP == "" ]];then
      return
    fi
    if [[ $END_AFTER_STEP -le $1 ]];then 
      exit 0
    fi
}
addAndCommit(){
    git add -A 
    git commit -m "$1"
    if [[ $2 == "true" ]];then 
      git push
    fi 
}
waitForSecret(){
  while true; do 
    if [[ $(oc get secret $1 2>/dev/null) != '' ]];then 
      break
    fi 
    echo "Waiting for secret $1"
    sleep 10
  done 
}
waitForBuilds(){
   sleep 10
   while [[ $(oc get builds --no-headers|grep -E "^$1-.*(Running|New)") != '' ]];do 
     echo "Waiting for $1 build to finish"
     sleep 10
   done 
}
waitForServiceInstance(){
   while [[ $(oc get serviceinstance --no-headers|grep -E "^$1-.*Ready") == '' ]];do 
     echo "Waiting for $1 service instance to be ready"
     sleep 10
   done 
}
waitForPods(){
  sleep 10
  while true;do 
    echo "Waiting for $1 pods to start"
    pods=$(oc get pods|grep -E "^$1-.*(Running|Terminating)"|grep -Ev '\-(deploy|build)' | awk '{print $2}') 
    if [[ $pods == "" ]];then 
      pods="0/1"
    fi
    valid="true"
    for p in $(echo "$pods");do 
        started=$(echo $p|awk -F '/' '{print $1}')
        desired=$(echo $p|awk -F '/' '{print $2}')
        if [[ $started != $desired ]];then
            valid=false 
            break;
        fi
    done
    if [[ $valid == "true" ]];then 
     break;
    fi
  done
}

# init vars
while getopts ":u:h:e:i:p:u:n:" opt; do
  case ${opt} in
    e )
      if [ -n "$OPTARG" ] && [ "$OPTARG" -eq "$OPTARG" ] 2>/dev/null; then
        END_AFTER_STEP=$OPTARG
      else
        echo "Invalid option: -$opt must be a number"
        exit 1
      fi
      ;;
    i )
      CLUSTER_UID=$OPTARG
      ;;
    p )
      OC_PASSWORD=$OPTARG
      ;;
    u )
      OC_USERNAME=$OPTARG
      ;;
    h )
      OC_HOST=$OPTARG
      ;;
    n )
      OC_PROJECT=$OPTARG
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done

isPrereqMet oc 1
isPrereqMet git 14
isPrereqMet curl 15
isPrereqMet mvn 18 false 



if [[ $OC_USERNAME == "" ]];then
  echo -n "Enter username to use for the lab:"
  read OC_USERNAME 
fi

if [[ $OC_PASSWORD == "" ]];then
  OC_PASSWORD=openshift
fi

if [[ $OC_PROJECT == "" ]];then
   OC_PROJECT=$OC_USERNAME
fi

if [[ $OC_HOST == "" && $CLUSTER_UID == ""  ]];then
  echo -n "Enter cluster url, eg 'https://master.omf-4b7d.open.redhat.com' :"
  read OC_HOST
elif [[ $OC_HOST == "" ]];then
  OC_HOST="https://master.omf-$CLUSTER_UID.open.redhat.com" 
  echo "Using OC_HOST $OC_HOST"
else 
  CLUSTER_UID=$(echo $OC_HOST|awk -F '-' '{print $2}' |awk -F '.' '{print $1}')
  echo "Using CLUSTER_UID $CLUSTER_UID"
fi



PARKSMAP_IMAGE=docker.io/openshiftroadshow/parksmap:1.2.0 
PARKSMAP_LABELS="app=workshop component=parksmap role=frontend"
NATIONALPARK_LABELS="app=workshop component=nationalparks role=backend"
GOGS_HOST="gogs-lab-infra.apps.omf-$CLUSTER_UID.open.redhat.com"
NATIONALPARK_GIT_HOST="$GOGS_HOST/$OC_USERNAME/nationalparks.git"
NATIONALPARK_GIT_URL="http://$NATIONALPARK_GIT_HOST"
MAVEN_MIRROR_URL=http://nexus.lab-infra.svc.cluster.local:8081/repository/maven-all-public
MONGO_LABELS="app=workshop component=nationalparks role=database"
MLBPARKS_GIT_URL="https://github.com/openshift-roadshow/mlbparks.git"


# login and ensure project exists
echo "Logging into openshift"
oc login ${OC_HOST} --insecure-skip-tls-verify=true --password=${OC_PASSWORD} --username=${OC_USERNAME}
if [[ $? -ne 0 ]];then
  exit 1
fi

projects=$(oc get project ${OC_PROJECT} 2>/dev/null| sed '1,1d')
currentProject=$(oc project -q 2>/dev/null)
if [[ $currentProject != $OC_PROJECT ]];then
    if [[ $projects == '' ]];then
      oc new-project $OC_PROJECT
      if [[ $? -ne 0 ]];then
        exit 1
      fi
    else 
      echo "Project $OC_PROJECT already exists"
    fi
    oc project $OC_PROJECT
fi


# cleanup previous work
echo "Ensuring all previous components are deleted"
oc delete all -l app=workshop

for x in $(oc get servicebindings --no-headers | awk '{print $1}');do
  oc delete servicebindings $x;
done

for x in $(oc get serviceinstances  --no-headers| awk '{print $1}' );do
 oc delete serviceinstance $x;
done

for x in $(oc get all |grep jenkins | awk '{print $1}'); do
  oc delete $x 
done 

oc delete bc/nationalparks-build 
oc delete cm/mlbparks

echo "Removing any previous webhooks for nationalparks"
for x in $(curl --silent --user $OC_USERNAME:$OC_PASSWORD -k "http://$GOGS_HOST/api/v1/repos/$OC_USERNAME/nationalparks/hooks" | tr ',' '\n'|grep id |awk -F ':' '{print $2}');do
  curl  --user $OC_USERNAME:$OC_PASSWORD -X DELETE http://$GOGS_HOST/api/v1/repos/$OC_USERNAME/nationalparks/hooks/$x
done

endOfStep 3


echo "Deploying parksmap image"
oc new-app $PARKSMAP_IMAGE --name=parksmap -l $PARKSMAP_LABELS
endOfStep 5


echo "Creating route parksmap"
oc expose service parksmap
waitForPods parksmap
endOfStep 7


echo "Ensuring default service account has view access"
oc policy add-role-to-user view -z default 
oc rollout latest parksmap
endOfStep 9

echo "Creating build for nationalparks"
oc new-app openshift/java:8~$NATIONALPARK_GIT_URL --name=nationalparks  -l $NATIONALPARK_LABELS --build-env MAVEN_MIRROR_URL=$MAVEN_MIRROR_URL
oc logs -f bc/nationalparks
oc expose service nationalparks
waitForPods nationalparks
endOfStep 11


# create service instance for mongodb
# we have to create parameters secret first, import json referencing the parms secret, get uid and update parms secret to have service instance as owner
UUID=$(uid)
UUID2=$(uid)
SECRET_NAME="mongodb-ephermeral-parameters$UUID"
INSTANCE_NAME="mongodb-ephemeral-$UUID"
SERVICE_BINDING_NAME="mongodb-ephemeral-$UUID-$UUID2"
# create parms
oc create secret generic "$SECRET_NAME" '--from-literal=parameters={"DATABASE_SERVICE_NAME":"mongodb-nationalparks","MEMORY_LIMIT":"512Mi","MONGODB_ADMIN_PASSWORD":"mongodb","MONGODB_DATABASE":"mongodb","MONGODB_PASSWORD":"mongodb","MONGODB_USER":"mongodb","MONGODB_VERSION":"3.2","NAMESPACE":"openshift"}'
# create instance
createFromJson '{
  "apiVersion": "servicecatalog.k8s.io/v1beta1",
  "kind": "ServiceInstance",
  "metadata": {
    "finalizers": [
      "kubernetes-incubator/service-catalog"
    ],
    "generateName": "mongodb-ephemeral-",
    "name": "'$INSTANCE_NAME'",
    "namespace": "'$OC_PROJECT'"
  },
  "spec": {
    "clusterServiceClassExternalName": "mongodb-ephemeral",
    "clusterServicePlanExternalName": "default",
    "parametersFrom": [
      {
        "secretKeyRef": {
          "key": "parameters",
          "name": "'$SECRET_NAME'"
        }
      }
    ],
    "updateRequests": 0,
    "userInfo": {
      "extra": {
        "scopes.authorization.openshift.io": [
          "user:full"
        ]
      },
      "groups": [
        "system:authenticated:oauth",
        "system:authenticated"
      ],
      "username": "'$OC_PROJECT'"
    }
  }
}'
# get uid of created instance
INSTANCE_UID=$(oc get serviceinstance $INSTANCE_NAME --template '{{.metadata.uid}}')
# update secret to have instance as owner
oc patch secret $SECRET_NAME -p '{"metadata":{"ownerReferences":[{"apiVersion":"servicecatalog.k8s.io/v1beta1","blockOwnerDeletion":false,"controller":false,"kind":"ServiceInstance","name":"'$INSTANCE_NAME'","uid":"'$INSTANCE_UID'"}]}}'

# create binding to instance
CREDS_NAME="$INSTANCE_NAME-credentials-$UUID2"
createFromJson '{
  "apiVersion": "servicecatalog.k8s.io/v1beta1",
  "kind": "ServiceBinding",
  "metadata": {
    "finalizers": [
      "kubernetes-incubator/service-catalog"
    ],
    "generateName": "'$INSTANCE_NAME'-",
    "name": "'$SERVICE_BINDING_NAME'"
  },
  "spec": {
    "instanceRef": {
      "name": "'$INSTANCE_NAME'"
    },
    "secretName": "'$CREDS_NAME'",
    "userInfo":  {
      "extra": {
        "scopes.authorization.openshift.io": [
          "user:full"
        ]
      },
      "groups": [
        "system:authenticated:oauth",
        "system:authenticated"
      ],
      "uid": "",
      "username": "'$OC_PROJECT'"
    }
  },
  "status": {
    "asyncOpInProgress": false,
    "conditions": [
      {
        "lastTransitionTime": "2019-10-30T20:15:15Z",
        "message": "Injected bind result",
        "reason": "InjectedBindResult",
        "status": "True",
        "type": "Ready"
      }
    ],
    "externalProperties": {
      "userInfo": {
        "extra": {
          "scopes.authorization.openshift.io": [
            "user:full"
          ]
        },
        "groups": [
          "system:authenticated:oauth",
          "system:authenticated"
        ],
        "uid": "",
        "username": "'$OC_PROJECT'"
      }
    },
    "orphanMitigationInProgress": false,
    "reconciledGeneration": 1,
    "unbindStatus": "Required"
  }
}'
# wait for mongodb to start
waitForPods mongodb-nationalparks
# add labels 
oc label dc/mongodb-nationalparks svc/mongodb-nationalparks $MONGO_LABELS --overwrite
# wait for created secret to exist
waitForSecret "$CREDS_NAME"

# map secret to nationalparks deployment
oc set env dc/nationalparks --from=secret/$CREDS_NAME

waitForPods nationalparks

# call endpoint to load data
echo "Calling /ws/data/load endpoint for nationalparks"
ROUTE=$(oc get route nationalparks  |tail -n 1 | awk '{print $2}')
curl "http://$ROUTE/ws/data/load"
echo

oc label route nationalparks type=parksmap-backend
endOfStep 12

echo "Adding readiness and liveness checks to nationalparks"
oc set probe dc/nationalparks --readiness "--get-url=http://:8080/ws/healthz/" --initial-delay-seconds=20
oc set probe dc/nationalparks --liveness "--get-url=http://:8080/ws/healthz/" --initial-delay-seconds=120
waitForPods nationalparks
endOfStep 13

echo "Removing build triggers from nationalparks"
oc patch dc/nationalparks -p '{
  "spec": {
    "triggers": [
      {
        "imageChangeParams": {
          "containerNames": [
            "nationalparks"
          ],
          "from": {
            "kind": "ImageStreamTag",
            "name": "nationalparks:latest",
            "namespace": "'$OC_PROJECT'"
          }
        },
        "type": "ImageChange"
      }
    ]
  }
}'


# create jenkins the same way we did mongodb, except no servicebinding this time
SECRET_NAME="jenkins-persistent-parameters$UUID"
INSTANCE_NAME="jenkins-persistent-$UUID"
oc create secret generic "$SECRET_NAME" '--from-literal=parameters={"DISABLE_ADMINISTRATIVE_MONITORS":"false","ENABLE_FATAL_ERROR_LOG_FILE":"false","ENABLE_OAUTH":"true","JENKINS_IMAGE_STREAM_TAG":"jenkins:2","JENKINS_SERVICE_NAME":"jenkins","JNLP_SERVICE_NAME":"jenkins-jnlp","MEMORY_LIMIT":"1.5Gi","NAMESPACE":"openshift","VOLUME_CAPACITY":"1Gi"}'
createFromJson '{
  "apiVersion": "servicecatalog.k8s.io/v1beta1",
  "kind": "ServiceInstance",
  "metadata": {
    "finalizers": [
      "kubernetes-incubator/service-catalog"
    ],
    "generateName": "jenkins-persistent-",
    "name": "'$INSTANCE_NAME'"
  },
  "spec": {
    "clusterServiceClassExternalName": "jenkins-persistent",
    "clusterServicePlanExternalName": "default",
    "parametersFrom": [
      {
        "secretKeyRef": {
          "key": "parameters",
          "name": "'$SECRET_NAME'"
        }
      }
    ],
    "updateRequests": 0,
    "userInfo": {
      "extra": {
        "scopes.authorization.openshift.io": [
          "user:full"
        ]
      },
      "groups": [
        "system:authenticated:oauth",
        "system:authenticated"
      ],
      "uid": "",
      "username": "'$OC_PROJECT'"
    }
  }
}'
INSTANCE_UID=$(oc get serviceinstance $INSTANCE_NAME --template '{{.metadata.uid}}')
oc patch secret $SECRET_NAME -p '{"metadata":{"ownerReferences":[{"apiVersion":"servicecatalog.k8s.io/v1beta1","blockOwnerDeletion":false,"controller":false,"kind":"ServiceInstance","name":"'$INSTANCE_NAME'","uid":"'$INSTANCE_UID'"}]}}'

waitForPods "jenkins"
waitForServiceInstance "jenkins-persistent"


GIT_REPO="nationalparks.$(date +%s%N)"
git clone "http://$OC_USERNAME:$OC_PASSWORD@$NATIONALPARK_GIT_HOST" $GIT_REPO
#clean up when we're done
trap "rm -rf $GIT_REPO" EXIT

cd $GIT_REPO


echo -n 'pipeline {
  agent {
      label '$(sq maven)'
  }
  stages {
    stage('$(sq Build JAR)') {
      steps {
        git url: '$(sq $NATIONALPARK_GIT_URL)'
        sh "cp .settings.xml ~/.m2/settings.xml"
        sh "mvn package"
      }
    }
    stage('$(sq Archive JAR)') {
      steps {
        sh "mvn deploy -DskipTests"
      }
    }
    stage('$(sq Build Image)') {
      steps {
        script {
          openshift.withCluster() {
            openshift.withProject() {
              openshift.startBuild("nationalparks",
                                   "--from-file=target/nationalparks.jar",
                                   "--wait")
            }
          }
        }
      }
    }
    stage('$(sq Deploy)') {
      steps {
        script {
          openshift.withCluster() {
            openshift.withProject() {
              def result, dc = openshift.selector("dc", "nationalparks")
              dc.rollout().latest()
              timeout(10) {
                  result = dc.rollout().status("-w")
              }
              if (result.status != 0) {
                  error(result.err)
              }
            }
          }
        }
      }
    }
  }
}' > Jenkinsfile.workshop

addAndCommit "Add Jenkinsfile for workshop teaching purposes" "true"

cd .. 

echo "Creating jenkins pipeline"
createFromJson '{
  "apiVersion": "build.openshift.io/v1",
  "kind": "BuildConfig",
  "metadata": {
    "name": "nationalparks-build"
  },
  "spec": {
    "runPolicy": "Serial",
    "source": {
      "git": {
        "ref": "master",
        "uri": "'$NATIONALPARK_GIT_URL'"
      },
      "type": "Git"
    },
    "strategy": {
      "jenkinsPipelineStrategy": {
        "env": [
          {
            "name": "NEXUS_URL",
            "value": "http://nexus.lab-infra.svc:8081"
          }
        ],
        "jenkinsfilePath": "Jenkinsfile.workshop"
      },
      "type": "JenkinsPipeline"
    },
    "triggers": [
      {
        "github": {
          "secret": "CqPGlXcKJXXqKxW4Ye6z"
        },
        "type": "GitHub"
      },
      {
        "generic": {
          "secret": "4LXwMdx9vhQY4WXbLcFR"
        },
        "type": "Generic"
      },
      {
        "type": "ConfigChange"
      }
    ]
  }
}'
waitForBuilds "nationalparks-build"
endOfStep 14

echo "Creating webhook for nationalparks.git"
WEBHOOK_URL="$OC_HOST/apis/build.openshift.io/v1/namespaces/$OC_PROJECT/buildconfigs/nationalparks-build/webhooks/4LXwMdx9vhQY4WXbLcFR/generic"
curl -X POST -H 'Content-Type: application/json' --user $OC_USERNAME:$OC_PASSWORD -k "http://$GOGS_HOST/api/v1/repos/$OC_USERNAME/nationalparks/hooks" --data '{
  "type": "gogs",
  "active":true,
  "config": {
    "content_type": "json",
    "url": "'$WEBHOOK_URL'"
  },
  "events": [
    "push"
  ]
}'


cd $GIT_REPO
file=src/main/java/com/openshift/evg/roadshow/parks/rest/BackendController.java
echo "Updating $file to trigger deployment"
data=$(cat $file )
#swap it twice to ensure repo gets updated, incase we're running on a repo that has already been modified once
echo "$(echo "$data" | sed 's/Amazing National Parks/National Parks/g')" > $file
addAndCommit "Update BackendController.java"
echo "$(echo "$data" | sed 's/National Parks/Amazing National Parks/g')" > $file 
addAndCommit "Update BackendController.java" "true"
waitForBuilds "nationalparks-build"
endOfStep 15

echo "Creating template from github url"
oc create -f "https://raw.githubusercontent.com/openshift-roadshow/mlbparks/master/ose3/application-template-eap.json"
oc new-app mlbparks -p "APPLICATION_NAME=mlbparks"
waitForPods mlbparks
endOfStep 16


echo "Scaling dc/mlbparks to 2"
oc scale "dc/mlbparks" "--replicas=2"
waitForPods "mlbparks"
endOfStep 17

if [[ $(type mvn 2>/dev/null ) != '' ]];then
    REPO="mlbparks.$(date +%s%N)"
    git clone "$MLBPARKS_GIT_URL" "$REPO"
    cd $REPO
    file=src/main/java/com/openshift/evg/roadshow/rest/BackendController.java 
    data=$(cat $file )
    echo "$(echo "$data" | sed 's/MLB Parks/AMAZING MLB Parks/g')" > $file
    mvn package 
    if [[ $? -ne 0 ]];then
    echo "Maven build failed, skipping this step"
    else
    oc start-build bc/mlbparks --from-file=target/ROOT.war --follow
    fi
    cd ..
    rm -rf $REPO
else 
  echo "mvn could not be found, so we will skip step 18"
fi
endOfStep 18

oc set env dc/mlbparks DEBUG=true
waitForPods mlbparks
#oc port-forward $(oc get pods --no-headers |grep -E '^mlbparks-.*Running' |head -n 1 |awk '{print $1}') 8787:8787
endOfStep 19
