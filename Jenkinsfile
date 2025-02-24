pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '<your-aws-account-id>'
        AWS_REGION = '<your-region>'
        ECR_REPO_NAME = 'gitlab-shell-java'
        IMAGE_TAG = "gitlab-shell-java:${BUILD_NUMBER}"
        EKS_CLUSTER_NAME = '<your-cluster-nam'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git 'https://github.com/suguslove10/GitLab-Shell-Java-project-Source-Code.git'
            }
        }

        stage('Increment Version') {
            steps {
                sh 'mvn versions:set -DnewVersion=1.0.${BUILD_NUMBER}'
            }
        }

        stage('Build Maven Artifact') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    sh """
                        docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG .
                        docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                script {
                    sh """
                        aws eks --region $AWS_REGION update-kubeconfig --name $EKS_CLUSTER_NAME
                        kubectl set image deployment/gitlab-shell-java gitlab-shell-java=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
                    """
                }
            }
        }

        stage('Commit Version Update') {
            steps {
                script {
                    sh """
                        git config --global user.email "your-email@example.com"
                        git config --global user.name "Your Name"
                        git add .
                        git commit -m "Updated version to 1.0.${BUILD_NUMBER}"
                        git push origin main
                    """
                }
            }
        }
    }
}
