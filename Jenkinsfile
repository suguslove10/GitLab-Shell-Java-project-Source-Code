pipeline {
    agent any
    
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_ACCOUNT_ID        = credentials('AWS_ACCOUNT_ID')
        AWS_REGION           = 'us-east-1'
        ECR_REPO_NAME        = 'my-java-app'
        IMAGE_TAG            = "${BUILD_NUMBER}"
        KUBE_CONFIG         = credentials('eks-kubeconfig')
        GITHUB_CREDENTIALS  = credentials('github-credentials')
        EKS_CLUSTER_NAME    = 'ridiculous-grunge-otter'
        DOCKER_PATH         = sh(script: 'which docker', returnStdout: true).trim()
        AWS_CLI_PATH        = sh(script: 'which aws', returnStdout: true).trim()
        KUBECTL_PATH        = sh(script: 'which kubectl', returnStdout: true).trim()
    }
    
    tools {
        maven 'Maven 3.9.8'
        jdk 'JDK11'
    }

    stages {
        stage('Check Prerequisites') {
            steps {
                script {
                    // Check Docker
                    def dockerVersion = sh(script: "${DOCKER_PATH} --version", returnStatus: true)
                    if (dockerVersion != 0) {
                        error "Docker is not running or accessible. Please start Docker Desktop."
                    }
                    
                    // Check AWS CLI
                    def awsVersion = sh(script: "${AWS_CLI_PATH} --version", returnStatus: true)
                    if (awsVersion != 0) {
                        error "AWS CLI is not installed. Run: brew install awscli"
                    }
                    
                    // Check kubectl
                    def kubectlVersion = sh(script: "${KUBECTL_PATH} version --client", returnStatus: true)
                    if (kubectlVersion != 0) {
                        error "kubectl is not installed. Run: brew install kubectl"
                    }
                    
                    // Verify Docker is running
                    def dockerPs = sh(script: "${DOCKER_PATH} ps", returnStatus: true)
                    if (dockerPs != 0) {
                        error "Cannot connect to Docker daemon. Please ensure Docker Desktop is running."
                    }
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
        
        stage('Build and Push Docker Image') {
            steps {
                script {
                    // Configure AWS CLI
                    sh """
                        ${AWS_CLI_PATH} configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                        ${AWS_CLI_PATH} configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                        ${AWS_CLI_PATH} configure set default.region ${AWS_REGION}
                    """
                    
                    // Login to ECR and build/push image
                    sh """
                        ${AWS_CLI_PATH} ecr get-login-password --region ${AWS_REGION} | ${DOCKER_PATH} login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        ${DOCKER_PATH} build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} .
                        ${DOCKER_PATH} push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh """
                        ${AWS_CLI_PATH} eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                        ${KUBECTL_PATH} set image deployment/java-app java-app=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} -n default
                        ${KUBECTL_PATH} rollout status deployment/java-app -n default
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            cleanWs()
        }
    }
}
