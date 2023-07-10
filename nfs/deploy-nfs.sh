#!/bin/bash

kubectl create -f crds.yaml
kubectl create -f operator.yaml
kubectl create -f rbac.yaml
kubectl create -f nfs.yaml
kubectl create -f sc.yaml
kubectl create -f pvc.yaml
