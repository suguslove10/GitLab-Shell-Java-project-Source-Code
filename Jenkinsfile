pipeline {
    agent any
    
    environment {
        DOCKER_PATH = '/usr/local/bin/docker'
        AWS_PATH = '/usr/local/bin/aws'
        KUBECTL_PATH = '/usr/local/bin/kubectl'
        AWS_REGION = 'ap-south-1'
        ECR_REPO_NAME = 'my-java-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = 'ridiculous-grunge-otter'
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_ACCOUNT_ID = credentials('AWS_ACCOUNT_ID')
    }
    
    tools {
        maven 'Maven 3.9.8'
        jdk 'JDK11'
    }

    stages {
        stage('Check Prerequisites') {
            steps {
                script {
                    // Check for Docker
                    sh 'docker --version'
                    
                    // Check for AWS CLI
                    sh 'aws --version'
                    
                    // Check for kubectl
                    sh 'kubectl version --client'
                }
            }
        }

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
        
        stage('Build & Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        
                        # Create repository if it doesn't exist
                        aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}
                        
                        # Build and push Docker image
                        docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
                        docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                        docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh """
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        cat <<EOF | kubectl apply -f -
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
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
        ports:
        - containerPort: 8080
EOF
                        
                        kubectl rollout status deployment/java-app -n default
                    """
                }
            }
        }
    }
    
    post {
        success {
            node('built-in') {
                echo 'Pipeline completed successfully!'
                cleanWs()
            }
        }
        failure {
            node('built-in') {
                echo 'Pipeline failed!'
                cleanWs()
            }
        }
    }
}
