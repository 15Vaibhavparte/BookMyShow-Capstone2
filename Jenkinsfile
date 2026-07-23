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

        SONAR_PROJECT_KEY = "bookmyshow-app"
        SCANNER_HOME = tool 'sonar-scanner'
    }
    stages {
        stage ("clean workspace") {
            steps {
                cleanWs()
            }
        }
        stage ("Git Checkout") {
            steps {
                git branch: 'main', url: 'https://github.com/15Vaibhavparte/BookMyShow-Capstone2.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh ''' 
                    $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=BMS \
                    -Dsonar.projectKey="${SONAR_PROJECT_KEY}" 
                    '''
                }
            }
        }
        stage('Quality Gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }

        stage("Install NPM Dependencies") {
            steps {
                // Navigate to the React app folder before installing dependencies
                dir('bookmyshow-app') {
                    sh '''
                ls -la  # Verify package.json exists
                if [ -f package.json ]; then
                    rm -rf node_modules package-lock.json  # Remove old dependencies
                    npm install  # Install fresh dependencies
                else
                    echo "Error: package.json not found in bookmyshow-app!"
                    exit 1
                fi
                '''
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
        stage('OWASP FS Scan') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check', nvdCredentialsId: 'nvd-api-key'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs . > trivyfs.txt'
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
        stage('Deploy to Container') {
            steps {
                sh ''' 
                echo "Stopping and removing old container..."
                docker stop bookmyshow-app || true
                docker rm bookmyshow-app || true

                echo "Running new container on port 3000..."
                docker run -d --restart=always --name bookmyshow-app -p 3000:3000 ${IMAGE_REPO}:latest

                echo "Checking running containers..."
                docker ps -a

                echo "Fetching logs..."
                sleep 5  # Give time for the app to start
                docker logs bookmyshow-app
                '''
          
            }
        }
    }
    post {
        always {
            emailext attachLog: true,
                subject: "'${currentBuild.result}'",
                body: "Project: ${env.JOB_NAME}<br/>" +
                      "Build Number: ${env.BUILD_NUMBER}<br/>" +
                      "URL: ${env.BUILD_URL}<br/>",
                to: 'vaibhavparte2@gmail.com',
                attachmentsPattern: 'trivyfs.txt,trivyimage.txt'
           
            sh '''docker image prune -f || true'''
        }
    }
}
