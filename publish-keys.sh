NAMESPACE="$1"
if [[ -z $1 ]]; then
    NAMESPACE=default
fi
echo Installing in namespace $NAMESPACE
kubectl -n $NAMESPACE create configmap authorized-keys-configmap \
"--from-literal=authorized_keys=$(cat ~/.ssh/*.pub)" --dry-run=client -o yaml | \
kubectl  -n $NAMESPACE apply -f -