#!/bin/bash
#create certificate for lancelot
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

#create roles and bind them to lancelot
kubectl create namespace round-table

kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods,pods/log
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create role deployment-admin -n round-table --verb='*' --resource=deployments

kubectl create rolebinding -n round-table pod-reader --clusterrole=pod-reader --group=knights
kubectl create rolebinding -n round-table deployment-admin --role=deployment-admin --group=knights
kubectl create clusterrolebinding node-reader --clusterrole=node-reader --user=lancelot

#create a context for lancelot and use it
kubectl config set-credentials lancelot --client-certificate=lancelot.crt --client-key=lancelot.key --embed-certs
kubectl config set-context lancelot@kubernetes --user=lancelot --cluster=kubernetes --namespace=round-table
kubectl config use-context lancelot@kubernetes

#create a new admin certificate (dragon.crt) using lancelot's limited account
openssl genrsa -out dragon.key 2048
openssl req -new -key dragon.key -out dragon.csr -subj "/CN=dragon/O=system:masters"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: dragon
  name: dragon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dragon
  template:
    metadata:
      labels:
        app: dragon
    spec:
      tolerations:
      - key: ""
        operator: "Exists"
        effect: "NoSchedule"
      nodeSelector:
        node-role.kubernetes.io/master: ""
      containers:
      - image: alpine
        name: alpine
        command:
        - sh
        - -c
        - apk upgrade; apk add openssl; echo $(cat dragon.csr | base64 -w0) > /tmp/dragon.csr; cat /tmp/dragon.csr | base64 -d | openssl x509 -req -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out /tmp/dragon.crt -days 365; cat /tmp/dragon.crt; sleep 3600;
        volumeMounts:
        - mountPath: /etc/kubernetes/pki
          name: k8s-certs
        - mountPath: /tmp
          name: tmp
      volumes:
      - name: k8s-certs
        hostPath:
          path: /etc/kubernetes/pki
      - name: tmp
        emptyDir: {}
EOF

sleep 20
kubectl logs deployments/dragon | grep "BEGIN CERTIFICATE" -A 50 > dragon.crt
kubectl config set-credentials dragon --client-certificate=dragon.crt --client-key=dragon.key --embed-certs

#create a context for dragon and use it
kubectl config set-context dragon@kubernetes --user=dragon --cluster=kubernetes
kubectl config use-context dragon@kubernetes