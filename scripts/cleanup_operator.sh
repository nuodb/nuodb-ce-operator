#!/bin/bash

#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -c clusterserviceversion"
   echo -e "\t-c clusterserviceversion to use "
   exit 1 # Exit script after printing help
}

while getopts "c:h" opt
do
   case "$opt" in
	  c ) csv="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$csv" ]
then
   echo "Enter clusterserviceversion";
   helpFunction
fi


PROJECT=nuodb
NODE=centos7.localdomain
TESTDIR=$HOME/nuodb/nuodb_ocp_test_okd
CONTAINER=nuodb/nuodb-ce:3.3.0
#CONTAINER="registry.connect.redhat.com/nuodb/nuodb-ce:latest"
OPERATOR_NAMESPACE=nuodb

cd $TESTDIR

# Wait for OpenShift API to become ready
while ! echo exit | nc localhost 8443; do sleep 2; done

#sleep 60

oc login -u system:admin

OCPVERSION=$(oc version | gawk '$1 ~ /^openshift/ { print $NF; }')
echo $OCPVERSION

oc project nuodb
cd ${TESTDIR}/nuodb-ce-operator

oc delete -n $OPERATOR_NAMESPACE -f deploy/cr.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/olm-catalog/nuodb-ce-operator/$csv/nuodb.v$csv.clusterserviceversion.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/operator.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/rbac.yaml
oc delete -f deploy/crds/nuodb_v1alpha1_nuodb_crd.yaml


oc secrets unlink default nuodb-docker
oc delete secret generic nuodb-docker
oc delete pvc archive-sm-0
oc delete -f ${TESTDIR}/nuodb-ce-operator/deploy/local-disk-class.yaml


oc label node ${NODE} nuodb.com/zone-
oc label node ${NODE} nuodb.com/node-type-

rm -fr /mnt/local-storage/disk0

# remove nuodb-ce-operator
if [ -d ${TESTDIR}/nuodb-ce-operator ]; then
  rm -fr ${TESTDIR}/nuodb-ce-opeartor
fi

oc project default
oc delete project nuodb
