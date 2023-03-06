sleep 5
kubectl exec vault-0 -n vault -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
sleep 5

export VAULT_UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
kubectl exec vault-0 -nvault -- vault operator unseal $VAULT_UNSEAL_KEY
sleep 5

export CLUSTER_ROOT_TOKEN=$(cat cluster-keys.json | jq -r ".root_token")
kubectl exec vault-0 -n vault -- vault login $CLUSTER_ROOT_TOKEN
sleep 5

kubectl exec vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal:8200
sleep 5

kubectl exec vault-1 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
sleep 5

kubectl exec vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal:8200
sleep 5

kubectl exec vault-2 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
sleep 5

kubectl exec vault-0 -n vault -- vault operator raft list-peers

kubectl exec vault-0 -n vault -it -- sh -c "vault secrets enable -path=secret kv-v2"

kubectl exec vault-0 -n vault -it -- sh -c "vault auth enable kubernetes"
k8s_host="$(kubectl exec vault-0 -n vault -- printenv | grep KUBERNETES_PORT_443_TCP_ADDR | cut -f 2- -d "=" | tr -d " ")"
k8s_port="443"
k8s_cacert="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)"
secret_name="$(kubectl get serviceaccount vault -n vault -o jsonpath='{.secrets[0].name}')"
tr_account_token="$(kubectl get secret ${secret_name} -n vault -ojsonpath='{.data.token}' | base64 --decode)"
kubectl exec vault-0 -n vault -it -- sh -c "vault write auth/kubernetes/config token_reviewer_jwt='${tr_account_token}' kubernetes_host='https://${k8s_host}:${k8s_port}' kubernetes_ca_cert='{k8s_cacert}'   disable_issuer_verification=true"