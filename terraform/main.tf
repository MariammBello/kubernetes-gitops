# VPC Configuration
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

#Input module requirements

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 3), cidrsubnet(var.vpc_cidr, 8, 4)]
  enable_nat_gateway   = true
  single_nat_gateway   = true #this is default true in registry so to clean code it may not be a necessary add on
  enable_dns_hostnames = true #this is default true in registry so to clean code it may not be a necessary add on

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    main = {
      desired_size = var.node_group_desired_size
      min_size     = 1
      max_size     = 3

      instance_types = var.node_group_instance_types
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "development"
    Terraform   = "true"
  }
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.46.7"  # Specify the version you want to use
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [<<-EOT
    server:
      service:
        type: LoadBalancer
      extraArgs:
        - --insecure
    configs:
      params:
        server.insecure: true
    dex:
      enabled: false
    notifications:
      enabled: false
    EOT
  ]

  depends_on = [
    module.eks
  ]
}