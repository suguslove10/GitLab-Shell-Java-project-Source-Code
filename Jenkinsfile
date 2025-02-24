pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1' // Change to your AWS region
        ECR_REPO = '211125328135.dkr.ecr.ap-south-1.amazonaws.com/gitlab-shell-java-repo' // Change to your ECR repo
        EKS_CLUSTER = 'extravagant-rock-otter' // Change to your EKS cluster name
        IMAGE_TAG = "latest"
        AWS_ACCOUNT_ID = "211125328135" // Change to your AWS Account ID
        DOCKER_IMAGE = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git 'https://github.com/suguslove10/GitLab-Shell-Java-project-Source-Code.git'
            }
        }

        stage('Increment Version') {
            steps {
                script {
                    sh 'echo "1.0.$BUILD_NUMBER" > version.txt'
                }
            }
        }

        stage('Build Maven Project') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Login to AWS ECR') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                '''
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                sh '''
                docker build -t $DOCKER_IMAGE .
                docker push $DOCKER_IMAGE
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                aws eks --region $AWS_REGION update-kubeconfig --name $EKS_CLUSTER
                kubectl set image deployment/my-app my-app-container=$DOCKER_IMAGE --namespace=default
                '''
            }
        }

        stage('Commit Version Update') {
            steps {
                sh '''
                git config --global user.email "your-email@example.com"
                git config --global user.name "Your Name"
                git add version.txt
                git commit -m "Updated version to 1.0.$BUILD_NUMBER"
                git push origin main
                '''
            }
        }
    }
}
