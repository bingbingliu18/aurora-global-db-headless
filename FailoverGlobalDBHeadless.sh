#!/bin/bash

# Check input arguments


# Parse input arguments
while getopts ":g:R:r:s:n:" opt; do
    case $opt in
        g) GLOBAL_CLUSTER_ID="$OPTARG";;
        R) REGION="$OPTARG";;
        r) REGION_CLUSTER_ID="$OPTARG";;
        s) DB_INSTANCE_CLASS="$OPTARG";;
        n) DB_INSTANCE_AZ="$OPTARG";;
 
    esac
done

if [ -z "$GLOBAL_CLUSTER_ID" ] || [ -z "$REGION" ]|| [ -z "$REGION_CLUSTER_ID" ] || [ -z "$DB_INSTANCE_CLASS" ]|| [ -z "$DB_INSTANCE_AZ" ]; then
    echo "Usage: $0 -g <global_cluster_identifier> -R <region> -r <region_cluster_identifier> -s <database_node_size> -n <database_node_az>"
    exit 1
fi


# Error handling function
function errorCheck() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Wait for the database instance creation to complete
function waitForInstanceCreationToComplete() {
    local INSTANCE_ID=$1
    local REGION=$2

    while true; do
        STATUS=$(aws rds describe-db-instances --db-instance-identifier "$INSTANCE_ID" --region "$REGION" --query 'DBInstances[0].DBInstanceStatus' --output text)
        if [ "$STATUS" != "creating" ]; then
            break
        fi
        echo "Waiting for database instance $INSTANCE_ID to be created..."
        sleep 10
    done

    if [ "$STATUS" != "available" ]; then
        errorCheck "Database instance $INSTANCE_ID creation failed with status $STATUS"
    fi
}

# Remove the region cluster from the global cluster and promote it to a standalone cluster
function removeFromGlobalCluster() {
    aws rds remove-from-global-cluster --global-cluster-identifier "$GLOBAL_CLUSTER_ID" --region "$REGION" --db-cluster-identifier "$REGION_CLUSTER_ARN" 2>&1
    errorCheck "Failed to remove the region cluster from the global cluster"
}

# Wait for the promotion to complete
function waitForPromotionToComplete() {
    local GLOBAL_CLUSTER_ID=$1
    local REGION_CLUSTER_ARN=$2
    remainingsecondaryClusters=$(aws rds describe-global-clusters --global-cluster-identifier "$GLOBAL_CLUSTER_ID" --output text --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter== `false`].DBClusterArn')
    while [[ "$remainingsecondaryClusters" = $REGION_CLUSTER_ARN ]]; do
        sleep 10s
        remainingsecondaryClusters=$(aws rds describe-global-clusters --global-cluster-identifier "$GLOBAL_CLUSTER_ID" --output text --query 'GlobalClusters[0].GlobalClusterMembers[?IsWriter== `false`].DBClusterArn')
	    echo "Waiting for cluster promotion to complete..."
    done
}

# Get all region clusters in the global cluster
REGION_CLUSTERS=$(aws rds describe-global-clusters --region "$REGION" --global-cluster-identifier "$GLOBAL_CLUSTER_ID" --query 'GlobalClusters[0].GlobalClusterMembers[*].DBClusterArn' --output text)
if [ -z "$REGION_CLUSTERS" ]; then
    echo "No region clusters found in the global cluster $GLOBAL_CLUSTER_ID."
    exit 1
fi

# Find the region cluster to be promoted to a standalone cluster
REGION_CLUSTER_ARN=$(aws rds describe-db-clusters --region "$REGION" --db-cluster-identifier "$REGION_CLUSTER_ID" --query 'DBClusters[0].DBClusterArn' --output text)
if [ -z "$REGION_CLUSTER_ARN" ]; then
    echo "Region cluster $REGION_CLUSTER_ID does not exist."
    exit 1
fi

# Get the engine and engine version from the existing cluster
ENGINE=$(aws rds describe-db-clusters --db-cluster-identifier "$REGION_CLUSTER_ID" --region "$REGION" --query 'DBClusters[0].Engine' --output text)
errorCheck "Failed to get the engine"

ENGINE_VERSION=$(aws rds describe-db-clusters --db-cluster-identifier "$REGION_CLUSTER_ID" --region "$REGION" --query 'DBClusters[0].EngineVersion' --output text)
errorCheck "Failed to get the engine version"

# Confirm before creating a new database instance
read -p "Are you sure you want to add a new instance $DB_INSTANCE_IDENTIFIER to cluster $REGION_CLUSTER_ID at region $REGION; DB instance size is $DB_INSTANCE_CLASS and AZ is $DB_INSTANCE_AZ  (y/n)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Canceled creating a new instance"
    exit 0
fi
start_time=$(date +%s)
echo "Task started at $(date -d @$start_time +'%Y-%m-%d %H:%M:%S')"
# Create a new database instance
DB_INSTANCE_IDENTIFIER="$REGION_CLUSTER_ID-instance-1"
aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
    --db-cluster-identifier "$REGION_CLUSTER_ID" \
    --db-instance-class "$DB_INSTANCE_CLASS" \
    --engine "$ENGINE" \
    --engine-version "$ENGINE_VERSION" \
    --region "$REGION" \
    --availability-zone "$DB_INSTANCE_AZ"

errorCheck "Failed to create a new database instance"

# Wait for the database instance creation to complete
waitForInstanceCreationToComplete "$DB_INSTANCE_IDENTIFIER" "$REGION"

# Confirm before promoting the cluster
read -p "Are you sure you want to promote cluster $REGION_CLUSTER_ID to a standalone cluster? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Canceled promoting the cluster"
    exit 0
fi

# Remove the region cluster from the global cluster and promote it to a standalone cluster
removeFromGlobalCluster

# Wait for the promotion to complete
waitForPromotionToComplete "$GLOBAL_CLUSTER_ID" "$REGION_CLUSTER_ARN"

echo "Successfully added a new database instance $DB_INSTANCE_IDENTIFIER and promoted the region cluster $REGION_CLUSTER_ID to a standalone cluster."
end_time=$(date +%s)
echo "Task ended at $(date -d @$end_time +'%Y-%m-%d %H:%M:%S')"

duration=$((end_time-start_time))
echo "Task duration: $duration seconds"
