# Source these values for a large cluster.

# CLUSTER VALUES
# Change cluster name to a unique name that can include alphanumeric characters and hyphens only.
export NAME=large
export CLUSTER_LABELS="forgerock.io/cluster=cdm-large"

# Override default Kubernetes version
export K8S_VERSION="1.21.1"

# cluster-up.sh retrieves the location from the user's az config.  Uncomment below to override:
# export LOCATION=eastus

# Name of Azure Container Registry.  AKS needs to be given access to ACR. Please amend to your registry name.
# export ACR_NAME="" 

# PRIMARY NODE POOL VALUES
export VM_SIZE=Standard_F16s_v2 # vCPU*16, Mem GiB*32, Compute Intensive, Premium Storage(with caching)
export NODE_COUNT=6

# DS NODE POOL VALUES
export CREATE_DS_POOL=true
export DS_VM_SIZE=Standard_DS5_v2 # vCPU*16, Mem GiB*56, Premium Storage(with caching)
export DS_NODE_COUNT=6