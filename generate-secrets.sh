#!/bin/bash

mkdir -p ./temphostkeys/etc/ssh
ssh-keygen -A -f ./temphostkeys
kubectl create secret generic host-keys-secret \
--dry-run=client \
--from-file=./temphostkeys/etc/ssh \
-o yaml | \
kubectl apply -f -
rm -rf ./temphostkeys

OOD_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

kubectl create secret generic htdbm-secret \
--dry-run=client \
--from-literal=password=$OOD_PASS \
-o yaml | \
kubectl apply -f -

echo "Open Ondemand Credentials:"
echo "Username: rocky"
echo "Password: $OOD_PASS"
OOD_PASS=""