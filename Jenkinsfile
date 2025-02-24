pipeline {
    agent any
    
    environment {
        AWS_ACCOUNT_ID = "YOUR_AWS_ACCOUNT_ID"
        AWS_DEFAULT_REGION = "YOUR_AWS_REGION" // e.g., us-east-1
        IMAGE_REPO_NAME = "tomcat-java-app"
        IMAGE_TAG = "${BUILD_NUMBER}"
        REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${IMAGE_REPO_NAME}"
        KUBECONFIG = credentials('eks-kubeconfig') // You'll need to add this credential in Jenkins
    }
    
    tools {
        maven 'Maven'
        jdk 'JDK11'
    }

    stages {
        stage('Increment Version') {
            steps {
                script {
                    echo 'Incrementing app version...'
                    sh 'mvn build-helper:parse-version versions:set \
                        -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.nextIncrementalVersion} \
                        versions:commit'
                    def matcher = readFile('pom.xml') =~ '<version>(.+)</version>'
                    def version = matcher[0][1]
                    env.IMAGE_TAG = "$version-$BUILD_NUMBER"
                }
            }
        }
        
        stage('Build Maven Project') {
            steps {
                sh 'mvn clean package'
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                script {
                    // AWS ECR Login
                    sh """
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
                        docker build -t ${IMAGE_REPO_NAME}:${IMAGE_TAG} .
                        docker tag ${IMAGE_REPO_NAME}:${IMAGE_TAG} ${REPOSITORY_URI}:${IMAGE_TAG}
                        docker push ${REPOSITORY_URI}:${IMAGE_TAG}
                    """
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh """
                        export KUBECONFIG=\$KUBECONFIG
                        kubectl apply -f k8s/deployment.yaml
                        kubectl set image deployment/tomcat-java-app tomcat-java-app=${REPOSITORY_URI}:${IMAGE_TAG}
                        kubectl rollout status deployment/tomcat-java-app
                    """
                }
            }
        }
    }
}
