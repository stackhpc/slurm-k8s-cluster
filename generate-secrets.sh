#!/bin/bash

mkdir -p ./temphostkeys/etc/ssh
ssh-keygen -A -f ./temphostkeys
kubectl create secret generic host-keys-secret \
--dry-run=client \
--from-file=./temphostkeys/etc/ssh \
-o yaml | \
kubectl apply -f -
rm -rf ./temphostkeys
