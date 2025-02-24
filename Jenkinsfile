pipeline {
    agent any
    
    environment {
        AWS_CREDENTIALS = credentials('aws-credentials')
        AWS_REGION = 'ap-south-1'
        ECR_REPO_NAME = 'my-java-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = 'my-eks-cluster'
    }
    
    tools {
        maven 'Maven 3.9.8'
        jdk 'JDK11'
    }

    stages {
        // CI Step: Increment version
        stage('Prepare Version') {
            steps {
                script {
                    env.VERSION = "${BUILD_NUMBER}"
                    echo "Building version: ${env.VERSION}"
                }
            }
        }

        // CI Step: Build artifact for Java Maven application
        stage('Build Maven Project') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
        }
        
        // CI Step: Build and push Docker image to AWS ECR
        stage('Build & Push to ECR') {
            steps {
                script {
                    // Configure AWS CLI
                    sh """
                        aws configure set aws_access_key_id ${AWS_CREDENTIALS_USR}
                        aws configure set aws_secret_access_key ${AWS_CREDENTIALS_PSW}
                        aws configure set region ${AWS_REGION}
                    """
                    
                    // Get ECR login token
                    def ecrLogin = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    
                    // Get AWS Account ID
                    def awsAccountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                    
                    // Create ECR repository if it doesn't exist
                    sh """
                        aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} || \
                        aws ecr create-repository --repository-name ${ECR_REPO_NAME}
                    """
                    
                    // Login to ECR
                    sh "echo ${ecrLogin} | docker login --username AWS --password-stdin ${awsAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    
                    // Build and push Docker image
                    sh """
                        docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
                        docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${awsAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                        docker push ${awsAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        // CD Step: Deploy to EKS cluster
        stage('Deploy to EKS') {
            steps {
                script {
                    // Update kubeconfig
                    sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                    
                    // Get AWS Account ID
                    def awsAccountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                    
                    // Apply Kubernetes deployment
                    sh """
                        kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: java-app
  template:
    metadata:
      labels:
        app: java-app
    spec:
      containers:
      - name: java-app
        image: ${awsAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
        ports:
        - containerPort: 8080
EOF
                    """
                    
                    // Wait for deployment to complete
                    sh "kubectl rollout status deployment/java-app -n default"
                }
            }
        }
        
        // CD Step: Commit version update
        stage('Commit Version Update') {
            steps {
                script {
                    echo "Application version ${env.VERSION} deployed successfully"
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
        always {
            cleanWs()
        }
    }
}
