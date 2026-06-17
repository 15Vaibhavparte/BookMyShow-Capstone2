pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node18' // Using node18 to match our Docker container environment
    }
    environment {  
        DOCKER_CREDS = 'docker'
        IMAGE_REPO = 'parte15/bookmyshow-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }
    stages {
        stage ("clean workspace") {
            steps {
                cleanWs()
            }
        }
        stage ("Git Checkout") {
            steps {
                git branch: 'main', url: 'https://github.com/15Vaibhavparte/BookMyShow.git'
            }
        }
        
        stage("Install NPM Dependencies") {
            steps {
                // Navigate to the React app folder before installing dependencies
                dir('bookmyshow-app') {
                    sh "npm install"
                }
            }
        }
        
        stage ("Build Docker Image") {
            steps {
                // Navigate to the React app folder so it uses bookmyshow-app/Dockerfile
                dir('bookmyshow-app') {
                    sh "docker build -t bookmyshow-app ."
                }
            }
        }
        
        stage ("Tag & Push to DockerHub") {
            steps {
                script {
                    // Securely inject Docker credentials using native Jenkins commands
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDS}", passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                        
                        sh "echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin"
                        
                        // Tag and push using the dynamic build number
                        sh "docker tag bookmyshow-app ${IMAGE_REPO}:${IMAGE_TAG}"
                        sh "docker push ${IMAGE_REPO}:${IMAGE_TAG}"
                        
                        // Push 'latest' as a backup
                        sh "docker tag bookmyshow-app ${IMAGE_REPO}:latest"
                        sh "docker push ${IMAGE_REPO}:latest"
                    }
                }
            }
        }
        
        stage ("Run playbook to deploy on Kubernetes") {
            steps {
                sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.31.3.3 "ansible-playbook -i /etc/ansible/hosts /etc/ansible/playbook.yml"'
            }
        }
    }
}
