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

echo "Starting deployment script..."

# Set essential credentials
export AWS_PROFILE=<profile_name>
export EMAIL=<email>
export DB_CREDS_SECRET_NAME=<db_secret_name>
export ECR_NAME=<ecr_name>
export DB_USER=<user>
export DB_PASSWORD=<password>

echo "AWS profile set to: $AWS_PROFILE"

# Ensure status file exists
touch $STATUS_FILE

# Step 1: Create DB credentials secret
if ! is_done "DB_SECRET_CREATED"; then
    echo "Creating DB credentials secret..."
    aws secretsmanager create-secret \
        --profile $AWS_PROFILE \
        --name $DB_CREDS_SECRET_NAME \
        --description "Credentials for my LAMP stack DB" \
        --secret-string "{\"username\": \"$DB_USER\", \"password\": \"$DB_PASSWORD\"}" \
        --tags Key=Lab,Value=LAMP

    mark_done "DB_SECRET_CREATED"
    echo "DB credentials secret created."
else
    echo "Skipping DB credentials creation (already done)."
fi

# Step 2: Create ECR repository
if ! is_done "ECR_CREATED"; then
    echo "Creating ECR repository..."
    ECR_RESPONSE=$(aws ecr-public create-repository \
        --profile $AWS_PROFILE \
        --region us-east-1 \
        --repository-name $ECR_NAME \
        --tags Key=Lab,Value=LAMP)

    # Extract repository URI
    REPOSITORY_URI=$(echo $ECR_RESPONSE | jq -r '.repository.repositoryUri')

    if [ -z "$REPOSITORY_URI" ]; then
        echo "Error: Failed to retrieve ECR repository URI."
        exit 1
    fi

    mark_done "ECR_CREATED"
    echo "ECR repository created: $REPOSITORY_URI"
else
    echo "Skipping ECR repository creation (already done)."
fi

# Step 3: Authenticate Docker
if ! is_done "DOCKER_AUTHENTICATED"; then
    echo "Authenticating Docker with ECR..."
    aws ecr-public get-login-password --region us-east-1 --profile $AWS_PROFILE | docker login --username AWS --password-stdin $REPOSITORY_URI
    mark_done "DOCKER_AUTHENTICATED"
    echo "Docker authentication successful."
else
    echo "Skipping Docker authentication (already done)."
fi

# Step 4: Build and Push Docker Image
if ! is_done "DOCKER_IMAGE_PUSHED"; then
    echo "Building and pushing Docker image..."
    docker build -t $REPOSITORY_URI:latest .
    docker push $REPOSITORY_URI:latest
    mark_done "DOCKER_IMAGE_PUSHED"
    echo "Docker image pushed successfully."
else
    echo "Skipping Docker build and push (already done)."
fi

# Step 5: Initialize Terraform
if ! is_done "TERRAFORM_INIT"; then
    echo "Initializing Terraform..."
    terraform init
    mark_done "TERRAFORM_INIT"
    echo "Terraform initialized."
else
    echo "Skipping Terraform initialization (already done)."
fi

# Step 6: Apply Terraform Deployment
if ! is_done "TERRAFORM_APPLIED"; then
    echo "Applying Terraform deployment..."
    terraform apply -var "image=$REPOSITORY_URI:latest" -var "email=$EMAIL" -var "db-creds=$DB_CREDS_SECRET_NAME" -auto-approve
    mark_done "TERRAFORM_APPLIED"
    echo "Terraform deployment applied successfully."
else
    echo "Skipping Terraform apply (already done)."
fi


echo "Deployment completed successfully!"
