# Kubectl vs terraform
You can choose to create the k8s objects (plus certificates) either with kubectl or with terraform.

# kubectl
Make sure you have the permissions to execute the script.sh and run the script. Your *kubeconfig* will be automatically edited and your context switched.

# Terraform script
If you want to use terraform, make sure you are happy with my var defaults within *terraform.tfvars* and run the following command in the *terraform* directory:

`terraform init`

`terraform apply`

Terraform will not edit your *kubeconfig*, so you must add the credentials and the new context manually (i.e. with `kubectl config`)