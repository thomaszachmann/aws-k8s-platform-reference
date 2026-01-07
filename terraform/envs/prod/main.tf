terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "aws-k8s-platform"
      ManagedBy   = "terraform"
    }
  }
}

# Network Module
module "network" {
  source = "../../modules/network"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  tags = var.tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  cluster_name = var.cluster_name
  tags         = var.tags
}

# Security Module
module "security" {
  source = "../../modules/security"

  cluster_name = var.cluster_name
  vpc_id       = module.network.vpc_id
  vpc_cidr     = module.network.vpc_cidr

  tags = var.tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name                 = var.cluster_name
  cluster_version              = var.cluster_version
  subnet_ids                   = concat(module.network.private_subnet_ids, module.network.public_subnet_ids)
  cluster_role_arn             = module.iam.cluster_role_arn
  node_group_role_arn          = module.iam.node_group_role_arn
  cluster_security_group_id    = module.security.cluster_security_group_id
  node_security_group_id       = module.security.node_security_group_id
  node_groups                  = var.node_groups
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  tags = var.tags

  depends_on = [
    module.network,
    module.iam,
    module.security
  ]
}

# Outputs
output "cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.network.public_subnet_ids
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
