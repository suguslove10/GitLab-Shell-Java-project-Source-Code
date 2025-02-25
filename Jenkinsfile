pipeline {
    agent any
    
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
        // AWS credentials will be provided by withCredentials block
    }
    
    stages {
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
                    
                    // Increment patch version (you can adjust this logic as needed)
                    def versionParts = currentVersion.split('\\.')
                    def major = versionParts[0]
                    def minor = versionParts[1]
                    def patch = versionParts[2].toInteger() + 1
                    def newVersion = "${major}.${minor}.${patch}"
                    
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
                
                // Archive the artifacts for later use
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
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
                        aws ecr describe-repositories --repository-names ${ECR_REPOSITORY_NAME} --region ${AWS_REGION} || \
                        aws ecr create-repository --repository-name ${ECR_REPOSITORY_NAME} --region ${AWS_REGION}
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
                        // Authenticate with ECR
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URI}"
                        
                        // Build the Docker image
                        sh "docker build -t ${ECR_REPOSITORY_URI}:${IMAGE_TAG} -t ${ECR_REPOSITORY_URI}:latest ."
                        
                        // Push the Docker image to ECR
                        sh "docker push ${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
                        sh "docker push ${ECR_REPOSITORY_URI}:latest"
                        
                        // Clean up local images to save space
                        sh "docker rmi ${ECR_REPOSITORY_URI}:${IMAGE_TAG}"
                        sh "docker rmi ${ECR_REPOSITORY_URI}:latest"
                    }
                }
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
                        sh "aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
                        
                        // Test the connection
                        sh "kubectl get nodes"
                        
                        // Create namespace if it doesn't exist
                        sh "kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"
                        
                        // Create deployment.yaml dynamically
                        sh """
                        cat <<EOF > deployment.yaml
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
        image: ${ECR_REPOSITORY_URI}:${IMAGE_TAG}
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
EOF
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
                    
                    // Push the commit back to the repository
                    withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        sh "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GIT_USERNAME}/java-app-repo.git HEAD:${env.BRANCH_NAME}"
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
