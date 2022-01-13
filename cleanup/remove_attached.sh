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


echo "Wiping Portworx from cluster: $CLUSTER"


curl  -fSsL https://raw.githubusercontent.com/IBM/ibmcloud-storage-utilities/master/px-utils/px_cleanup/px-wipe.sh | bash -s -- --talismanimage icr.io/ext/portworx/talisman --talismantag 1.1.0 --wiperimage icr.io/ext/portworx/px-node-wiper --wipertag 2.5.0 --force

echo "removing the portworx helm from the cluster"
_rc=0
helm_release=$(helm ls -a --output json | jq -r '.[]|select(.name=="portworx") | .name')
if [ -z "$helm_release" ];
then
  echo "Unable to find helm release for portworx.  Ensure your helm client is at version 3 and has access to the cluster.";
else
  helm uninstall portworx || _rc=$?
  if [ $_rc -ne 0 ]; then
    echo "error removing the helm release"
    exit 1;
  fi
fi

echo "removing all portworx storage classes"
kubectl get sc -A | grep portworx | awk '{ print $1 }' > sc.tmp
while read in; do
  kubectl delete sc "$in"
done < sc.tmp
rm -rf sc.tmp

echo "removing portworx artifacts"
kubectl delete serviceaccount -n kube-system portworx-hook --ignore-not-found=true
kubectl delete clusterrole -n kube-system portworx-hook --ignore-not-found=true
kubectl delete clusterrolebinding -n kube-system portworx-hook --ignore-not-found=true

kubectl delete Service portworx-service -n kube-system --ignore-not-found=true
kubectl delete Service portworx-api -n kube-system --ignore-not-found=true

kubectl delete serviceaccount -n kube-system portworx-hook --ignore-not-found=true 
kubectl delete clusterrole portworx-hook --ignore-not-found=true

kubectl delete job -n kube-system talisman --ignore-not-found=true
kubectl delete serviceaccount -n kube-system talisman-account --ignore-not-found=true 
kubectl delete clusterrolebinding talisman-role-binding --ignore-not-found=true 
kubectl delete crd volumeplacementstrategies.portworx.io --ignore-not-found=true
kubectl delete configmap -n kube-system portworx-pvc-controller --ignore-not-found=true

kubectl delete secret -n default sh.helm.release.v1.portworx.v1 --ignore-not-found=true
