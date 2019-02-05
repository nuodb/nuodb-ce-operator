# nuodb-ce-operator

A Kubernetes Operator for NuoDB CE deployments on OpenShift with support for
both ephemeral and persistent storage.  The nuodb-ce-operator also has support
for NuoDB Insights and an example YCSB workload.


Node Labeling
-------------
Before running the NuoDB Community Edition (CE) persistent storage template,
you must first label the nodes you want to run NuoDB pods.

The first label, "nuodb.com/zone", constrains on which nodes NuoDB pods are
permitted to run. For example:

  oc label node <node-name> nuodb.com/zone=east

Note: the label value, in this example "east", can be any value.

Next, label one of these nodes as your storage node, where you provide
persistent storage for your database. Ensure there is sufficient disk space.
To create this label:

  oc label node <node-name> nuodb.com/node-type=storage


Example of NuoDB CE persistent deployment 
-----------------------------------------

Assumptions:

1) An OpenShift 3.11 or 4.0 cluster with Operator Lifecycle Manager
   installed and running.
2) nuodb-ce-operator repo is in the $HOME directory.
3) A valid oc login.  Example: oc login -u system:admin

PROJECT=nuodb
NODE=centos7.localdomain
CONTAINER=nuodb/nuodb-ce:3.3.0
OPERATOR_NAMESPACE=nuodb

# Disable THP
${HOME}/nuodb-ce-operator/nuodb-prereq/thp-tuned.sh

# make local-storage
sudo mkdir -p /mnt/local-storage/disk0
sudo chmod -R 777 /mnt/local-storage/
sudo chcon -R unconfined_u:object_r:svirt_sandbox_file_t:s0 /mnt/local-storage
sudo chown -R root:root /mnt/local-storage

# label the nodes
oc label node ${NODE} nuodb.com/node-type=storage
oc label node ${NODE} nuodb.com/zone=east --overwrite=true

# create the storage class and persistent volume
oc create -f ${TESTDIR}/nuodb-ce-operator/local-disk-class.yaml

# create the nuodb project
oc new-project nuodb
cd ${TESTDIR}/nuodb-ce-operator

# create the K8s Custom Resource Definition for the NuoDB Operator
oc create -f deploy/crd.yaml

# create the K8s Role Based Access Control for the NuoDB Operator
oc create -n $OPERATOR_NAMESPACE -f deploy/rbac.yaml

# create the NuoDB Operator
oc create -n $OPERATOR_NAMESPACE -f deploy/operator.yaml

# create Cluster Service Version for the OLM
oc create -n $OPERATOR_NAMESPACE -f deploy/csv.yaml

# create the Custom Resource to deploy NuoDB CE
oc create -n $OPERATOR_NAMESPACE -f deploy/cr.yaml


Other deployment examples
-------------------------
The deploy directory also has other Custom Resources to deploy NuoDB CE:

cr-ephemeral.yaml - Deploys NuoDB CE domain using ephemeral storage.

cr-persistent-insights-enabled.yaml - Deploys NuoDB CE domain using persistent
storage and has insights enabled.


Commands to enable, check, disable NuoDB Insights
-------------------------------------------------
# To manually register and enable Insights
oc exec -it nuodb-insights -c insights -- nuoca register insights --enable-insights

# To check on Insights
oc exec -it nuodb-insights -c insights -- nuoca check insights

# To disable Insights:
# oc exec -it nuodb-insights -c insights -- nuoca disable insights
oc scale rc ycsb-load --replicas=1

oc exec -it nuodb-insights -c insights -- nuoca check insights


Cleanup
-------
# To remove the NuoDB CE Deployment, and NuoDB Operator:
oc delete -n $OPERATOR_NAMESPACE -f deploy/cr.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/csv.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/operator.yaml
oc delete -n $OPERATOR_NAMESPACE -f deploy/rbac.yaml
oc delete -f deploy/crd.yaml


Operator Variables
-------------------

The following is a list of default variables for the NuoDB CE Operator.
You can override any of the variables in your Custom Resource yaml file
(cr.yaml)


# storageMode
# Run NuoDB CE using a persistent, local, disk volume "persistent"
# or volatile storage "ephemeral".  Must be set to one of those values.
storageMode: persistent


# insightsEnabled
# Use to control Insights Opt In.  Insights provides database monitoring.
# Set to "true" to activate or "false" to deactivate
insightsEnabled: false

# adminCount
# Number of admin service pods. Requires 1 server available for each
# Admin Service
adminCount: 1

# adminStorageSize
# Admin service log volume size (GB)
adminStorageSize: 5G

# adminStorageClass
# Admin persistent storage class name
adminStorageClass: glusterfs-storage

# dbName
# NuoDB Database name.  must consist of lowercase alphanumeric
#characters '[a-z0-9]+'
dbName: test

# dbUser
# Name of Database user
dbUser: dba

# dbPassword
# Database password
dbPassword: secret

# smMemory
# SM memory (in GB)
smMemory: 2

# smCpu
# SM CPU cores to request
smCpu: 1

# smStorageSize
# Storage manager (SM) volume size (GB)
smStorageSize: 20G

# smStorageClass
# SM persistent storage class name
smStorageClass: local-disk

# engineOptions
# Additional "nuodb" engine options
# Format: <option> <value> <option> <value> ...
engineOptions: ""

# teCount
# Number of transaction engines (TE) nodes.  Limit is 3 in CE version of NuoDB
teCount: 1

# teMemory
# TE memory (in GB)
teMemory: 2

# teCpu
# TE CPU cores to request
teCpu: 1

# ycsbLoadName
# YCSB workload pod name
ycsbLoadName: ycsb-load

# ycsbWorkload
# YCSB workload.  Valid values are a-f. Each letter determines a different
# mix of read and update workload percentage generated. a= 50/50, b=95/5,
# c=100 read. Refer to YCSB documentation for more detail
ycsbWorkload: b

# ycsbLbPolicy
# YCSB load-balancer policy. Name of an existing load-balancer policy, that
# has already been created using the 'nuocmd set load-balancer' command.
ycsbLbPolicy: ""

# ycsbNoOfProcesses
# Number of YCSB processes. Number of concurrent YCSB processes that will
# be started in each YCSB pod. Each YCSB process makes a connection to the
# database.
ycsbNoOfProcesses: 2

# ycsbNoOfRows: 10000
# YCSB number of initial rows in table
ycsbNoOfRows: 10000

# ycsbNoOfIterations
# YCSB number of iterations
ycsbNoOfIterations: 0

# ycsbOpsPerIteration
# Number of YCSB SQL operations to perform in each iteration.
# This value controls the number of SQL operations performed in each benchmark
# iteration. Increasing this value increases the run-time of each iteration,
# and also reduces the frequency at which new connections are made during the
# sample workload run period.
ycsbOpsPerIteration: 10000

# ycsbMaxDelay
# YCSB maximum workload delay in milliseconds (Default is 4 minutes)
ycsbMaxDelay: 240000

# ycsbDbSchema
# YCSB Database schema.  Default schema to use to resolve tables, views, etc
ycsbDbSchema: User1

# apiServer
# Load balancer service URL.  hostname:port (or LB address) for nuoadmin
# process to connect to.
apiServer: https://domain:8888

# container
# NuoDB fully qualified image name (FQIN) for the Docker image to use
# container: "registry.connect.redhat.com/nuodb/nuodb-ce:latest"
container: nuodb/nuodb-ce:3.3.0

# ycsbContainer
# YCSB fully qualified image name (FQIN) for the Docker image to use
ycsbContainer: nuodb/ycsb:latest




