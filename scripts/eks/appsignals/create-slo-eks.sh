#!/bin/bash

# change the directory to the script location so that the relative path can work
cd "$(dirname "$0")"

CLUSTER_NAME=$1
REGION=$2

check_if_step_failed_and_exit() {
  if [ $? -ne 0 ]; then
    echo $1
    exit 1
  fi
}

check_if_loop_failed_and_exit() {
  if [ $1 -ne 0 ]; then
    echo $2
    exit 1
  fi
}

# SLR could be created via console or API. So EnableTopologyDiscovery API is called to enroll topology discovery.
aws application-signals start-discovery --region $REGION
check_if_step_failed_and_exit "There was an error enabling topology discovery, exiting"

echo "Creating Service Level Objectives"

# Create customers-service availability SLO
echo "Creating customers-service availability SLO..."
err=0
for i in {1..5}
do
  output=$(aws application-signals create-service-level-objective \
    --name "customers-service-availability" \
    --description "Availability SLO for customers service - 95% success rate" \
    --sli-config '{
      "SliMetricConfig": {
        "KeyAttributes": {
          "Environment": "eks:'$CLUSTER_NAME'/default",
          "Name": "customers-service-java",
          "Type": "Service"
        },
        "OperationName": "InternalOperation",
        "MetricType": "AVAILABILITY"
      },
      "MetricThreshold": 95.0,
      "ComparisonOperator": "GreaterThanOrEqualTo"
    }' \
    --goal '{
      "Interval": {
        "RollingInterval": {
          "DurationUnit": "HOUR",
          "Duration": 1
        }
      },
      "AttainmentGoal": 95.0,
      "WarningThreshold": 30.0
    }' \
    --region $REGION 2>&1)
  err=$?
  if echo "$output" | grep 'InvalidParameterValue'; then
    echo "Error creating availability SLO. Retrying attempt: $i"
    sleep 120
    continue
  fi
  break
done
check_if_loop_failed_and_exit $err "There was an error creating customers-service availability SLO"
echo "$output"

# Create customers-service latency SLO
echo "Creating customers-service latency SLO..."
err=0
for i in {1..5}
do
  output=$(aws application-signals create-service-level-objective \
    --name "customers-service-latency" \
    --description "Latency SLO for customers service - 99% under 100ms" \
    --sli-config '{
      "SliMetricConfig": {
        "KeyAttributes": {
          "Environment": "eks:'$CLUSTER_NAME'/default",
          "Name": "customers-service-java",
          "Type": "Service"
        },
        "OperationName": "InternalOperation",
        "MetricType": "LATENCY",
        "Statistic": "Average"
      },
      "MetricThreshold": 100.0,
      "ComparisonOperator": "LessThan"
    }' \
    --goal '{
      "Interval": {
        "RollingInterval": {
          "DurationUnit": "HOUR",
          "Duration": 1
        }
      },
      "AttainmentGoal": 99.0,
      "WarningThreshold": 30.0
    }' \
    --region $REGION 2>&1)
  err=$?
  if echo "$output" | grep 'InvalidParameterValue'; then
    echo "Error creating latency SLO. Retrying attempt: $i"
    sleep 120
    continue
  fi
  break
done
check_if_loop_failed_and_exit $err "There was an error creating customers-service latency SLO"
echo "$output"