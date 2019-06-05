#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -u docker-username -p docker-password -e docker-email -s docker-server -r repo-name -t image-tag -c clusterserviceversion"
   echo -e "\t-u Docker username for pushing the image"
   echo -e "\t-p Docker password"
   echo -e "\t-e Docker email"
   echo -e "\t-s Docker server to push (e.g. quay.io)"
   echo -e "\t-r Repository name in the server including username"
   echo -e "\t-t Image tag to be used"
   echo -e "\t-c clusterserviceversion to use "
   exit 1 # Exit script after printing help
}

while getopts "u:p:s:r:t:e:c:h" opt
do
   case "$opt" in
      u ) dusername="$OPTARG" ;;
      p ) dpassword="$OPTARG" ;;
      s ) dserver="$OPTARG" ;;
	  r ) rname="$OPTARG" ;;
	  t ) tag="$OPTARG" ;;
	  e ) demail="$OPTARG" ;;
	  c ) csv="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$dusername" ] || [ -z "$dpassword" ] || [ -z "$dserver" ] || [ -z "$rname" ] || [ -z "$tag" ] || [ -z "$demail" ] || [ -z "$csv" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi


PROJECT=nuodb
NODE=centos7.localdomain
TESTDIR=$HOME/nuodb/nuodb_ocp_test_okd
OPERATOR_NAMESPACE=nuodb

yum install -y nc

if [ ! -d ${TESTDIR} ]; then
  mkdir -p $TESTDIR
fi
cd $TESTDIR

# git clone nuodb-ce-operator
if [ -d ${TESTDIR}/nuodb-ce-operator ]; then
  rm -fr ${TESTDIR}/nuodb-ce-opeartor
fi
cp -r /vagrant/nuodb-ce-operator $TESTDIR/

# Wait for OpenShift API to become ready
while ! echo exit | nc localhost 8443; do sleep 2; done

sleep 60

oc login -u system:admin

OCPVERSION=$(oc version | gawk '$1 ~ /^openshift/ { print $NF; }')
echo $OCPVERSION

docker login -u $dusername -p $dpassword $dserver

oc new-project ${PROJECT}

# Disable THP
${TESTDIR}/nuodb-ce-operator/nuodb-prereq/thp-tuned.sh

cd ${TESTDIR}

echo "Make local-storage"
# make local-storage
sudo mkdir -p /mnt/local-storage/disk0
sudo chmod -R 777 /mnt/local-storage/
sudo chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /mnt/local-storage
sudo chown -R root:root /mnt/local-storage

echo "Label the nodes..."
oc label node ${NODE} nuodb.com/node-type=storage
oc label node ${NODE} nuodb.com/zone=east --overwrite=true

echo "Create the storage class and persistent volume..."
oc create -f ${TESTDIR}/nuodb-ce-operator/deploy/local-disk-class.yaml

 oc create secret docker-registry docker-pull-secret \
    --docker-server=$dserver --docker-username=$dusername \
    --docker-password=$dpassword --docker-email=$demail

oc secrets link default docker-pull-secret --for=pull

echo "Pulling Docker Image nuodb-ce-operator"
export NUODB_OP_IMAGE=$dserver/$dusername/$rname:$tag
docker pull  $NUODB_OP_IMAGE

echo "Create nuodb project..."
cd ${TESTDIR}/nuodb-ce-operator

echo "Create the K8s Custom Resource Definition for the NuoDB Operator..."
oc create -f deploy/crds/nuodb_v1alpha1_nuodb_crd.yaml

echo "Create the K8s Custom Resource Definition for the NuoDB Operator..."
oc create -f deploy/service_account.yaml

echo "Create the K8s Role Based Access Control for the NuoDB Operator..."
oc create -n $OPERATOR_NAMESPACE -f deploy/rbac.yaml

echo "Create the NuoDB Operator..."
oc create -n $OPERATOR_NAMESPACE -f deploy/operator.yaml

echo "Create Cluster Service Version for the OLM..."
oc create -n $OPERATOR_NAMESPACE -f deploy/olm-catalog/nuodb-ce-operator/$csv/nuodb.$csv.clusterserviceversion.yaml

echo "Create the Custom Resource to deploy NuoDB..."
oc create -n $OPERATOR_NAMESPACE -f deploy/cr.yaml
