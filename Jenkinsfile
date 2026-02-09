pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        PROJECT_NAME = 'hello-app'
        ENVIRONMENT = 'dev'
        ECR_REPO_NAME = "${PROJECT_NAME}-${ENVIRONMENT}"
        ECS_CLUSTER = "${PROJECT_NAME}-${ENVIRONMENT}-cluster"
        ECS_SERVICE = "${PROJECT_NAME}-${ENVIRONMENT}-service"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Initialize AWS') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        def accountId = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                        env.AWS_ACCOUNT_ID = accountId
                        env.ECR_REPOSITORY = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
                        echo "AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                        echo "ECR Repository: ${env.ECR_REPOSITORY}"
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo 'Building Spring Boot application...'
                sh './gradlew clean build'
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh './gradlew test'
            }
            post {
                always {
                    junit '**/build/test-results/test/*.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo 'Building Docker image...'
                sh '''
                    docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
                    docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPO_NAME}:latest
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                echo 'Pushing Docker image to ECR...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        // Login to ECR
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        """

                        // Tag and push
                        sh """
                            docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:${IMAGE_TAG}
                            docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest
                            docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
                            docker push ${ECR_REPOSITORY}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                echo 'Deploying to ECS...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh """
                            aws ecs update-service \
                                --cluster ${ECS_CLUSTER} \
                                --service ${ECS_SERVICE} \
                                --force-new-deployment \
                                --region ${AWS_REGION}
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
            emailext (
                subject: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: """
                    <p>SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'</p>
                    <p>Build URL: ${env.BUILD_URL}</p>
                    <p>Image: ${ECR_REPOSITORY}:${IMAGE_TAG}</p>
                    <p>ECS Service updated successfully.</p>
                """,
                to: 'enrique.coello@gmail.com',
                from: 'enrique.coello@gmail.com',
                mimeType: 'text/html'
            )
        }
        failure {
            echo 'Pipeline failed!'
            emailext (
                subject: "FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: """
                    <p>FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'</p>
                    <p>Build URL: ${env.BUILD_URL}</p>
                    <p>Console Output: ${env.BUILD_URL}console</p>
                    <p>Please check the logs for details.</p>
                """,
                to: 'enrique.coello@gmail.com',
                from: 'enrique.coello@gmail.com',
                mimeType: 'text/html'
            )
        }
        always {
            script {
                echo 'Cleaning up...'
                sh 'docker system prune -f'
            }
        }
    }
}
