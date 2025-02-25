pipeline {
    agent any
    
    tools {
        maven 'Maven 3.8.4'  // Use the name you defined in the global tool configuration
    }
    
    environment {
        // Define environment variables
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY_NAME = 'java-app-repo'
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ? env.GIT_COMMIT.substring(0,7) : 'unknown'}"
        EKS_CLUSTER_NAME = 'my-eks-cluster'
        APP_NAME = 'java-app'
        NAMESPACE = 'production'
        // Add Git branch variable to use throughout the pipeline
        GIT_BRANCH = "${env.BRANCH_NAME ?: 'main'}"
    }
    
    stages {
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "Checking for Docker..."
                    docker --version || echo "Docker not found"
                    
                    echo "Checking for AWS CLI..."
                    aws --version || echo "AWS CLI not found"
                    
                    echo "Checking for kubectl..."
                    kubectl version --client || echo "kubectl not found"
                    
                    echo "Checking Maven..."
                    mvn --version
                '''
            }
        }
        
        stage('Code Checkout') {
            steps {
                checkout scm
                // Display the commit information for traceability
                sh 'git log -1'
                // Display current branch
                sh 'git branch --show-current'
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
                
                // Archive the WAR file
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
                        sh '''
                        aws ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION}
                        '''
                    }
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    string(credentialsId: 'AWS_ACCOUNT_ID', variable: 'AWS_ACCOUNT_ID')
                ]) {
                    script {
                        def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
                        
                        // Authenticate with ECR
                        sh '''
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        '''
                        
                        // Build the Docker image
                        sh "docker build -t ${ecrUri}:${IMAGE_TAG} -t ${ecrUri}:latest ."
                        
                        // Push the Docker image to ECR
                        sh "docker push ${ecrUri}:${IMAGE_TAG}"
                        sh "docker push ${ecrUri}:latest"
                        
                        // Clean up local images to save space
                        sh "docker rmi ${ecrUri}:${IMAGE_TAG}"
                        sh "docker rmi ${ecrUri}:latest"
                        
                        // Store the ECR URI for later stages
                        env.ECR_URI = ecrUri
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                    string(credentialsId: 'AWS_ACCOUNT_ID', variable: 'AWS_ACCOUNT_ID')
                ]) {
                    script {
                        def ecrUri = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}"
                        
                        // Configure kubectl to connect to your EKS cluster
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // Test the connection
                        sh "kubectl get nodes"
                        
                        // Create namespace if it doesn't exist
                        sh "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                        
                        // Create deployment YAML file
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
        image: ${ecrUri}:${IMAGE_TAG}
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
                        sh "kubectl apply -f deployment.yaml"
                        
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
                    
                    // Push the commit back to the repository with proper branch name
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        // Fixed: Make sure we have a valid branch to push to
                        sh '''
                            # Get current branch or use GIT_BRANCH default
                            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                            if [ "$CURRENT_BRANCH" = "HEAD" ]; then
                                CURRENT_BRANCH=${GIT_BRANCH}
                            fi
                            
                            # Setup remote with credentials
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GIT_USERNAME}/GitLab-Shell-Java-project-Source-Code.git
                            
                            # Push with explicit branch name
                            git push origin HEAD:${CURRENT_BRANCH}
                            
                            echo "Successfully pushed to branch: ${CURRENT_BRANCH}"
                        '''
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
            cleanWs()
        }
    }
}
