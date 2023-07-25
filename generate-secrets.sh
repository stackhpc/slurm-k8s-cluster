#!/bin/bash

kubectl create secret generic database-auth-secret \
--dry-run=client \
--from-literal=password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32) \
-o yaml | \
kubectl apply -f -

kubectl create secret generic munge-key-secret \
--dry-run=client \
--from-literal=munge.key=$(dd if=/dev/urandom bs=1 count=1024 2>/dev/null | base64 -w 0) \
-o yaml | \
kubectl apply -f -

cp $KUBECONFIG slurm-cluster-chart/files/kubectl
