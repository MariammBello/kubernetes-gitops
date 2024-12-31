# Kubernetes Infrastructure Migration Project

## Overview
This project demonstrates the migration of an on-premises Kubernetes infrastructure to the cloud, implementing best practices in container orchestration, monitoring, and DevOps methodologies.

## Project Structure
```
.
├── kubernetes/           # Kubernetes manifests
│   ├── base/            # Base configurations
│   └── overlays/        # Environment-specific overlays
├── monitoring/          # Monitoring configurations
│   ├── prometheus/      # Prometheus configurations
│   └── grafana/         # Grafana dashboards
├── terraform/           # Infrastructure as Code
├── docs/               # Project documentation
└── scripts/            # Utility scripts
```

## Features
- 🚀 Kubernetes cluster setup and management
- 📊 Prometheus & Grafana monitoring stack
- 🔐 Security implementations with RBAC
- 🔄 CI/CD pipeline with GitHub Actions
- 📦 GitOps with ArgoCD
- ☁️ Cloud migration strategy

## Prerequisites
- Docker Desktop
- kubectl
- Helm
- AWS CLI (for cloud migration)
- Terraform

## Getting Started
1. Clone the repository
2. Follow setup instructions in `docs/setup.md`
3. Review the architecture in `docs/architecture.md`

## Documentation
- [Setup Guide](docs/setup.md)
- [Architecture Overview](docs/architecture.md)
- [Monitoring Guide](docs/monitoring.md)
- [Security Implementation](docs/security.md)
- [Migration Strategy](docs/migration.md)

## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Onprem to  cloud, step by step
Accessing the cluster using a node in the cluster (not best practice, but it is possible)
1.Provde ssh key to connect to PC
To get key use
 cat ~/.ssh/id_rsa.pub
Copy and give the internal unit 
2. Internal Adds user key to the available compute resource
To add:
sudo nano ~/.ssh/authorized_keys
3. User: ssh into the machine once access was granted
ssh ubuntu@102.223.37.32
Use -i where necessary (explain when I is necessary)
4. Internal guys: Join the microk8s group to have access to the cluster
sudo usermod -a -G microk8s ubuntu (see microk8s documentation)
5. Ensure directory exists for kube
sudo mkdir -p ~/.kube
6. Run the access command 
sudo chown -R ubuntu ~/.kube~
After this, reload the user groups either via a reboot or by running ```newgrp microk8s```
7. MicroK8s uses a namespaced kubectl command to prevent conflicts with any existing installs of kubectl. If you don’t have an existing install, it is easier to add an alias (append to ~/.bash_aliases) like this:
```alias kubectl='microk8s kubectl'```
Its necessary to find out what alias is used in the new environment to ensure kubectl command works. refresh with ```source ~/.bash_aliases``` to ensure the alias is set
8. Confirm kubectl command is available
9. User: To know what is running on the cluster, we use kubectl. ```kubectl get all -A``` This gets all the resources in the cluster (and namespaces), including the ones that are not running, such as the kube-system resources that are used for the cluster.
10. check server info with ```kubectl get nodes```
11.describe the cluster ```kubectl describe nodes``` or the specific node ```kubectl describe node <node-name>``` 
12. bonus command on getting the cluster info ```kubectl get nodes -o wide```

## ALternative method of accessing the cluster and discovering the cluster size and node size before installing monitoring tools.

 (Accessing the cluster with kubeconfig since we are now trying to work on AWS or any CSP)
The initial steps gave access to a node, wich was used to access the cluster. Every kubernetes cluster has a kubeconfig file. This file contains the information necessary to access the cluster.

1. Another way is to access the clusster using the kubeconfig file. To access the cluster, we need to create a kubeconfig file. ```microk8s config > ~/.kube/config```
2. copy kubeconfig to the developer local machine. 
3. update kubeconfig with new cluster connection information. 
4. Access the cluster using the kubeconfig file. ```export KUBECONFIG="G:\My Drive\Msft surface 9\Desktop\kubernetes\CascadeProjects\windsurf-project\onprem_cluster_kubeconfig.yaml"``` this sets kubectl to use the ephemeral clusters kubeconfigfile, so that kubectl can access the cluster. A longer more permanent solution would be to add the new kubeconfig file to the global kubeconfig file. ``` ~/.kube/config``` and determine which cluster to use using the ```kubectl config get-contexts``` which would show the name of the cluster and select using ```kubectl config use-context {name of the cluster}``` (Research how to merge kubeconfig files).
5.confirm the cluster is accessible using ```kubectl get all -A```

Part C (Installing the monitoring tools for reviewing the nodes within the cluster). 
We need to work with monitoring tools like kubepromstack(Kubernetes Prometheus Stack that comprises of:
- Prometheus
- Grafana
- Alertmanager) 
6. Install helm using chocolatey if not installed ```choco install kubernetes-helm```
7. Add the kubepromstack helm chart repository gotten from https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
```helm repo add prometheus-community https://prometheus-community.github.io/helm-charts```
and update it with ```helm repo update```
8. Install the helm chart ```helm install kubepromstack prometheus-community/kube-prometheus-stack```
9. run ```kubectl get all -A``` to confirm the helm chart is installed and see the pods that are running
10. change grafana service to nodeport ```kubectl patch service kubepromstack-grafana  -p '{"spec": {"type": "NodePort"}}'``` we are doing this because the service type was clusterIP which does not allow external access, so we are switching it to nodeport.
11. to access the grafana service, we can first get the node port using ```kubectl get service kubepromstack-grafana``` in combination with the node IP using ```kubectl get nodes -o wide``` a sample output would look like this:
```102.223.37.32:31064``` where the number first number is the node IP and the second is the service node port
12. Ensure/confirm the security group allows access to the node port and login with the default credentials username ```admin``` and password ```prom-operator```
13. if the credentials admin/admin are not available, use the credentials from the helm chart by generically running ```kubectl get secret --namespace default kubepromstack-grafana -o yaml```. Then get the specific credentials using the following command and decode the password by running this

```kubectl get secret --namespace default kubepromstack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo```
where ```.data.admin-password``` is one ofthe specific credential we are looking for. Similar to be done for .```data.admin-user```

14 Aftter viewing the grafana dashboard, we can now move on to the next Steps within AWS
1. create EKS cluster (we created one called on-prem-practice-cluster)
2. Add node groups to the cluster
3. The cluster and node size is informed by the grafana dashboard output we created which monitors the applications resource usage (Memory and CPU), 
4. Based on the grafana dashboard output, in this exercise, we then create the node groups with t3.micro instances and add them to the cluster.
5. Once you create your cluster with the specified node groups, you can then add and access the cluster using the kubeconfig file generated by the EKS cluster using the following command
```aws eks --region eu-north-1 update-kubeconfig --name {name of the cluster}```. 
Note: ensure you return to the default kubeconfig file in the file location ```~/.kube/config``` , since you had to overide the default kubeconfig file to connect to the onpremise cluster using ````export KUBECONFIG="G:\My Drive\Msft surface 9\Desktop\kubernetes\CascadeProjects\windsurf-project\onprem_cluster_kubeconfig.yaml"```in your terminal. To revert back lets remove the override by running ```export KUBECONFIG=""```
6. Now explore the eks cluster using ```kubectl get all -A```


questions i have to any company i work for  
- are clusters set up by the environments. Like dev, staging, prod, per team
- design definitions - clusters, namespaces eg (during version changes, they can be tested on a lower environment like staging before going to production)
- find out what apps are running and their specs, eg the frontend app cpu and RAM, this represents the requirement for one replica. This can be found using a monitoring tool, or developerr documentation/conversation
- what is the cluster size? and what is the node size?
- Check instance types on target provider, eg at aws.amazon.com/ec2/instance-types/
- what is the cluster size? and what is the node size? then distribute them accordingly. 
create nodes in the CSP in an effectively distribued way, eg per app or more than node to an app to ensure high availability.

1. install argocd in the cluster
kubectl create namespace argocd
install using helm 
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```helm install argocd argo/argo-cd```

or install using the manifest 
```https://raw.githubusercontent.com/argoproj/argo-cd/v2.14.0-rc3/manifests/install.yaml```

2. Access the ui
- First check the argocd svc by running ```kubectl get services -n argocd``` in the namespace

- Either imperatively change the service clusterIP to NodePort
```kubectl patch svc argocd-server -p '{"spec": {"type": "NodePort"}}'```
or Declaratively by editing the service file`to change re argocd-server from cluster IP to nodeport
``kubectl edit svc argocd-server -n argocd```

or you can locally do a portforwarding to your local device by running
```kubectl port-forward svc/argocd-server -n argocd 8080:443```

3. Get the credentials to Login to the argocd ui (username is admin)
```kubectl -n argocd get secret ```  This lists all the secrets in the argocd namespace.
```kubectl -n argocd get secret argocd-initial-admin-secret -o json``` This retrieves the full JSON representation of the specified secret in the argocd namespace.
```kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" ``` his extracts only the password field from the secret, which is base64-encoded.
```kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo``` Extracts the base64-encoded password from the secret. Pipes it to base64 --decode to decode the password. Adds an echo at the end for a clean output.

4. Once logged into the ui, you can update the password

5. You can also do this on the cli 


further research 
learn terraform modules (read documentation on modules)

