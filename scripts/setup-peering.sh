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
vpc_name=$2
# configure service networking

if [ -z "$2" ]
  then
    vpc_name='default'
    subnet_name='default'
  else
    vpc_name=$4
    if [ -z "$5" ]
      then
        echo "A subnetwork is a mandatory parameter when specifying a custom network"
        exit 1
  fi
fi

echo "Project ID: " $project
echo "VPC name: " $vpc_name

gcloud config set project $project

existingAddress=$( gcloud compute addresses list|grep 'google-svcs'|awk '{print $1}')
if [ -z "$existingAddress" ]; then
	gcloud compute addresses create google-svcs --global \
	    --prefix-length=16 --description="Peering range for Google services" \
	    --network=$vpc_name --purpose=VPC_PEERING --project=$project
else 
	echo "google-svcs address already exists... skipping..."
fi

# This establishes the one-time, private connection between the customer project default VPC network and Google tenant projects.
 
existingConnection=$(gcloud services vpc-peerings list --network=$vpc_name | grep -e 'servicenetworking-googleapis-com'|awk '{print $2}')
if [ -z "$existingConnection" ]; then
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --network=$vpc_name --ranges=google-svcs --project=$project
else
 	echo "VPC-Peering connection already exists...skipping"
fi