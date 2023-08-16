#!/bin/bash
NAMESPACE="$1"
if [[ -z $1 ]]; then
    NAMESPACE=default
fi

kubectl -n $NAMESPACE create secret generic database-auth-secret \
--dry-run=client \
--from-literal=password=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32) \
-o yaml | \
kubectl -n $NAMESPACE apply -f -

kubectl -n $NAMESPACE create secret generic munge-key-secret \
--dry-run=client \
--from-literal=munge.key=$(dd if=/dev/urandom bs=1 count=1024 2>/dev/null | base64 -w 0) \
-o yaml | \
kubectl -n $NAMESPACE apply -f -

mkdir -p ./temphostkeys/etc/ssh
ssh-keygen -A -f ./temphostkeys
kubectl -n $NAMESPACE create secret generic host-keys-secret \
--dry-run=client \
--from-file=./temphostkeys/etc/ssh \
-o yaml | \
kubectl -n $NAMESPACE apply -f -
rm -rf ./temphostkeys

OOD_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)

kubectl -n $NAMESPACE create secret generic htdbm-secret \
--dry-run=client \
--from-literal=password=$OOD_PASS \
-o yaml | \
kubectl -n $NAMESPACE apply -f -

echo "Open Ondemand Credentials:"
echo "Username: rocky"
echo "Password: $OOD_PASS"
OOD_PASS=""
