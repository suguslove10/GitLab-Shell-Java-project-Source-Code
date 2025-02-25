# CI/CD Pipeline with AWS EKS and ECR

This repository contains a complete CI/CD pipeline implementation using Jenkins that builds a Java application, packages it as a Docker image, pushes it to AWS ECR, and deploys it to an AWS EKS Kubernetes cluster.

## Project Overview

This project demonstrates a full CI/CD workflow with the following components:
- Java application built with Maven
- Automatic version incrementation
- Docker image creation and publishing to AWS ECR
- Kubernetes deployment to AWS EKS
- Automated version update commit

## Technologies Used

- **Jenkins**: CI/CD orchestration
- **Java & Maven**: Application development and build
- **AWS ECR**: Docker image repository
- **AWS EKS**: Kubernetes service for container orchestration
- **Docker**: Containerization
- **Kubernetes**: Container orchestration
- **Git**: Source control

## Prerequisites

Before setting up this pipeline, ensure you have:

1. **Jenkins server** with the following plugins installed:
   - Pipeline
   - Git
   - Docker
   - AWS
   - Kubernetes

2. **Jenkins tools configured**:
   - Maven (configured as "Maven 3.8.4" in Global Tool Configuration)

3. **AWS resources**:
   - An AWS account with appropriate permissions
   - AWS EKS cluster created and configured
   - AWS ECR repository (will be created by the pipeline if it doesn't exist)

4. **Jenkins credentials configured**:
   - `aws-access-key`: AWS Access Key ID
   - `aws-secret-key`: AWS Secret Access Key
   - `AWS_ACCOUNT_ID`: Your AWS Account ID
   - `github-credentials`: GitHub credentials with write access to the repository

5. **Required tools on Jenkins server**:
   - Docker
   - AWS CLI
   - kubectl
   - Git

## Setup Instructions

### 1. Configure AWS CLI

Ensure AWS CLI is installed and configured on your Jenkins server:

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials (can be done via Jenkins credentials too)
aws configure
```

### 2. Install kubectl

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### 3. Configure Jenkins Credentials

In Jenkins, navigate to:
1. Manage Jenkins > Manage Credentials
2. Add the following credentials:
   - AWS access key credentials
   - AWS secret key credentials
   - AWS account ID
   - GitHub credentials with repository access

### 4. Create Jenkins Pipeline

1. Create a new Pipeline job in Jenkins
2. Configure the job to use "Pipeline script from SCM"
3. Set the repository URL to your GitHub repository
4. Set the script path to "Jenkinsfile"

## Jenkinsfile Configuration

The Jenkinsfile in this repository is already configured with all necessary stages:

1. **Verify Tools**: Checks that all required tools are available
2. **Code Checkout**: Retrieves the latest code from the repository
3. **Increment Version**: Automatically increments version in pom.xml
4. **Build Maven Artifact**: Compiles the Java application
5. **Run Tests**: Executes unit tests
6. **Create ECR Repository**: Creates ECR repository if it doesn't exist
7. **Build and Push Docker Image**: Creates Docker image and pushes to ECR
8. **Deploy to EKS**: Deploys the application to Kubernetes
9. **Commit Version Update**: Commits the updated version back to the repository

## Project Structure

```
project-root/
├── Jenkinsfile            # Jenkins pipeline definition
├── pom.xml                # Maven project configuration
├── src/                   # Java source code
├── Dockerfile             # Docker image definition
```

## Running the Pipeline

1. Push changes to your repository
2. Jenkins will automatically detect the changes and start the pipeline
3. Monitor the pipeline execution in Jenkins
4. After successful completion, the updated application will be deployed to EKS

## Customization

You may need to customize the following variables in the Jenkinsfile:

- `AWS_REGION`: Your AWS region
- `ECR_REPOSITORY_NAME`: Name for your ECR repository
- `EKS_CLUSTER_NAME`: Name of your EKS cluster
- `APP_NAME`: Name of your application
- `NAMESPACE`: Kubernetes namespace for deployment

## Troubleshooting

### Common Issues

1. **Docker build fails**:
   - Ensure Dockerfile is properly configured
   - Check Jenkins has permissions to run Docker commands

2. **AWS ECR authentication fails**:
   - Verify AWS credentials are correctly configured
   - Ensure IAM permissions include ECR access

3. **Kubernetes deployment fails**:
   - Check EKS cluster configuration
   - Verify kubectl is properly configured with cluster access
   - Ensure deployment YAML is valid

4. **Git push fails**:
   - Verify GitHub credentials
   - Ensure proper branch name is specified
   - Check repository permissions

### Logs

Check the Jenkins console output for detailed logs on each stage of the pipeline.

## Security Considerations

- Store all sensitive credentials in Jenkins Credentials Manager
- Use IAM roles with minimum required permissions
- Regularly rotate access keys and credentials
- Consider implementing secret scanning in your codebase

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
