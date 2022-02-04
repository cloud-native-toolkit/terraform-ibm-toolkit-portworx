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

echo "WORKERS:"
ibmcloud oc workers  --cluster $CLUSTER


echo "ATTACHMENTS:"
for worker_node_id in `ibmcloud oc workers  --cluster $CLUSTER |grep '^kube' | cut -d ' ' -f 1` ; do 

    echo "ibmcloud ks storage attachments -c $CLUSTER -w $worker_node_id"
    ibmcloud ks storage attachments -c $CLUSTER -w $worker_node_id

done
