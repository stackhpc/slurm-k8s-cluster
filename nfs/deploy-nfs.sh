#!/bin/bash

# Based on https://rook.io/docs/nfs/v1.7/quickstart.html
# Manifests listed explicitly here to guarantee ordering

kubectl create -f crds.yaml
kubectl create -f operator.yaml
kubectl create -f rbac.yaml
kubectl create -f nfs.yaml
kubectl create -f sc.yaml
kubectl create -f pvc.yaml
