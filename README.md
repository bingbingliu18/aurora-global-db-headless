# Amazon Aurora Global Database headless cluster Failover

Amazon Aurora Global Database headless cluster allows you to promote secondary cluster(s) in a different AWS region to a primary cluster, during regional failures.The recomended steps to promote a secondary cluster are 

- Step 1: Stop Application from writing to primary
- Step 2: Identify secondary to promote based on latency for end users 
- Step 3: Add DB instance to headless cluster and promote identified secondary to primary 
- Step 4: Delete old primary and other secondaries
- Step 5: Point application to new primary (standalone)

This script automates steps 3 by using AWS CLI. To install AWS CLI which is a pre-requisite to run this script, follow the instructions [here](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

The script takes 5 parameters as input. 

- -g --> Global database identifer
- -R --> Secondary cluster region
- -r --> Secondary cluster identifer
- -s -->  Added DB instance size
- -n -->  Added DB instance AZ


To run the script

- Clone the repo
- cd to the downloaded location
- Make the script executable ```chmod +x FailoverGlobalDBHeadless.sh ```
- Use the below instructions to invoke the script
```
sh FailoverGlobalDBHeadless.sh -g <'Global Cluster Identfier'> -R <'secondary cluster region'> -r <'secondary cluster to promote'> -s <'Added DB instance size'> -n <'Added DB instance AZ'>;

```

## Sample Input
```
sh FailoverGlobalDBHeadless.sh -g aurora-global-db-headless -R us-west-2 -r aurora-global-db-headless-cluster-1 -s db.r6g.large -n us-west-2b;
```

## Sample Output

```
Are you sure you want to add a new instance  to cluster aurora-global-db-headless-cluster-1 at region us-west-2; DB instance size is db.r6g.large and AZ is us-west-2b  (y/n)? y
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Waiting for database instance aurora-global-db-headless-cluster-1-instance-1 to be created...
Are you sure you want to promote cluster aurora-global-db-headless-cluster-1 to a standalone cluster? (y/n)  y
Waiting for cluster promotion to complete...
Waiting for cluster promotion to complete...
Waiting for cluster promotion to complete...
Waiting for cluster promotion to complete...
Successfully added a new database instance aurora-global-db-headless-cluster-1-instance-1 and promoted the region cluster aurora-global-db-headless-cluster-1 to a standalone cluster.
```
