# Setting Up EKS with Terraform

## Overview
Terraform is an Infrastructure as Code (IaC) tool that allows us to define and provision infrastructure in a declarative way. We're using it to create an EKS (Elastic Kubernetes Service) cluster on AWS.

## Project Structure
```
terraform/
├── main.tf         # Main configuration file
├── variables.tf    # Variable definitions
├── outputs.tf      # Output definitions
└── providers.tf    # Provider configurations
```

## Key Components Explained

### 1. Provider Configuration (providers.tf)
- Defines which cloud providers and versions we're using
- AWS provider for creating AWS resources
- Kubernetes provider for managing Kubernetes resources
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### 2. Variables (variables.tf)
- Defines customizable inputs for our infrastructure
- Makes our code reusable and flexible
- Key variables:
  - `aws_region`: Where to create resources
  - `cluster_name`: Name of our EKS cluster
  - `vpc_cidr`: Network range for our VPC
  - `cluster_version`: Kubernetes version
  - `node_group_instance_types`: EC2 instance types for worker nodes

### 3. Main Configuration (main.tf)
Contains two main modules:

#### VPC Module
- Creates a Virtual Private Cloud (VPC)
- Sets up public and private subnets
- Configures NAT Gateway for private subnet internet access
- Tags subnets for EKS use

#### EKS Module
- Creates the EKS cluster
- Sets up node groups for worker nodes
- Configures security groups and IAM roles
- Enables public access to the cluster API

### 4. Outputs (outputs.tf)
- Provides important information after creation
- Includes:
  - Cluster endpoint
  - Security group IDs
  - Cluster name
  - Certificate authority data

## Usage Instructions

### Prerequisites
1. AWS CLI installed and configured
2. Terraform installed (version 1.0 or later)
3. kubectl installed

### Steps to Deploy

1. Configure AWS Credentials:
```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region
# - Default output format
```

2. Initialize Terraform:
```bash
cd terraform
terraform init
```

3. Review the Plan:
```bash
terraform plan
```

4. Apply the Configuration:
```bash
terraform apply
```

5. Configure kubectl:
```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

### Cost Considerations
- Using t3.medium instances to minimize costs
- 2 nodes by default
- NAT Gateway costs (~$32/month)
- EKS cluster costs ($0.10/hour)

### Best Practices Implemented
1. **Modularity**
   - Separate files for different concerns
   - Using official AWS modules

2. **Security**
   - Private subnets for worker nodes
   - Controlled public access
   - Proper IAM roles and policies

3. **Networking**
   - Proper VPC configuration
   - Multiple availability zones
   - Public/private subnet separation

4. **Scalability**
   - Configurable node groups
   - Auto-scaling capabilities
   - Multiple AZ deployment

### Common Operations

1. **Scaling Nodes**
   - Modify `node_group_desired_size` in variables.tf
   - Run `terraform apply`

2. **Updating Kubernetes Version**
   - Update `cluster_version` variable
   - Run `terraform plan` to see changes
   - Run `terraform apply`

3. **Destroying Infrastructure**
```bash
terraform destroy  # Use with caution!
```

### Troubleshooting
1. **Common Issues**
   - VPC limits in the AWS account
   - IAM permission issues
   - Subnet capacity issues

2. **Debugging**
   - Check Terraform logs: `export TF_LOG=DEBUG`
   - AWS Console EKS dashboard
   - CloudWatch logs

### Next Steps
1. Argocd helm chart installation on the cluster using terraform
2. Configure GitOps to deploy existing manifests using argocd
3.Install Kubepromstack using argocd for monitoring and logging
4. Configure cluster autoscaling
5. Set up CI/CD pipelines
6. Implement backup solutions

## Configuring GitOps with ArgoCD

After installing ArgoCD using Terraform, we'll set up GitOps to manage our Kubernetes resources. This section covers how to configure ArgoCD to deploy our existing manifests.

### 1. Accessing ArgoCD UI

First, we need to access the ArgoCD UI and get the initial admin password:

```bash
# Get the ArgoCD server URL (if using LoadBalancer)
kubectl get svc argocd-server -n argocd

# If using LoadBalancer, wait for an external IP to be assigned
# If no LoadBalancer is available or you prefer local access, use port-forwarding within a different terminal
```kubectl port-forward svc/argocd-server -n argocd 8080:443```

# You can now access ArgoCD at https://localhost:8080 in your browser.

2. After setting up port-forwarding and accessing the ArgoCD UI at: https://localhost:8080
Login with:
   - Username: admin
   - Password: (use the password obtained from the secret)

# Get the initial admin password (username is admin)
```kubectl -n argocd get secret ```  #This lists all the secrets in the argocd namespace.
```kubectl -n argocd get secret argocd-initial-admin-secret -o json``` #This retrieves the full JSON representation of the specified secret in the argocd namespace.
```kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" ``` #This extracts only the password field from the secret, which is base64-encoded.
```kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo``` #Extracts the base64-encoded password from the secret. Pipes it to base64 --decode to decode the password. Adds an echo at the end for a clean output.

3. You might see a certificate warning in your browser - this is expected for the default self-signed certificate
4. After first login, it's recommended to change the admin password

Note: Keep the port-forwarding terminal window open while you need access to the UI. If you close it, you'll need to run the port-forward command again.

### 2. Organizing Manifests for GitOps

Structure your repository for GitOps:

```
kubernetes/
├── base/                    # Base manifests
│   ├── deployment.yaml      # Nginx deployment
│   └── service.yaml         # Nginx service
├── monitoring/              # Monitoring configurations
│   ├── prometheus/
│   │   └── config-map.yaml
│   └── grafana/
│       └── dashboard-config.yaml
└── overlays/               # Environment-specific configurations
    ├── dev/
    ├── staging/
    └── prod/
```

### 3. Creating ArgoCD Applications

There are two ways to create ArgoCD applications: through YAML manifests or using the ArgoCD CLI/UI.

#### Method 1: Using YAML Manifest

1. Create a directory for your ArgoCD applications:
```bash
mkdir -p kubernetes/applications
```

2. Create the application manifest (`kubernetes/applications/nginx-app.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:MariammBello/kubernetes-gitops.git  # Your repository URL
    targetRevision: main
    path: kubernetes/base
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Key fields explained:
- `metadata.name`: Name of your application in ArgoCD
- `metadata.namespace`: Must be `argocd` where ArgoCD is installed
- `spec.source.repoURL`: Your Git repository URL (HTTPS or SSH)
- `spec.source.path`: Path to your Kubernetes manifests in the repository
- `spec.destination.namespace`: Namespace where your application will be deployed
- `spec.syncPolicy.automated`: Enables automatic sync from Git to cluster

3. Apply the application:
```bash
kubectl apply -f kubernetes/applications/nginx-app.yaml
```

#### Method 2: Using ArgoCD CLI

If you prefer using the CLI:

1. Login to ArgoCD CLI:
```bash
argocd login localhost:8080
```

2. Create the application:
```bash
argocd app create nginx-app \
  --repo git@github.com:MariammBello/kubernetes-gitops.git \
  --path kubernetes/base \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

#### Verifying the Application

After creating the application, verify its status:

```bash
# Using kubectl
kubectl get applications -n argocd
kubectl get pods -n default  # To see deployed pods

# Using ArgoCD CLI
argocd app get nginx-app
argocd app sync nginx-app  # Manual sync if needed
```

The application status should show:
- `Healthy`: Application is running correctly
- `Synced`: Git state matches cluster state

#### Troubleshooting Application Creation

If the application isn't syncing:

1. Check application status:
```bash
kubectl describe application nginx-app -n argocd
```

2. View ArgoCD controller logs:
```bash
kubectl logs -n argocd deployment/argocd-application-controller
```

3. Common issues and solutions:
   - Repository not accessible: Check your Git URL and credentials
   - Path not found: Verify the path to your Kubernetes manifests
   - Invalid manifests: Ensure your YAML files are valid
   - Network issues: Check if ArgoCD can reach your Git repository

### 4. Setting Up Monitoring with ArgoCD

Create an Application for Prometheus monitoring:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/your-repo.git
    targetRevision: HEAD
    path: kubernetes/monitoring
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 5. Best Practices

1. **Repository Structure**
   - Keep base configurations separate from environment-specific ones
   - Use overlays for environment-specific changes
   - Store all configurations in Git

2. **Application Management**
   - Use automated sync policies for continuous deployment
   - Enable pruning to remove deleted resources
   - Enable self-healing to revert manual changes

3. **Security**
   - Use SSH or HTTPS with credentials for private repositories
   - Implement RBAC for different teams
   - Store sensitive data using Sealed Secrets or external secret management

4. **Monitoring**
   - Configure notifications for sync failures
   - Set up monitoring for ArgoCD itself
   - Use the ArgoCD metrics for Prometheus

### 6. Troubleshooting

Common issues and solutions:

1. **Sync Failed**
   - Check application logs: `kubectl logs -n argocd deployment/argocd-application-controller`
   - Verify Git credentials
   - Check manifest validity

2. **Access Issues**
   - Ensure correct RBAC permissions
   - Verify network connectivity to Git repository
   - Check ArgoCD service account permissions

3. **Resource Conflicts**
   - Use `kubectl describe` on conflicting resources
   - Check for naming conflicts
   - Verify resource quotas

### 7. Validation

Verify your GitOps setup:

```bash
# Check application status
kubectl get applications -n argocd

# Check sync status
argocd app get my-app

# View application logs
kubectl logs -n argocd deployment/argocd-application-controller
```
