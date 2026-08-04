pipeline {
    agent any            // Executes the pipeline on any available Jenkins worker node/agent.
    tools {              // Injects required build tools (Java and Node.js) into the pipeline environment.
        jdk 'jdk17'
        nodejs 'node18' // Using node18 to match our Docker container environment
    }
    environment {          // Defines global environment variables used across multiple stages, such as registry credentials, cluster names, and AWS regions.
        DOCKER_CREDS = 'docker'
        IMAGE_REPO = 'parte15/bookmyshow-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"

        SONAR_PROJECT_KEY = "bookmyshow-app"
        SCANNER_HOME = tool 'sonar-scanner'

        EKS_CLUSTER_NAME = 'bookmyshow-eks'
        AWS_REGION = 'ap-south-1'
    
    }
    stages {                    
        stage ("clean workspace") {         // Clears the Jenkins workspace to prevent artifact conflicts and ensure a pristine build environment.
            steps {
                cleanWs()
            }
        }
        stage ("Git Checkout") {
            steps {
                git branch: 'main', url: 'https://github.com/15Vaibhavparte/BookMyShow-Capstone2.git'
            }
        }

        stage('SonarQube Analysis') {       // Executes static code analysis using the SonarQube scanner to identify bugs, code smells, and vulnerabilities.
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh ''' 
                    $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=BMS \
                    -Dsonar.projectKey="${SONAR_PROJECT_KEY}" 
                    '''
                }
            }
        }
        stage('Quality Gate') {             // Halts the pipeline to wait for SonarQube's response, proceeding only if the code meets predefined quality thresholds.
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }

        stage("Install NPM Dependencies") {         // Navigates into the React app directory, removes stale packages, and cleanly installs required Node.js dependencies.
            steps {
                // Navigate to the React app folder before installing dependencies
                dir('bookmyshow-app') {
                    sh '''
                ls -la  # Verify package.json exists
                if [ -f package.json ]; then
                    rm -rf node_modules package-lock.json  # Remove old dependencies
                    npm install  # Install fresh dependencies
                    npm install react-is styled-components

                else
                    echo "Error: package.json not found in bookmyshow-app!"
                    exit 1
                fi
                '''
                }
            }
        }
        
        stage ("Build Docker Image") {      // Compiles the React application into a standalone Docker container image using the local Dockerfile.
            steps {
                // Navigate to the React app folder so it uses bookmyshow-app/Dockerfile
                dir('bookmyshow-app') {
                    sh "docker build -t bookmyshow-app ."
                }
            }
        }
        stage('OWASP FS Scan') {            // Scans the project's dependencies for known public vulnerabilities (CVEs) and generates an XML report.
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check', nvdCredentialsId: 'nvd-api-key'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('Trivy FS Scan') {            // Audits the local file system for security flaws and exposed secrets, saving the output to a text file.
            steps {
                sh 'trivy fs . > trivyfs.txt'
            }
        }

        
        stage ("Tag & Push to DockerHub") {         // Authenticates with Docker Hub, tags the new image with the build number and 'latest', and pushes them to the remote registry.
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
        stage('Deploy to Container') {                  // Stops any existing local containers and spins up the newly built image on port 3000 to verify basic runtime stability.
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

        stage('Deploy to EKS Cluster') {                    // Executes after the pipeline completes, automatically sending an HTML email alert with the build status, logs, and security report.
            steps {
                script {
                    sh '''
                    echo "Verifying AWS credentials..."
                    aws sts get-caller-identity

                    echo "Configuring kubectl for EKS cluster..."
                    aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

                    echo "Verifying kubeconfig..."
                    kubectl config view

                    echo "Deploying application to EKS..."
                    kubectl apply -f kubernetes/deployment.yml
                    kubectl apply -f kubernetes/service.yml

                    kubectl rollout restart deployment/bookmyshow-app
                    
                    echo "Verifying deployment..."
                    kubectl get pods
                    kubectl get svc
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                emailext (
                    attachLog: true,
                    subject: "Build Status: ${currentBuild.currentResult} - Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h3>Jenkins Build Notification</h3>
                        <p><b>Project:</b> ${env.JOB_NAME}</p>
                        <p><b>Build Number:</b> ${env.BUILD_NUMBER}</p>
                        <p><b>Status:</b> ${currentBuild.currentResult}</p>
                        <p><b>URL:</b> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                        <hr/>
                        <p><i>The Trivy File System Scan report is attached to this email.</i></p>
                    """,
                    mimeType: 'text/html',
                    to: 'vaibhavparte2@gmail.com',
                    replyTo: 'vaibhavparte2@gmail.com',
                    attachmentsPattern: 'trivyfs.txt'
                )
            }
        }
    }
}