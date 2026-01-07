# AWS EKS Terraform Infrastructure

This directory contains Terraform infrastructure as code for deploying a production-ready Amazon EKS (Elastic Kubernetes Service) cluster on AWS.

## Architecture Overview

The infrastructure is organized into modular components:

- **Network Module** (`modules/network/`): VPC, subnets, NAT gateways, and routing
- **IAM Module** (`modules/iam/`): IAM roles and policies for EKS cluster and nodes
- **Security Module** (`modules/security/`): Security groups for cluster and node communication
- **EKS Module** (`modules/eks/`): EKS cluster, node groups, and add-ons

## Project Structure

```
terraform/
├── modules/
│   ├── network/        # VPC, subnets, NAT gateway
│   ├── iam/            # IAM roles and policies
│   ├── security/       # Security groups
│   └── eks/            # EKS cluster and node groups
├── envs/
│   ├── dev/            # Development environment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── backend.tf
│   └── prod/           # Production environment
│       ├── main.tf
│       ├── variables.tf
│       └── backend.tf
└── README.md
```

## Features

- **Multi-AZ Deployment**: Resources deployed across 3 availability zones for high availability
- **Private Node Groups**: Worker nodes in private subnets for enhanced security
- **NAT Gateways**: Secure outbound internet access for private subnets
- **OIDC Provider**: Configured for IRSA (IAM Roles for Service Accounts)
- **EKS Add-ons**: Pre-configured with vpc-cni, kube-proxy, and CoreDNS
- **EBS CSI Driver Support**: IAM policies for persistent volume management
- **Security Groups**: Properly configured for cluster and node communication
- **CloudWatch Logging**: Control plane logging enabled

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. **Terraform** (>= 1.5.0) installed
   ```bash
   terraform --version
   ```

3. **kubectl** installed for cluster access
   ```bash
   kubectl version --client
   ```

4. **AWS Credentials** with appropriate permissions for:
   - VPC and networking resources
   - EKS cluster creation
   - IAM role and policy management
   - EC2 instances and security groups

## Deployment Instructions

### Step 1: Set Up Backend (Optional but Recommended)

For production use, configure remote state storage in S3:

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

Then uncomment and update the backend configuration in `envs/{dev,prod}/backend.tf`.

### Step 2: Deploy Development Environment

```bash
# Navigate to dev environment
cd envs/dev

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

The deployment will create:
- 1 VPC with public and private subnets across 3 AZs
- 1 NAT Gateway (single for cost optimization in dev)
- EKS cluster version 1.31
- Node group with 2 t3.medium instances
- All necessary IAM roles and security groups

### Step 3: Configure kubectl Access

After successful deployment, configure kubectl:

```bash
# Get the configuration command from Terraform output
terraform output configure_kubectl

# Or run directly
aws eks update-kubeconfig --region eu-central-1 --name aws-k8s-platform-dev

# Verify access
kubectl get nodes
kubectl get pods -A
```

### Step 4: Deploy Production Environment (When Ready)

```bash
# Navigate to prod environment
cd envs/prod

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

Production environment differs from dev:
- 3 NAT Gateways (one per AZ) for high availability
- Larger node groups: 3 t3.large instances
- Private endpoint only (no public access to API server)
- Larger disk sizes (50GB vs 20GB)

## Configuration Variables

Key variables you can customize in `variables.tf`:

| Variable | Description | Default (Dev) | Default (Prod) |
|----------|-------------|---------------|----------------|
| `aws_region` | AWS region | eu-central-1 | eu-central-1 |
| `cluster_name` | EKS cluster name | aws-k8s-platform-dev | aws-k8s-platform-prod |
| `cluster_version` | Kubernetes version | 1.31 | 1.31 |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 | 10.1.0.0/16 |
| `single_nat_gateway` | Use single NAT | true | false |
| `node_groups` | Node group config | 2x t3.medium | 3x t3.large |

## Cost Optimization

### Development Environment
- Uses a single NAT Gateway (~$32/month)
- Smaller instance types (t3.medium)
- Fewer nodes (min 1, desired 2)

### Production Environment
- Multiple NAT Gateways for HA (~$96/month)
- Larger instances (t3.large)
- More nodes for reliability (min 2, desired 3)

## Scaling the Cluster

### Manual Scaling

Edit the `node_groups` variable in `variables.tf`:

```hcl
node_groups = {
  general = {
    desired_size   = 5  # Change this
    max_size       = 10
    min_size       = 2
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 20
  }
}
```

Then apply:
```bash
terraform apply
```

### Adding Node Groups

You can add multiple node groups for different workload types:

```hcl
node_groups = {
  general = {
    desired_size   = 2
    max_size       = 4
    min_size       = 1
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 20
  }
  compute = {
    desired_size   = 1
    max_size       = 5
    min_size       = 0
    instance_types = ["c5.xlarge"]
    capacity_type  = "SPOT"
    disk_size      = 50
  }
}
```

## Outputs

After deployment, Terraform provides these outputs:

- `cluster_id`: EKS cluster ID
- `cluster_endpoint`: API server endpoint
- `cluster_name`: Name of the cluster
- `cluster_oidc_issuer_url`: OIDC provider URL for IRSA
- `vpc_id`: VPC ID
- `private_subnet_ids`: Private subnet IDs
- `public_subnet_ids`: Public subnet IDs

View outputs:
```bash
terraform output
```

## Troubleshooting

### Issue: Terraform Init Fails

**Solution**: Ensure AWS credentials are properly configured:
```bash
aws sts get-caller-identity
```

### Issue: Node Groups Not Ready

**Solution**: Check node status and events:
```bash
kubectl get nodes
kubectl describe nodes
```

### Issue: Cannot Access Cluster

**Solution**: Update kubeconfig:
```bash
aws eks update-kubeconfig --region eu-central-1 --name aws-k8s-platform-dev
```

### Issue: Pods Cannot Pull Images

**Solution**: Verify IAM role has ECR permissions:
```bash
kubectl describe pod <pod-name>
```

## Cleanup

To destroy all resources:

```bash
# In the environment directory (dev or prod)
terraform destroy
```

**Warning**: This will delete all resources including the EKS cluster, VPC, and all data.

## Security Considerations

1. **API Server Access**: Production uses private endpoint only
2. **Node Security**: Nodes in private subnets with no public IPs
3. **Security Groups**: Minimal required access configured
4. **IAM Roles**: Principle of least privilege applied
5. **Encryption**: Enable encryption at rest for EBS volumes
6. **Secrets**: Use AWS Secrets Manager or Parameter Store for sensitive data
7. **Network Policies**: Implement Kubernetes network policies for pod-to-pod security

## Next Steps

After deploying the cluster:

1. Install essential add-ons:
   - AWS Load Balancer Controller
   - EBS CSI Driver
   - Cluster Autoscaler
   - Metrics Server

2. Set up monitoring:
   - CloudWatch Container Insights
   - Prometheus and Grafana

3. Configure logging:
   - FluentBit or Fluentd
   - CloudWatch Logs

4. Deploy applications using the `kubernetes/` directory

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS EKS documentation
3. Create an issue in the repository
