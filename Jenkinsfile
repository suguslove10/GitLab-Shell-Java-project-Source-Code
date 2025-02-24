pipeline {
    agent any
    
    environment {
        DOCKER_PATH         = '/usr/local/bin/docker'
        AWS_PATH            = '/usr/local/bin/aws'
        KUBECTL_PATH        = '/usr/local/bin/kubectl'
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_ACCOUNT_ID        = credentials('AWS_ACCOUNT_ID')
        AWS_REGION           = 'ap-south-1'
        ECR_REPO_NAME        = 'my-java-app'
        IMAGE_TAG            = "${BUILD_NUMBER}"
        KUBE_CONFIG         = credentials('eks-kubeconfig')
        GITHUB_CREDENTIALS  = credentials('github-credentials')
        EKS_CLUSTER_NAME    = 'ridiculous-grunge-otter'
        PATH                = "/usr/local/bin:${env.PATH}"
    }
    
    tools {
        maven 'Maven 3.9.8'
        jdk 'JDK11'
    }

    stages {
        stage('Check Prerequisites') {
            steps {
                script {
                    if (!fileExists(DOCKER_PATH)) {
                        error "Docker is not installed at ${DOCKER_PATH}. Please verify Docker Desktop installation."
                    }
                    
                    def dockerPs = sh(script: "${DOCKER_PATH} ps", returnStatus: true)
                    if (dockerPs != 0) {
                        error "Cannot connect to Docker daemon. Please ensure Docker Desktop is running."
                    }
                    
                    if (!fileExists(AWS_PATH)) {
                        error "AWS CLI is not installed at ${AWS_PATH}. Please verify AWS CLI installation."
                    }
                    
                    if (!fileExists(KUBECTL_PATH)) {
                        error "kubectl is not installed at ${KUBECTL_PATH}. Please run: brew install kubectl"
                    }

                    sh """
                        mkdir -p ~/.docker
                        echo '{"credsStore":""}' > ~/.docker/config.json
                    """
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
                    sh """
                        ${AWS_PATH} configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                        ${AWS_PATH} configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                        ${AWS_PATH} configure set default.region ${AWS_REGION}
                    """
                    
                    def ecrRepoExists = sh(
                        script: "${AWS_PATH} ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION}",
                        returnStatus: true
                    )
                    
                    if (ecrRepoExists != 0) {
                        echo "Creating ECR repository ${ECR_REPO_NAME}"
                        sh "${AWS_PATH} ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_REGION}"
                    }
                    
                    def ecrPassword = sh(script: "${AWS_PATH} ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                    
                    writeFile file: '.docker_auth.txt', text: ecrPassword
                    
                    sh """
                        cat .docker_auth.txt | ${DOCKER_PATH} login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        rm -f .docker_auth.txt
                        
                        ${DOCKER_PATH} build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} .
                        ${DOCKER_PATH} push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    withEnv(["AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}",
                            "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}",
                            "AWS_DEFAULT_REGION=${AWS_REGION}"]) {
                        
                        sh """
                            # Configure AWS CLI
                            ${AWS_PATH} configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
                            ${AWS_PATH} configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
                            ${AWS_PATH} configure set default.region ${AWS_REGION}
                            
                            # Get EKS cluster info
                            CLUSTER_ENDPOINT=\$(${AWS_PATH} eks describe-cluster --name ${EKS_CLUSTER_NAME} --query "cluster.endpoint" --output text)
                            CERTIFICATE_DATA=\$(${AWS_PATH} eks describe-cluster --name ${EKS_CLUSTER_NAME} --query "cluster.certificateAuthority.data" --output text)
                            
                            # Create kubeconfig
                            cat > kubeconfig << EOF
apiVersion: v1
clusters:
- cluster:
    server: \${CLUSTER_ENDPOINT}
    certificate-authority-data: \${CERTIFICATE_DATA}
  name: ${EKS_CLUSTER_NAME}
contexts:
- context:
    cluster: ${EKS_CLUSTER_NAME}
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: ${AWS_PATH}
      args:
        - eks
        - get-token
        - --cluster-name
        - ${EKS_CLUSTER_NAME}
        - --region
        - ${AWS_REGION}
EOF

                            # Use the new kubeconfig
                            export KUBECONFIG=\${PWD}/kubeconfig
                            
                            # Update deployment
                            ${KUBECTL_PATH} set image deployment/java-app java-app=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} -n default
                            
                            # Verify deployment
                            ${KUBECTL_PATH} rollout status deployment/java-app -n default
                            
                            # Clean up
                            rm -f kubeconfig
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            cleanWs()
            echo 'Pipeline completed successfully!'
        }
        failure {
            cleanWs()
            echo 'Pipeline failed!'
        }
    }
}
