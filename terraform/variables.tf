variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"  # Change this to your preferred region
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-practice-eks-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_group_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}