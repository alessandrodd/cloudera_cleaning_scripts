# Cloudera Cluster Scripts
Various scripts that can be useful in a Cloudera CDH deployment

# Role-Aware Cloudera Cleaner
A Python script that, when executed on an host attached to a Cloudera Cluster, uses the Cloudera Manager APIs to detect the configured role types and to execute actions and scripts that "cleans" the cluster. Since some cleaning operations are cluster-wide and are only executed from an elected host to avoid double runs, it should be executed by each of the hosts of the cluster to be effective.