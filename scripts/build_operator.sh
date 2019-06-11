#!/bin/bash


helpFunction()
{
   echo ""
   echo "Usage: $0 -u docker-username -p docker-password -s docker-server -r repo-name -t image-tag -o nuodb-ce-operator-branch-name -l nuodb-ce-helm-branch-name"
   echo -e "\t-u Docker username for pushing the image"
   echo -e "\t-p Docker password"
   echo -e "\t-s Docker server to push (e.g. quay.io)"
   echo -e "\t-r Repository name in the server including username"
   echo -e "\t-t Image tag to be used"
   echo -e "\t-o nuodb-ce-operator Branch name to use"
   echo -e "\t-l nuodb-ce-helm Branch name to use"
   exit 1 # Exit script after printing help
}

while getopts "u:p:s:r:t:o:l:h" opt
do
   case "$opt" in
      u ) dusername="$OPTARG" ;;
      p ) dpassword="$OPTARG" ;;
      s ) dserver="$OPTARG" ;;
	  r ) rname="$OPTARG" ;;
	  t ) tag="$OPTARG" ;;
	  o ) obranch="$OPTARG" ;;
	  l ) hbranch="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$dusername" ] || [ -z "$dpassword" ] || [ -z "$dserver" ] || [ -z "$rname" ] || [ -z "$tag" ] || [ -z "$obranch" ] || [ -z "$hbranch" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

PROJECT=nuodb
BUILDDIR=$HOME/build-operator
GOLANG_VERSION=1.11.4

mkdir $BUILDDIR
cd $BUILDDIR
git clone https://github.com/nuodb/nuodb-ce-operator.git 
cd nuodb-ce-operator
git checkout $obranch

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
cd $BUILDDIR
git clone https://github.com/nuodb/nuodb-ce-helm.git
cd nuodb-ce-helm/
git checkout $hbranch
rm -fr .git/
cd $BUILDDIR/nuodb-ce-operator
mv $BUILDDIR/nuodb-ce-helm/ $BUILDDIR/nuodb-ce-operator/helm-charts/nuodb
git status

docker version
echo "Docker login..."
docker login -u $dusername -p $dpassword $dserver


echo "Build NuoDB Operator..."
export NUODB_OP_IMAGE=$dserver/$dusername/$rname:$tag
operator-sdk build $NUODB_OP_IMAGE
docker push $NUODB_OP_IMAGE
