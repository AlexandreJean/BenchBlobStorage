
**Introduction**

*TO BE REVIEWED*

This project allows you to deploy a cluster (1 x master node with X x compute nodes) along with storage blob accounts to do raw benchmarks. The master node will be automatically configured with a GIT stack (Grafana / InfluxDB / Telegraph) to monitor activity on the compute nodes.
The first run will issue writes to the storage accounts, then reads. The second run will not re-do the writes if the storage accounts in the resource group you have configured already exist.

**How To**

**1.** You first need to have your devops environment configured links to your azure subscription via an spn.

**2.** Create a keyvault in your subscription and define the following keys :

...

**3.** Update the inputs-variables, make sure you have the proper quotas in your subscription

...
...
...
