# Backend configuration for Terraform state
#
# Before using this backend, you need to create:
# 1. An S3 bucket for storing Terraform state
# 2. A DynamoDB table for state locking
#
# To create these resources, run the following AWS CLI commands:
#
# aws s3api create-bucket \
#   --bucket your-terraform-state-bucket \
#   --region eu-central-1 \
#   --create-bucket-configuration LocationConstraint=eu-central-1
#
# aws s3api put-bucket-versioning \
#   --bucket your-terraform-state-bucket \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket your-terraform-state-bucket \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region eu-central-1
#
# Then uncomment the backend configuration below and update the bucket name:

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks/prod/terraform.tfstate"
#     region         = "eu-central-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }
