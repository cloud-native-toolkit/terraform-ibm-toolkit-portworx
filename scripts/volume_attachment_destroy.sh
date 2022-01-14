#!/bin/bash

JQ="$BIN_DIR/jq"

export TOKEN=$(curl -s -X POST "https://iam.cloud.ibm.com/identity/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${IBMCLOUD_API_KEY}" | ${JQ} -r '.access_token')


echo "Detaching volume $VOLUME_ID from worker $WORKER_ID"

# Grab volume attachment id
if ! RESPONSE=$(
    curl -s -X GET -H "Authorization: $TOKEN" \
        -H "Content-Type: application/json" \
        -H "X-Auth-Resource-Group-ID: $RESOURCE_GROUP_ID" \
        "https://$REGION.containers.cloud.ibm.com/v2/storage/getAttachments?cluster=$CLUSTER_ID&worker=$WORKER_ID"
); then
  echo 'Error when trying to /getAttachments'
  exit 1
fi

ID=$(echo $RESPONSE | jq -r --arg VOLUMEID "$VOLUME_ID" '.volume_attachments[] | select(.volume.id==$VOLUMEID) | .id')

if [ "$ID" == "" ] || [ "$ID" == "null" ]; then
    echo "No attachment found, skipping"
else
    echo "Deleting volume attachment $ID"
    if ! curl -s -X DELETE -H "Authorization: $TOKEN" \
        "https://$REGION.containers.cloud.ibm.com/v2/storage/vpc/deleteAttachment?cluster=$CLUSTER_ID&worker=$WORKER_ID&volumeAttachmentID=$ID"; then
      echo 'Delete failed'
      exit 1
    fi
    echo 'Sleeping for 30s...'
    sleep 30
fi
