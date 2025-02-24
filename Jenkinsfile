pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'github-credentials'  // Use the credential ID from Jenkins
        BRANCH = 'main'  // Ensure this matches your repo branch
    }

    stages {
        stage('Checkout Code') {
            steps {
                script {
                    checkout scm: [
                        $class: 'GitSCM',
                        branches: [[name: "*/${BRANCH}"]],
                        userRemoteConfigs: [[
                            url: 'https://github.com/suguslove10/GitLab-Shell-Java-project-Source-Code.git',
                            credentialsId: GIT_CREDENTIALS
                        ]]
                    ]
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Docker Build & Push') {
            environment {
                IMAGE_NAME = 'suguslove10/gitlab-shell-java'
                TAG = 'latest'
            }
            steps {
                script {
                    sh """
                        docker build -t ${IMAGE_NAME}:${TAG} .
                        echo "Pushing Docker image to Docker Hub..."
                        docker login -u \$DOCKER_USERNAME -p \$DOCKER_PASSWORD
                        docker push ${IMAGE_NAME}:${TAG}
                    """
                }
            }
        }

        stage('Deploy to Server') {
            steps {
                script {
                    sh """
                        ssh -i /path/to/your.pem ubuntu@your-ec2-ip "
                        docker pull ${IMAGE_NAME}:${TAG} &&
                        docker stop myapp || true &&
                        docker rm myapp || true &&
                        docker run -d --name myapp -p 8080:8080 ${IMAGE_NAME}:${TAG}
                        "
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline executed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
