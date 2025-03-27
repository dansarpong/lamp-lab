#!/bin/bash

# Enable error handling
set -e

# Status file to track progress
STATUS_FILE="tracker.log"

# Function to mark a step as completed
mark_done() {
    echo "$1" >> $STATUS_FILE
}

# Function to check if a step has already been completed
is_done() {
    grep -q "$1" $STATUS_FILE 2>/dev/null
}

echo "Starting cleanup process..."

# Set AWS credentials and variables if not already set (uncomment if needed)
# AWS_PROFILE=<profile_name>
# DB_CREDS_SECRET_NAME=<secret_name>
# ECR_NAME=<ecr_name>
# EMAIL=<email>

# Ensure status file exists
if [ ! -f "$STATUS_FILE" ]; then
    echo "Error: tracker.log not found indicating resources were not deployed with deploy.sh"
    exit 1
fi

# Step 1: Destroy Terraform Resources
if ! is_done "TERRAFORM_DESTROYED"; then
    echo "Destroying Terraform-managed resources..."
    terraform destroy -var "image=$REPOSITORY_URI:latest" -var "email=$EMAIL" -auto-approve
    mark_done "TERRAFORM_DESTROYED"
    echo "Terraform resources destroyed."
else
    echo "Skipping Terraform destruction (already done)."
fi

# Step 2: Delete AWS Secrets Manager Secret
if ! is_done "SECRET_DELETED"; then
    echo "Deleting AWS Secrets Manager secret..."
    aws secretsmanager delete-secret \
        --profile $AWS_PROFILE \
        --secret-id $DB_CREDS_SECRET_NAME \
        --force-delete-without-recovery
    mark_done "SECRET_DELETED"
    echo "Secret deleted."
else
    echo "Skipping secret deletion (already done)."
fi

# Step 3: Delete ECR Repository
if ! is_done "ECR_DELETED"; then
    echo "Deleting ECR repository..."
    aws ecr-public delete-repository \
        --profile $AWS_PROFILE \
        --region us-east-1 \
        --repository-name $ECR_NAME \
        --force
    mark_done "ECR_DELETED"
    echo "ECR repository deleted."
else
    echo "Skipping ECR deletion (already done)."
fi

rm -f $STATUS_FILE
echo "Cleanup completed successfully!"