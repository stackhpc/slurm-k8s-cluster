#!/bin/bash
NAMESPACE="$1"
if [[ -z $1 ]]; then
    NAMESPACE=default
fi

kubectl -n $NAMESPACE create secret generic database-auth-secret \
--dry-run=client \
--from-literal=password=abcdefghijklmnopqrstuvwxyz123456 \
-o yaml | \
kubectl -n $NAMESPACE apply -f -

kubectl -n $NAMESPACE create secret generic munge-key-secret \
--dry-run=client \
--from-literal=munge.key=$(dd if=/dev/urandom bs=1 count=1024 2>/dev/null | base64) \
-o yaml | \
kubectl -n $NAMESPACE apply -f -