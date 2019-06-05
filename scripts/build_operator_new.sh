#!/bin/bash

PROJECT=nuodb
BUILDDIR=$HOME/build-operator
GOLANG_VERSION=1.11.4


mkdir $BUILDDIR
cd $BUILDDIR
git clone https://github.com/nuodb/nuodb-ce-operator.git 
cd nuodb-ce-operator
git checkout ashukla/DB-26277


echo "Installing GoLang version: '${GOLANG_VERSION}' ..."
cd ${HOME}
wget https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz
cat << EOF > ${HOME}/.bash_profile
export PATH=$PATH:/usr/local/go/bin
EOF
source ${HOME}/.bash_profile
go version


# GOPATH
echo "Adding gopath to PATH..."
export GOPATH=${HOME}/gopath
mkdir -p ${GOPATH}/bin
export PATH=${GOPATH}/bin:$PATH

# dep
echo "Installing dep..."
curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
dep version


# Install the Operator SDK
echo "Installing the Operator SDK..."
mkdir -p $GOPATH/src/github.com/operator-framework
cd $GOPATH/src/github.com/operator-framework
git clone https://github.com/operator-framework/operator-sdk.git
cd operator-sdk
git checkout v0.7.0
make dep install
operator-sdk version

echo "Making helm-dir and getting latest"
cd $BUILDDIR/nuodb-ce-operator
CURRENTDIR=$(pwd)
echo "Cureent dir : $CURRENTDIR"
mkdir helm-charts
cd helm-charts/
git clone https://github.com/nuodb/nuodb-ce-helm.git
cd nuodb-ce-helm/
rm -fr .git/
cd ../../
git status

docker version
echo "Docker login..."
#docker login -u tgatesnuodb -p 9892-Kcod
docker login -u ashukl -p @5hutoSh quay.io


echo "Build NuoDB Operator..."
export NUODB_OP_IMAGE=quay.io/ashukl/nuodb-operator:latest
operator-sdk build $NUODB_OP_IMAGE
docker push $NUODB_OP_IMAGE
