# Multi-cluster deployment using Google Cloud Multi Cluster Ingress and CloudDNS for GKE

Google Docs:   
* [Multi Cluster Ingress](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress)
* [Setup Multi Cluster Ingress](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup)  
* [Deploy Multi Cluster Ingress](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress)

## Overview
This guide explains how to deploy the ForgeRock Identity Platform across 2 different clusters and configure proximity-based routing with Multi Cluster Ingress.

Features:
* Fully meshed multi-cluster DS tolopology using CloudDNS for GKE.  
* Global HTTP(S) load balancing across multiple clusters with Multi Cluster Ingress.  
* Healthchecks to manage application level failover between clusters.
* Proximity-based routing.
* Active/active or failover.
* Blue/green deployments.

## Step 1: Pre-requisites
#

**1. Cloud SDK version**
* cloud SDK version 290 or later.

**2. Select Anthos pricing model**  
Anthos ingress controller is a Google hosted service which is used by Multi Cluster Ingress.  
Choose your Anthos pricing model here: [Anthos](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup#enablement).  

**3. Enable MCI APIs**  
```bash
gcloud services enable gkehub.googleapis.com  
gcloud services enable anthos.googleapis.com # Enable if required based on the previous section  
gcloud services enable multiclusteringress.googleapis.com 
```

## Step 2: Cluster provisioning and DS setup
#

* Follow the clouddns [readme](https://github.com/ForgeRock/forgeops/blob/master/etc/multi-cluster/google-cloud/clouddns/README.md) to set up US and EU clusters and deploy DS using Cloud DNS for GKE.  

* Enable HTTP loadbalancing on the clusters.  This can be applied either at cluster creation time or after the clusters are created. 

* After following the above steps you should have the following:
  * HTTP loadbalancing and workload identity enabled on both clusters.
  * Secret Agent Operator deployed.
  * DS deployed and communicating across both clusters.  

* Now you need to register your new clusters to a fleet.  Multi-cluster works only on clusters that are registered to the same fleet. 
Ensure:
* \<cluster_location\> matches the location of the cluster master.
* \<cluster_name\> matches the exact name of the cluster.
* \<project_id> matches your Google Cloud Project ID.

```bash
gcloud container hub memberships register <cluster_name> \
    --gke-cluster <cluster_location>/<cluster_name> \
    --enable-workload-identity \
    --project=<project_id>
```

Verify membership by running the following command

```bash
gcloud container hub memberships list --project=<project_id>
```

## Step 3: Config cluster
#
For more info on configuring the config cluster, see Google doc [here](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup#specifying_a_config_cluster).

Enable the US cluster as the config cluster:
```bash
gcloud alpha container hub ingress enable --config-membership=clouddns-us
```

Verify the config cluster:
```bash
gcloud alpha container hub ingress describe
```

Output should look something like:
```yaml
multiclusteringressFeatureSpec:
  configMembership: projects/<project-id>/locations/global/memberships/<cluster-membership-name>
```

## Step 4: MCI Preparation
#

**1. Create a Static IP**  
A static IP is required for the HTTP(S) loadbalancer.  See doc [here](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#static).

Add the IP address to the MultiClusterIngress [file](https://github.com/ForgeRock/forgeops/tree/master/etc/multi-cluster/google-cloud/multi-cluster-ingress/mci.yaml) using the static-ip annotation:

```yaml
  annotations:
    networking.gke.io/static-ip: <static ip address>
```  

**2. SSL cert for the HTTP(S) load balancer**
There are various options for generating an SSL cert for external traffic to the HTTP(S) load balancer.  
* Pre-shared certificates [doc](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#pre-shared_certificates)
* Google managed certificates [doc](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#google-managed_certificates)
* Configure SSL cert as Kubernetes secret [doc](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#https_support)  

For the first 2 options, update the MultiClusterIngress [file](https://github.com/ForgeRock/forgeops/tree/master/etc/multi-cluster/google-cloud/multi-cluster-ingress/mci.yaml) using the pre-shared-certs annotation:
```yaml
  annotations:
    networking.gke.io/pre-shared-certs: "certname"
```  

**3. Configure FQDN**  
Add FQDN to the host property in the MultiClusterIngress [file](https://github.com/ForgeRock/forgeops/tree/master/etc/multi-cluster/google-cloud/multi-cluster-ingress/mci.yaml).  

```yaml
      rules:
      - host: <fqdn>
```

**4. Deploy the custom resources to the config server**

```bash
cd etc/multi-cluster/google-cloud/multi-cluster-ingress/mci
kubectl apply -f mci.yaml -n prod
kubectl apply -f mcs.yaml -n prod
kubectl apply -f backendconfig.yaml -n prod
```

For more information on the above resources see the 2 Google doc links below:
* MultiClusterIngress(mci.yaml): https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress#multiclusteringress_resource 
* MultiClusterService(mcs.yaml): https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress#multiclusterservice_resources
* BackendConfig(backendconfig.yaml): https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress#backendconfig_support

## Step 5: Deploy Frontend Apps
#

**1. Deploy AM, IDM and the UIs**  
This example reflects a CDM medium size deployment which is the size used for testing.  Please adjust to suit your requirements.
```bash
bin/forgeops install apps ui --medium
```

**2. Verify deployment**

Things to check:
* All pods are deployed `kubectl get pods`
* You can access the UIs e.g. https://prod.mci.forgeops.com/platform.
* Load balancer pod status is green and backend services are green(healthchecks passed) e.g. 
https://console.cloud.google.com/kubernetes/multiclusteringress/us-west1-b/clouddns-us/prod/forgerock/details?project=\<projectID\>.
* Verify requests from a US and EU location go to their relevant/local clusters.

## Step 6: Deleting the deployment 
#

Carry out the following commands in each cluster:

```bash
bin/forgeops delete apps ui
```

## Step 7: Deleting the Multi-cluster Ingress configuration
#

**1. Remove configs from config cluster**

From the config cluster:

```bash
kubectl delete mcs --all
kubectl delete backendconfig --all
kubectl delete mci forgerock
```

**2. Remove clusters from fleet**
```bash
gcloud container hub memberships delete clouddns-eu
gcloud container hub memberships delete clouddns-us
```

## Step 8: Pricing
#
https://cloud.google.com/kubernetes-engine/pricing#multi-cluster-ingress

## Step 9: Testing
#
The following tests have been carried out across 2 clusters in different regions unless specified
(failover is triggered by scaling down product to 0 pods):
* Verify geolocation.
* Test failover between europe-west1 and europe-west2/europe-west2 and us-west-2
* Failover IDM while creating users.
* Test failover of AM across 3 clusters in different regions.
* Test split load by running test against 1 location with low available resources.
* Failover IDM based on idrepo being down.
* Failover AM which running AuthN and Access Token simulations.
* Test failover across 3 different clusters.
* Running performance tests for 1,6 and 12 hour durations.
* Running AM performance tests with stateful and stateless tokens.
* Running load simulataneously across 2 clusters and forcing failover of AM.  


## TODO
#

* Use healthcheck status to manage failovers
  * Failover IDM if AM is down
  * Failover AM if idrepo or cts is down
  * Failover IDM if idrepo is down
* Enable SSL endpoint of AM
* Resolve throughput issues after 7 hours during dual load performance testing
* IG/RCS agent?
