pipeline {
    agent any
    
    tools {
        maven 'Maven 3.8.4'  // Use the name you defined in the global tool configuration
    }
    
    environment {
        // Define environment variables
        AWS_ACCOUNT_ID = credentials('AWS_ACCOUNT_ID')
        AWS_REGION = 'us-east-1' // Change to your preferred region
        ECR_REPOSITORY_NAME = 'java-app-repo'
        ECR_REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.substring(0,7)}"
        EKS_CLUSTER_NAME = 'my-eks-cluster'
        APP_NAME = 'java-app'
        NAMESPACE = 'production'
        AWS_CLI_PATH = '/opt/homebrew/bin/aws' // Full path to AWS CLI on macOS
        DOCKER_PATH = '/opt/homebrew/bin/docker' // Full path to Docker on macOS
    }
    
    stages {
        stage('Verify Tools') {
            steps {
                sh 'which docker || echo "Docker not found"'
                sh 'which aws || echo "AWS CLI not found"'
                sh 'mvn --version'
            }
        }
        
        stage('Code Checkout') {
            steps {
                checkout scm
                // Display the commit information for traceability
                sh 'git log -1'
            }
        }
        
        stage('Increment Version') {
            steps {
                script {
                    // Read current version from pom.xml
                    def pom = readMavenPom file: 'pom.xml'
                    def currentVersion = pom.version
                    echo "Current version: ${currentVersion}"
                    
                    // Increment version safely, handling both 2-part and 3-part versions
                    def versionParts = currentVersion.split('\\.')
                    def newVersion
                    
                    if (versionParts.size() >= 3) {
                        // Handle 3-part version (e.g., 1.0.0)
                        def major = versionParts[0]
                        def minor = versionParts[1]
                        def patch = versionParts[2].toInteger() + 1
                        newVersion = "${major}.${minor}.${patch}"
                    } else if (versionParts.size() == 2) {
                        // Handle 2-part version (e.g., 1.0)
                        def major = versionParts[0]
                        def minor = versionParts[1].toInteger() + 1
                        newVersion = "${major}.${minor}"
                    } else {
                        // Handle single digit version (e.g., 1)
                        def major = versionParts[0].toInteger() + 1
                        newVersion = "${major}"
                    }
                    
                    // Update pom.xml with new version
                    sh "mvn versions:set -DnewVersion=${newVersion}"
                    
                    // Store new version for later stages
                    env.APP_VERSION = newVersion
                    echo "New version: ${env.APP_VERSION}"
                }
            }
        }
        
        stage('Build Maven Artifact') {
            steps {
                sh 'mvn clean package -DskipTests'
                
                // Archive the WAR file instead of JAR
                archiveArtifacts artifacts: 'target/*.war', fingerprint: true
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Create ECR Repository if Not Exists') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        // Check if repository exists and create if it doesn't
                        sh """
                        ${env.AWS_CLI_PATH} ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} || \
                        ${env.AWS_CLI_PATH} ecr create-repository --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION}
                        """
                    }
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        // Authenticate with ECR - using a safer approach to avoid credential exposure
                        sh """
                        ${env.AWS_CLI_PATH} ecr get-login-password --region ${AWS_REGION} > ecr_password.txt
                        cat ecr_password.txt | ${env.DOCKER_PATH} login --username AWS --password-stdin \$REPOSITORY_URI
                        rm ecr_password.txt
                        """
                        
                        // Build the Docker image
                        sh "${env.DOCKER_PATH} build -t \$REPOSITORY_URI:${IMAGE_TAG} -t \$REPOSITORY_URI:latest ."
                        
                        // Push the Docker image to ECR
                        sh "${env.DOCKER_PATH} push \$REPOSITORY_URI:${IMAGE_TAG}"
                        sh "${env.DOCKER_PATH} push \$REPOSITORY_URI:latest"
                        
                        // Clean up local images to save space
                        sh "${env.DOCKER_PATH} rmi \$REPOSITORY_URI:${IMAGE_TAG}"
                        sh "${env.DOCKER_PATH} rmi \$REPOSITORY_URI:latest"
                    }
                }
            }
            environment {
                // Define REPOSITORY_URI in the environment to avoid Groovy string interpolation with credentials
                REPOSITORY_URI = "${ECR_REPOSITORY_URI}"
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        // Configure kubectl to connect to your EKS cluster
                        sh "${env.AWS_CLI_PATH} eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // Test the connection
                        sh "kubectl get nodes"
                        
                        // Create namespace if it doesn't exist
                        sh "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                        
                        // Use env variables to avoid exposing secrets through string interpolation
                        writeFile file: 'deployment.yaml', text: """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        version: "${env.APP_VERSION}"
    spec:
      containers:
      - name: ${APP_NAME}
        image: \$REPOSITORY_URI:${IMAGE_TAG}
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "0.5"
            memory: "512Mi"
          requests:
            cpu: "0.2"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${APP_NAME}
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
"""
                        
                        // Apply the deployment and service
                        sh "REPOSITORY_URI=${ECR_REPOSITORY_URI} envsubst < deployment.yaml | kubectl apply -f -"
                        
                        // Wait for the deployment to be ready
                        sh "kubectl rollout status deployment/${APP_NAME} -n ${NAMESPACE} --timeout=5m"
                    }
                }
            }
        }
        
        stage('Commit Version Update') {
            steps {
                script {
                    // Configure Git user
                    sh 'git config user.email "jenkins@example.com"'
                    sh 'git config user.name "Jenkins CI"'
                    
                    // Commit the updated pom.xml
                    sh 'git add pom.xml'
                    sh "git commit -m 'Bump version to ${env.APP_VERSION} [CI SKIP]'"
                    
                    // Push the commit back to the repository
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        // Use a more secure way to pass credentials to git push
                        withEnv(["HTTPS_URL=https://github.com/${GIT_USERNAME}/GitLab-Shell-Java-project-Source-Code.git"]) {
                            sh '''
                                git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@${HTTPS_URL#https://}
                                git push origin HEAD:${BRANCH_NAME}
                            '''
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully!"
            echo "Application version ${env.APP_VERSION} deployed to EKS cluster ${EKS_CLUSTER_NAME}"
            echo "Image tag: ${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed. Please check the logs for details."
        }
        always {
            // Clean workspace
            cleanWs()
        }
    }
}
