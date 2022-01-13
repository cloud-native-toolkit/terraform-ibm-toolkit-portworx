#!/bin/bash

echo "sleeping for 4 mins to prevent synchronization errors"
sleep 5m

echo "checking for portworx services"

kubectl get service portworx-service -A
kubectl get service portworx-api -A
