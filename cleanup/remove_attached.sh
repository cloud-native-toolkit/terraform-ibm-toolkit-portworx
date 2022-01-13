#!/bin/sh

export CLUSTER="${1}"
export UNIQUE_ID="pwx" 

usage()
{
    echo "usage: " `basename $0` "[-h] CLUSTER"
    echo
    echo "Run remove volume attachment script."
    echo
    echo "arguments:"
    echo "  -h, --help            show this help message and exit"
    exit 1
}

if [ -z "$1" ]
  then
    usage
fi



echo "Removing attachment from worker-node"
for worker_node_id in `ibmcloud oc workers  --cluster $CLUSTER |grep '^kube' | cut -d ' ' -f 1` ; do 

    echo "worker: $worker_node_id"
    attachment_id=`ibmcloud ks storage attachments -c $CLUSTER -w ${worker_node_id} | grep ${UNIQUE_ID} | cut -d ' ' -f 1`
    if [ -n "$attachment_id" ]; then 
        ibmcloud ks storage attachment rm -c $CLUSTER -w ${worker_node_id} --attachment ${attachment_id}
    else
        echo "not found"
    fi 

done