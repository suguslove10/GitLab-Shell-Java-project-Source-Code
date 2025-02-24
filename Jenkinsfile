pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_REGION            = 'ap-south-1'  // Change to your AWS region
        ECR_REPO_NAME         = 'gitlab-shell-java-repo'
        EKS_CLUSTER_NAME      = 'extravagant-rock-otter'
        IMAGE_TAG             = "v1.${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git ''
            }
        }

        stage('Increment Version') {
            steps {
                sh '''
                echo "Incrementing version..."
                echo $IMAGE_TAG > version.txt
                git config --global user.email "your-email@example.com"
                git config --global user.name "Jenkins"
                git add version.txt
                git commit -m "Increment version to $IMAGE_TAG"
                git push origin main
                '''
            }
        }

        stage('Build Java Application') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Authenticate AWS ECR') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.$AWS_REGION.amazonaws.com
                '''
            }
        }

        stage('Build and Push Docker Image to ECR') {
            steps {
                sh '''
                docker build -t $ECR_REPO_NAME:$IMAGE_TAG .
                docker tag $ECR_REPO_NAME:$IMAGE_TAG <AWS_ACCOUNT_ID>.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
                docker push <AWS_ACCOUNT_ID>.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to EKS Cluster') {
            steps {
                sh '''
                aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
                kubectl set image deployment/my-deployment my-container=<AWS_ACCOUNT_ID>.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG
                kubectl rollout status deployment/my-deployment
                '''
            }
        }

        stage('Commit Version Update') {
            steps {
                sh '''
                git add version.txt
                git commit -m "Updated to version $IMAGE_TAG"
                git push origin main
                '''
            }
        }
    }

    post {
        success {
            echo 'CI/CD Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
