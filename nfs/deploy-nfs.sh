#!/bin/bash

# Based on https://rook.io/docs/nfs/v1.7/quickstart.html
# Manifests listed explicitly here to guarantee ordering

kubectl create -f nfs/crds.yaml
kubectl create -f nfs/operator.yaml
kubectl create -f nfs/rbac.yaml
kubectl create -f nfs/nfs.yaml
kubectl create -f nfs/sc.yaml
kubectl create -f nfs/pvc.yaml
