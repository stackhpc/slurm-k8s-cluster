#!/bin/bash

kubectl delete -f web-service.yaml
kubectl delete -f web-rc.yaml
kubectl delete -f busybox-rc.yaml
kubectl delete -f pvc.yaml
kubectl delete -f pv.yaml
kubectl delete -f nfs.yaml
kubectl delete -f nfs-xfs.yaml
kubectl delete -f nfs-ceph.yaml
kubectl delete -f rbac.yaml
kubectl delete -f psp.yaml
kubectl delete -f scc.yaml # if deployed
kubectl delete -f operator.yaml
kubectl delete -f webhook.yaml # if deployed
kubectl delete -f crds.yaml
