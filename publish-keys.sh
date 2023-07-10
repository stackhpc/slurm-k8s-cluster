kubectl create configmap authorized-keys-configmap \
"--from-literal=authorized_keys=$(cat ~/.ssh/*.pub)" --dry-run=client -o yaml | \
kubectl apply -f -