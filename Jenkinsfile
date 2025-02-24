pipeline {
    agent any
    
    environment {
        DOCKER_PATH = '/usr/local/bin/docker'
        AWS_PATH = '/usr/local/bin/aws'
        KUBECTL_PATH = '/usr/local/bin/kubectl'
        AWS_REGION = 'ap-south-1'
        ECR_REPO_NAME = 'my-java-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = 'extravagant-rock-otter'
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
                    sh """
                        set -e
                        echo 'Checking prerequisites...'
                        docker --version
                        aws --version
                        kubectl version --client
                    """
                }
            }
        }

        stage('Build Maven Project') {
            steps {
                script {
                    sh """
                        set -e
                        echo 'Building Maven project...'
                        mvn clean package -DskipTests
                    """
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    sh """
                        set -e
                        echo 'Running unit tests...'
                        mvn test
                    """
                }
            }
        }
        
        stage('Build & Push to ECR') {
            steps {
                script {
                    sh """
                        set -e
                        echo 'Logging into AWS ECR...'
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        
                        echo 'Checking if ECR repository exists...'
                        aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}
                        
                        echo 'Building Docker image...'
                        docker build --no-cache -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
                        
                        echo 'Tagging and pushing Docker image...'
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
                        set -e
                        echo 'Updating kubeconfig for EKS cluster...'
                        aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
                        
                        echo 'Deploying application to EKS...'
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml
                        
                        echo 'Checking deployment status...'
                        kubectl rollout status deployment/java-app -n default
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            cleanWs()
        }
        failure {
            echo 'Pipeline failed!'
            cleanWs()
        }
    }
}
