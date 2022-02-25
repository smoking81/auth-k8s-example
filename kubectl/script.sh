#!/bin/bash
openssl genrsa -out lancelot.key 2048
openssl req -new -key lancelot.key -out lancelot.csr -subj "/CN=lancelot/O=knights"

echo "apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: lancelot
spec:
  request: $(cat lancelot.csr | base64 -w 0)
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth" | kubectl create -f -

kubectl certificate approve lancelot
kubectl get csr lancelot -o jsonpath='{.status.certificate}' | base64 --decode > lancelot.crt

#following line is optional. I suppose you will use your default "kubernetes" cluster in the following
#kubectl config set-cluster camelot --certificate-authority=ca.crt --server=https://<DNS-name>:6443 --embed-certs

kubectl create namespace round-table

kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods,pods/log
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create role deployment-admin -n round-table --verb='*' --resource=deployments

kubectl create rolebinding -n round-table pod-reader --clusterrole=pod-reader --group=knights
kubectl create rolebinding -n round-table deployment-admin --role=deployment-admin --group=knights
kubectl create clusterrolebinding node-reader --clusterrole=node-reader --user=lancelot

kubectl config set-credentials lancelot --client-certificate=lancelot.crt --client-key=lancelot.key --embed-certs
kubectl config set-context lancelot@kubernetes --user=lancelot --cluster=kubernetes --namespace=round-table
kubectl config use-context lancelot@kubernetes
