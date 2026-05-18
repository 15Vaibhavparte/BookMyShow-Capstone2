pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node18' // Using node18 to match your Docker container environment
    }
    environment {  
        // Define Docker and Image details here
        DOCKER_CREDS = 'docker'
        IMAGE_REPO = 'parte15/bookmyshow-app:latest'
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
                sh "npm install"
            }
        }
        
        stage ("Build Docker Image") {
            steps {
                sh "docker build -t bookmyshow-app ."
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
            sh'ansible-playbook -i /etc/ansible/hosts /etc/ansible/playbook.yml'
            }
        }
    }
}