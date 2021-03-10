#!/bin/bash

_MY_DIR=~/krb5
mkdir -p $_MY_DIR
_KDC=$(kubectl get pod -l app=hdfs-krb5,release=my-hdfs --no-headers  \
    -o name | cut -d/ -f2)
kubectl cp $_KDC:/etc/krb5.conf $_MY_DIR/tmp/krb5.conf
kubectl create configmap my-hdfs-krb5-config  \
  --from-file=$_MY_DIR/tmp/krb5.conf


_HOSTS=$(kubectl get nodes  \
    -o=jsonpath='{.items[*].status.addresses[?(@.type == "Hostname")].address}')

_HOSTS+=$(kubectl describe configmap my-hdfs-config |  \
      grep -A 1 -e dfs.namenode.rpc-address.hdfs-k8s  \
          -e dfs.namenode.shared.edits.dir |
      grep "<value>" |
      sed -e "s/<value>//"  \
          -e "s/<\/value>//"  \
          -e "s/:8020//"  \
          -e "s/qjournal:\/\///"  \
          -e "s/:8485;/ /g"  \
          -e "s/:8485\/hdfs-k8s//")


_SECRET_CMD="kubectl create secret generic my-hdfs-krb5-keytabs"

for _HOST in $_HOSTS
do
    kubectl exec $_KDC -- kadmin.local -q  \
        "addprinc -randkey hdfs/$_HOST@MYCOMPANY.COM"
      kubectl exec $_KDC -- kadmin.local -q  \
        "addprinc -randkey HTTP/$_HOST@MYCOMPANY.COM"
      kubectl exec $_KDC -- kadmin.local -q  \
        "ktadd -norandkey -k /tmp/$_HOST.keytab hdfs/$_HOST@MYCOMPANY.COM HTTP/$_HOST@MYCOMPANY.COM"
      kubectl cp $_KDC:/tmp/$_HOST.keytab $_MY_DIR/tmp/$_HOST.keytab
      _SECRET_CMD+=" --from-file=$_MY_DIR/tmp/$_HOST.keytab"
done

$_SECRET_CMD