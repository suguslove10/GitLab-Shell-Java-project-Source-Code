pipeline {
    agent any
    
    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_ACCOUNT_ID        = credentials('AWS_ACCOUNT_ID')
        AWS_REGION = 'us-east-1'
        ECR_REPO_NAME = 'my-java-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        KUBE_CONFIG = credentials('eks-kubeconfig')
        GITHUB_CREDENTIALS = credentials('github-credentials')
        EKS_CLUSTER_NAME = 'ridiculous-grunge-otter'
    }
    
    tools {
        maven 'Maven'
        jdk 'JDK11'
    }

    stages {
        stage('Increment Version') {
            steps {
                script {
                    def pom = readMavenPom file: 'pom.xml'
                    def currentVersion = pom.version
                    def versionParts = currentVersion.split('\\.')
                    def newPatchVersion = versionParts[2].toInteger() + 1
                    def newVersion = "${versionParts[0]}.${versionParts[1]}.${newPatchVersion}"
                    sh "mvn versions:set -DnewVersion=${newVersion}"
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
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    def imageTag = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG}"
                    sh "docker build -t ${imageTag} ."
                    sh "docker push ${imageTag}"
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"
                    sh """
                        kubectl set image deployment/java-app java-app=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:${IMAGE_TAG} -n default
                        kubectl rollout status deployment/java-app -n default
                    """
                }
            }
        }
        
        stage('Commit Version Update') {
            steps {
                script {
                    sh """
                        git config user.email "jenkins@example.com"
                        git config user.name "Jenkins"
                    """
                    sh """
                        git add pom.xml
                        git commit -m "Bump version to \$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)"
                        git push origin HEAD:main
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
    }
}