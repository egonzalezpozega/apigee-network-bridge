#!/bin/sh
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

project=$1
region=$2
endpoint=$3
vpc_name=$4
subnet_name=$5
mig_name=apigee-mig-$region

echo "Create GCE instance template\n"
# create a template
existingInstanceTemplate=$( gcloud compute instance-templates list|grep $mig_name|awk '{print $1}')
if [ -z "$existingInstanceTemplate" ]; then
  gcloud compute instance-templates create $mig_name \
    --project $project --region $region --network $vpc_name --subnet $subnet_name \
    --tags=https-server,apigee-mig-proxy,gke-apigee-proxy \
    --machine-type e2-medium --image-family debian-10 \
    --image-project debian-cloud --boot-disk-size 20GB \
    --metadata=ENDPOINT=$endpoint,startup-script-url=gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh
    
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    exit 1
  fi
else
  echo "Instance template $mig_name already exists...skipping"
fi


echo "Create GCE Managed Instance Group\n"
# Create Instance Group
# NOTE: Change min replicas if necessary

existingInstanceGroup=$( gcloud compute instance-groups managed list|grep $mig_name|awk '{print $1}')
if [ -z "$existingInstanceGroup" ]; then
  gcloud compute instance-groups managed create $mig_name \
      --project $project --base-instance-name apigee-mig \
      --size 2 --template $mig_name --region $region
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    exit 1
  fi
else
  echo "Instance group $mig_name already exists...skipping"
fi

echo "Create GCE auto-scaling\n"
# Configure Autoscaling
# NOTE: Change max replicas if necessary
existingAutoscaling=$( gcloud compute instance-groups managed describe $mig_name --region $region|grep 'autoscaler'|awk '{print $1}')
if [ -z "$existingAutoscaling" ]; then
  gcloud compute instance-groups managed set-autoscaling $mig_name \
      --project $project --region $region --max-num-replicas 20 \
      --target-cpu-utilization 0.75 --cool-down-period 90
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    exit 1
  fi
else
  echo "Autoscaling for instance group $mig_name is already setup...skipping"
fi

# Defined Named Port
gcloud compute instance-groups managed set-named-ports $mig_name \
    --project $project --region $region --named-ports https:443
RESULT=$?
if [ $RESULT -ne 0 ]; then
  exit 1
fi
